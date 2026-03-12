import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/supabase_service.dart';
import 'history_page.dart';
import 'login_page.dart';

enum AttendanceShift { morning, afternoon, evening }

enum AttendanceAction { checkIn, checkOut }

extension AttendanceShiftExtension on AttendanceShift {
  String get label {
    switch (this) {
      case AttendanceShift.morning:
        return 'Morning';
      case AttendanceShift.afternoon:
        return 'Afternoon';
      case AttendanceShift.evening:
        return 'Evening';
    }
  }

  String get dbValue => name;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabaseService = AttendanceSupabaseService();

  int selectedTab = 0;
  DateTime now = DateTime.now();
  Timer? timeTicker;
  bool locationLoading = false;
  double? currentLatitude;
  double? currentLongitude;
  String? currentAddress;

  Future<void> refreshCurrentLocation() async {
    setState(() => locationLoading = true);

    try {
      final position = await LocationService.getCurrentLocation();

      final address = await LocationService.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
        currentAddress = address;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => locationLoading = false);
      }
    }
  }

  Future<void> logout() async {
    await supabaseService.signOut();
    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    refreshCurrentLocation();
    timeTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    timeTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userLabel =
        supabaseService.currentUser?.email?.split('@').first ?? 'Employee';

    final tabs = [
      _HomeDashboardTab(
        userLabel: userLabel,
        now: now,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        currentAddress: currentAddress,
        locationLoading: locationLoading,
        onRefreshLocation: refreshCurrentLocation,
        onOpenHistory: openHistory,
        onLogout: logout,
        onTabChanged: (index) => setState(() => selectedTab = index),
      ),
      _AttendanceActionTab(
        action: AttendanceAction.checkIn,
        now: now,
        onLocationUpdated: (point) {
          setState(() {
            currentLatitude = point.latitude;
            currentLongitude = point.longitude;
          });
        },
      ),
      _AttendanceActionTab(
        action: AttendanceAction.checkOut,
        now: now,
        onLocationUpdated: (point) {
          setState(() {
            currentLatitude = point.latitude;
            currentLongitude = point.longitude;
          });
        },
      ),
      _MapTab(
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        locationLoading: locationLoading,
        onRefreshLocation: refreshCurrentLocation,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: selectedTab, children: tabs),
      ),
      bottomNavigationBar: NavigationBar(
        height: 66,
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.login), label: 'Check In'),
          NavigationDestination(icon: Icon(Icons.logout), label: 'Check Out'),
          NavigationDestination(icon: Icon(Icons.location_on), label: 'Map'),
        ],
      ),
    );
  }
}

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.bottomRadius = 24,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173F79), Color(0xFFDB2A4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                  ),
                ),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _HomeDashboardTab extends StatelessWidget {
  const _HomeDashboardTab({
    required this.userLabel,
    required this.now,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.currentAddress,
    required this.locationLoading,
    required this.onRefreshLocation,
    required this.onOpenHistory,
    required this.onLogout,
    required this.onTabChanged,
  });

  final String userLabel;
  final DateTime now;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? currentAddress;
  final bool locationLoading;
  final VoidCallback onRefreshLocation;
  final VoidCallback onOpenHistory;
  final Future<void> Function() onLogout;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('HH:mm').format(now);
    final dateText = DateFormat('EEEE, MMMM d, y').format(now);

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        _GradientHeader(
          title: 'Good Morning',
          subtitle: userLabel,
          bottomRadius: 26,
          trailing: PopupMenuButton<String>(
            color: Colors.white,
            onSelected: (value) {
              if (value == 'history') {
                onOpenHistory();
              } else {
                onLogout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'history', child: Text('History')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            child: const CircleAvatar(
              backgroundColor: Color(0x3DFFFFFF),
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            children: [
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 62,
                  height: 1,
                  color: Color(0xFF1A3666),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dateText,
                style: const TextStyle(
                  color: Color(0xFF4D5B78),
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF27C887),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '• Checked In • Morning Shift',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFE9F0FF),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'CURRENT LOCATION',
                        style: TextStyle(
                          letterSpacing: .3,
                          color: Color(0xFF9DA7BD),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentAddress ?? 'Loading current address...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF32435F),
                    ),
                  ),
                  const Divider(height: 22),
                 
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: locationLoading ? null : onRefreshLocation,
                      icon: const Icon(Icons.sync),
                      label: Text(
                        locationLoading
                            ? 'Updating current location...'
                            : 'Update Current Location',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E5D96),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'QUICK ACTIONS',
            style: TextStyle(
              color: Color(0xFF9AA5BB),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  title: 'Check In',
                  subtitle: 'Start your shift',
                  icon: Icons.login,
                  iconBg: const Color(0xFFD6F8E9),
                  iconColor: const Color(0xFF2AB676),
                  onTap: () => onTabChanged(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  title: 'Check Out',
                  subtitle: 'End your shift',
                  icon: Icons.logout,
                  iconBg: const Color(0xFFFFE1E3),
                  iconColor: const Color(0xFFF35C63),
                  onTap: () => onTabChanged(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7EBF3)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: iconBg,
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 26),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFF9AA5BB))),
          ],
        ),
      ),
    );
  }
}

class _AttendanceActionTab extends StatefulWidget {
  const _AttendanceActionTab({
    required this.action,
    required this.now,
    required this.onLocationUpdated,
  });

  final AttendanceAction action;
  final DateTime now;
  final ValueChanged<LatLng> onLocationUpdated;

  @override
  State<_AttendanceActionTab> createState() => _AttendanceActionTabState();
}

class _AttendanceActionTabState extends State<_AttendanceActionTab> {
  final picker = ImagePicker();
  final supabaseService = AttendanceSupabaseService();

  AttendanceShift selectedShift = AttendanceShift.morning;
  Uint8List? selfieBytes;
  bool loading = false;
  double? lastDistance;

  Future<void> takeSelfie() async {
    try {
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1080,
      );

      if (photo == null) {
        return;
      }

      final bytes = await photo.readAsBytes();
      setState(() => selfieBytes = bytes);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปิดกล้องไม่สำเร็จ: $e')));
    }
  }

  Future<void> submitAction() async {
    if (selfieBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.action == AttendanceAction.checkIn
                ? 'กรุณาถ่ายรูปยืนยันใบหน้าก่อน Check In'
                : 'กรุณาถ่ายรูปยืนยันใบหน้าก่อน Check Out',
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final position = await LocationService.getCurrentLocation();
      final distance = LocationService.distanceFromOffice(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() => lastDistance = distance);
      widget.onLocationUpdated(LatLng(position.latitude, position.longitude));

      if (!LocationService.isWithinOfficeRadius(
        latitude: position.latitude,
        longitude: position.longitude,
      )) {
        throw Exception(
          'อยู่นอกพื้นที่อนุญาต (${distance.toStringAsFixed(0)} เมตร) ต้องไม่เกิน 200 เมตร',
        );
      }

      final selfiePath = await supabaseService.uploadSelfie(
        selfieBytes: selfieBytes!,
      );

      if (widget.action == AttendanceAction.checkIn) {
        await supabaseService.clockIn(
          shift: selectedShift.dbValue,
          latitude: position.latitude,
          longitude: position.longitude,
          selfieUrl: selfiePath,
        );
      } else {
        await supabaseService.clockOut(shift: selectedShift.dbValue);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.action == AttendanceAction.checkIn
                ? 'Check In สำเร็จ (${selectedShift.label})'
                : 'Check Out สำเร็จ (${selectedShift.label})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCheckIn = widget.action == AttendanceAction.checkIn;
    final title = isCheckIn ? 'Check In' : 'Check Out';

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        _GradientHeader(
          title: title,
          subtitle: isCheckIn
              ? 'Verify your attendance'
              : 'End your work shift',
          leading: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x33FFFFFF),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Shift',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 26),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<AttendanceShift>(
                    segments: AttendanceShift.values
                        .map(
                          (shift) => ButtonSegment<AttendanceShift>(
                            value: shift,
                            label: Text(shift.label),
                          ),
                        )
                        .toList(),
                    selected: {selectedShift},
                    onSelectionChanged: (selection) {
                      setState(() => selectedShift = selection.first);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Face Verification',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 26),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22252C),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF18C49A),
                              width: 2,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.account_circle,
                          size: 90,
                          color: Colors.white.withOpacity(.35),
                        ),
                        Positioned(
                          bottom: 14,
                          left: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Position your face within the circle',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loading ? null : takeSelfie,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        selfieBytes == null ? 'Scan Face' : 'Scan Again',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E5D96),
                      ),
                    ),
                  ),
                  if (selfieBytes != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        selfieBytes!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Distance from Office',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                          ),
                        ),
                      ),
                      if (lastDistance != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: lastDistance! <= 200
                                ? const Color(0xFFD8F7E8)
                                : const Color(0xFFFFE0E3),
                          ),
                          child: Text(
                            lastDistance! <= 200
                                ? 'Within Range'
                                : 'Out of Range',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(lastDistance ?? 0).toStringAsFixed(0)}m',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 40,
                      color: Color(0xFF1E3763),
                    ),
                  ),
                  const Text(
                    'from office entrance',
                    style: TextStyle(color: Color(0xFF98A4BB)),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading || selfieBytes == null ? null : submitAction,
              icon: const Icon(Icons.check),
              label: Text(isCheckIn ? 'Confirm Check In' : 'Confirm Check Out'),
              style: FilledButton.styleFrom(
                backgroundColor: isCheckIn
                    ? const Color(0xFF7DD8BD)
                    : const Color(0xFFEF9AA5),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapTab extends StatefulWidget {
  const _MapTab({
    required this.currentLatitude,
    required this.currentLongitude,
    required this.locationLoading,
    required this.onRefreshLocation,
  });

  final double? currentLatitude;
  final double? currentLongitude;
  final bool locationLoading;
  final Future<void> Function() onRefreshLocation;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  final mapController = MapController();
  final searchController = TextEditingController();

  bool searching = false;
  LatLng? searchPoint;
  String? searchLabel;

  Future<void> searchLocation() async {
    final query = searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() => searching = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'attendance-tracker/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('ค้นหาสถานที่ไม่สำเร็จ (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        throw Exception('ไม่พบสถานที่ที่ค้นหา');
      }

      final first = decoded.first;
      final lat = double.parse(first['lat'].toString());
      final lon = double.parse(first['lon'].toString());
      final point = LatLng(lat, lon);

      setState(() {
        searchPoint = point;
        searchLabel = first['display_name']?.toString();
      });

      mapController.move(point, 16);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => searching = false);
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final office = LatLng(
      LocationService.officeLatitude,
      LocationService.officeLongitude,
    );
    final current =
        widget.currentLatitude != null && widget.currentLongitude != null
        ? LatLng(widget.currentLatitude!, widget.currentLongitude!)
        : null;

    final points = [
      office,
      if (current != null) current,
      if (searchPoint != null) searchPoint!,
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        const _GradientHeader(
          title: 'Location Map',
          subtitle: 'View office & your location',
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => searchLocation(),
            decoration: const InputDecoration(
              hintText: 'Search locations...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 320,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: current ?? office,
                  initialZoom: 16,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds.fromPoints(points),
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.attendance_tracker',
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: office,
                        color: const Color(0x1A4E78FF),
                        borderColor: const Color(0xFF4E78FF),
                        borderStrokeWidth: 2,
                        radius: 80,
                        useRadiusInMeter: true,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: office,
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 36,
                        ),
                      ),
                      if (current != null)
                        Marker(
                          point: current,
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2596FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x662596FF),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (searchPoint != null)
                        Marker(
                          point: searchPoint!,
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.place,
                            color: Color(0xFFE67E22),
                            size: 36,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: FilledButton.icon(
            onPressed: widget.locationLoading ? null : widget.onRefreshLocation,
            icon: const Icon(Icons.sync),
            label: Text(
              widget.locationLoading ? 'Refreshing...' : 'Refresh Location',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E5D96),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Coordinates\n${current?.latitude.toStringAsFixed(4) ?? '--'},\n${current?.longitude.toStringAsFixed(4) ?? '--'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Office Coordinates\n${office.latitude.toStringAsFixed(4)},\n${office.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (searchLabel != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Search result: $searchLabel'),
          ),
      ],
    );
  }
}
