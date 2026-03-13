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
    if (!mounted) return;

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
      if (!mounted) return;
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
        supabaseService.currentUser?.email?.split('@').first ?? 'Sarah Johnson';

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
        userLabel: userLabel,
        onOpenHistory: openHistory,
        onLogout: logout,
      ),
      _AttendanceActionTab(
        action: AttendanceAction.checkOut,
        now: now,
        userLabel: userLabel,
        onOpenHistory: openHistory,
        onLogout: logout,
      ),
      _MapTab(
        userLabel: userLabel,
        onOpenHistory: openHistory,
        onLogout: logout,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        locationLoading: locationLoading,
        onRefreshLocation: refreshCurrentLocation,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      body: SafeArea(child: IndexedStack(index: selectedTab, children: tabs)),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        indicatorColor: const Color(0x1A4A857A),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.login), label: 'Check In'),
          NavigationDestination(icon: Icon(Icons.logout), label: 'Check Out'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
        ],
      ),
    );
  }
}

class _TopProfileHeader extends StatelessWidget {
  const _TopProfileHeader({
    required this.userLabel,
    required this.onOpenHistory,
    required this.onLogout,
  });

  final String userLabel;
  final VoidCallback onOpenHistory;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good Morning',
                style: TextStyle(color: Color(0xFF8C9893), fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                userLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  color: Color(0xFF1E2B29),
                ),
              ),
              const Text(
                'Acme Corporation',
                style: TextStyle(color: Color(0xFF9AA5A0), fontSize: 14),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
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
            radius: 24,
            backgroundColor: Color(0xFF4A857A),
            child: Icon(Icons.person_outline, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
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
    final dateText = DateFormat('EEEE, MMM d, y').format(now);
    final timeText = DateFormat('hh:mm').format(now);
    final meridiem = DateFormat('a').format(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        _TopProfileHeader(
          userLabel: userLabel,
          onOpenHistory: onOpenHistory,
          onLogout: onLogout,
        ),
        const SizedBox(height: 10),
        _SoftCard(
          child: Column(
            children: [
              Text(
                dateText,
                style: const TextStyle(
                  color: Color(0xFF818E89),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 62,
                  height: 1,
                  color: Color(0xFF1E2B29),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ':${DateFormat('ss').format(now)} $meridiem',
                style: const TextStyle(
                  color: Color(0xFF70817A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftCard(
          child: Row(
            children: [
              const Icon(Icons.brightness_1, size: 10, color: Color(0xFFE0A23A)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Not Checked In',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => onTabChanged(1),
                child: const Text('Check In'),
              ),
              TextButton(
                onPressed: () => onTabChanged(2),
                child: const Text('Check Out'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.login,
                title: 'Check In',
                subtitle: 'Tap to check in',
                color: const Color(0xFF4A857A),
                onTap: () => onTabChanged(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.logout,
                title: 'Check Out',
                subtitle: 'Tap to check out',
                color: const Color(0xFFC5715A),
                onTap: () => onTabChanged(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Text(
                    'Recent Activity',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Spacer(),
                  Text('Today', style: TextStyle(color: Color(0xFF9CA6A3))),
                ],
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'No activity yet today',
                  style: TextStyle(color: Color(0xFFA1AAA7)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: locationLoading ? null : onRefreshLocation,
          icon: const Icon(Icons.near_me_outlined),
          label: Text(
            locationLoading ? 'Updating location...' : 'Refresh Current Location',
          ),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A857A)),
        ),
        if (currentAddress != null) ...[
          const SizedBox(height: 8),
          Text(
            'Current: $currentAddress (${currentLatitude?.toStringAsFixed(4) ?? '--'}, ${currentLongitude?.toStringAsFixed(4) ?? '--'})',
            style: const TextStyle(fontSize: 12, color: Color(0xFF7D8985)),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
            ),
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
    required this.userLabel,
    required this.onOpenHistory,
    required this.onLogout,
  });

  final AttendanceAction action;
  final DateTime now;
  final String userLabel;
  final VoidCallback onOpenHistory;
  final Future<void> Function() onLogout;

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

      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() => selfieBytes = bytes);
    } catch (e) {
      if (!mounted) return;
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

      if (!mounted) return;
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
      if (!mounted) return;
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        _TopProfileHeader(
          userLabel: widget.userLabel,
          onOpenHistory: widget.onOpenHistory,
          onLogout: widget.onLogout,
        ),
        const SizedBox(height: 10),
        _SoftCard(
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: isCheckIn
                    ? const Color(0xFFE1F1EC)
                    : const Color(0xFFF8E7E2),
                child: Icon(
                  isCheckIn ? Icons.login : Icons.logout,
                  size: 34,
                  color: isCheckIn
                      ? const Color(0xFF4A857A)
                      : const Color(0xFFC5715A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isCheckIn ? 'Check In' : 'Check Out',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 30),
              ),
              Text(
                DateFormat('hh:mm a').format(widget.now),
                style: TextStyle(
                  fontSize: 42,
                  color: isCheckIn
                      ? const Color(0xFF4A857A)
                      : const Color(0xFFC5715A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                DateFormat('EEEE, MMM d, y').format(widget.now),
                style: const TextStyle(color: Color(0xFF8A9590)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Shift', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: loading ? null : takeSelfie,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(selfieBytes == null ? 'Capture Selfie' : 'Retake Selfie'),
              ),
              if (selfieBytes != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    selfieBytes!,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftCard(
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: Color(0xFF4A857A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Office - Main Building\n${LocationService.officeLatitude.toStringAsFixed(4)}, ${LocationService.officeLongitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: Color(0xFF5E6D67)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftCard(
          child: Text(
            'Work Duration\n-- hrs -- min',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        if (lastDistance != null) ...[
          const SizedBox(height: 8),
          Text(
            'Distance from office: ${lastDistance!.toStringAsFixed(0)} m',
            style: const TextStyle(color: Color(0xFF7B8682)),
          ),
        ],
        const SizedBox(height: 10),
        FilledButton(
          onPressed: loading || selfieBytes == null ? null : submitAction,
          style: FilledButton.styleFrom(
            backgroundColor: isCheckIn
                ? const Color(0xFF4A857A)
                : const Color(0xFFC5715A),
            foregroundColor: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(isCheckIn ? 'Confirm Check In' : 'Confirm Check Out'),
          ),
        ),
      ],
    );
  }
}

class _MapTab extends StatefulWidget {
  const _MapTab({
    required this.userLabel,
    required this.onOpenHistory,
    required this.onLogout,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.locationLoading,
    required this.onRefreshLocation,
  });

  final String userLabel;
  final VoidCallback onOpenHistory;
  final Future<void> Function() onLogout;
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

  Future<void> searchLocation() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return;

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
      final point = LatLng(
        double.parse(first['lat'].toString()),
        double.parse(first['lon'].toString()),
      );

      setState(() => searchPoint = point);
      mapController.move(point, 16);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => searching = false);
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        _TopProfileHeader(
          userLabel: widget.userLabel,
          onOpenHistory: widget.onOpenHistory,
          onLogout: widget.onLogout,
        ),
        const SizedBox(height: 10),
        _SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox(
                  height: 220,
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(initialCenter: current ?? office, initialZoom: 15),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.attendance_tracker',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: office,
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                          ),
                          if (current != null)
                            Marker(
                              point: current,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A857A),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
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
                                color: Color(0xFFC5715A),
                                size: 36,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.location_searching, color: Color(0xFF4A857A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your Location\n${current?.latitude.toStringAsFixed(4) ?? '--'}, ${current?.longitude.toStringAsFixed(4) ?? '--'}',
                        style: const TextStyle(color: Color(0xFF63706B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => searchLocation(),
          decoration: InputDecoration(
            hintText: 'Search locations...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: searching ? null : searchLocation,
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: widget.locationLoading ? null : widget.onRefreshLocation,
          icon: const Icon(Icons.my_location),
          label: Text(widget.locationLoading ? 'Refreshing...' : 'Refresh Location'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A857A)),
        ),
      ],
    );
  }
}
