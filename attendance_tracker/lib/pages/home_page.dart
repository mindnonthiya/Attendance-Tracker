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
      ),
      _AttendanceActionTab(
        action: AttendanceAction.checkIn,
        onLocationUpdated: (point) {
          setState(() {
            currentLatitude = point.latitude;
            currentLongitude = point.longitude;
          });
        },
      ),
      _AttendanceActionTab(
        action: AttendanceAction.checkOut,
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
      appBar: AppBar(
        title: Text(['Home', 'Check In', 'Check Out', 'Map'][selectedTab]),
        actions: [
          IconButton(
            onPressed: openHistory,
            icon: const Icon(Icons.history),
            tooltip: 'History',
          ),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: IndexedStack(index: selectedTab, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.login_outlined),
            label: 'Check In',
          ),
          NavigationDestination(
            icon: Icon(Icons.logout_outlined),
            label: 'Check Out',
          ),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
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
  });

  final String userLabel;
  final DateTime now;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? currentAddress;
  final bool locationLoading;
  final VoidCallback onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('h:mm').format(now);
    final period = DateFormat('a').format(now);
    final dateText = DateFormat('EEE, dd MMM yyyy').format(now);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF182C74), Color(0xFFE0263D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Welcome back',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -78),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: timeText,
                            style: const TextStyle(
                              color: Color(0xFF1A2A5A),
                              fontSize: 58,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: ' $period',
                            style: const TextStyle(
                              color: Color(0xFFE0263D),
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF28365F),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Icon(
                      Icons.location_on,
                      color: Color.fromARGB(255, 214, 55, 55),
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentAddress ?? 'กำลังโหลดที่อยู่...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1A2A5A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentLatitude != null && currentLongitude != null
                          ? '${currentLatitude!.toStringAsFixed(6)}, ${currentLongitude!.toStringAsFixed(6)}'
                          : 'กดอัปเดตตำแหน่งเพื่อแสดงพิกัดปัจจุบัน',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6A6F7D)),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: locationLoading ? null : onRefreshLocation,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          locationLoading
                              ? 'กำลังอัปเดตตำแหน่ง...'
                              : 'อัปเดตตำแหน่งปัจจุบัน',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceActionTab extends StatefulWidget {
  const _AttendanceActionTab({
    required this.action,
    required this.onLocationUpdated,
  });

  final AttendanceAction action;
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
    final headerColor = isCheckIn
        ? const Color(0xFF275DF2)
        : const Color(0xFF933EF2);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [headerColor, headerColor.withOpacity(0.72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                isCheckIn ? 'Check In' : 'Check Out',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1) เลือกกะการทำงาน',
                  style: TextStyle(fontWeight: FontWeight.w600),
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
                  '2) สแกนหน้า (ถ่ายรูป)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: loading ? null : takeSelfie,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(selfieBytes == null ? 'สแกนหน้า' : 'สแกนใหม่'),
                ),
                if (selfieBytes != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      selfieBytes!,
                      height: 168,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (lastDistance != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'ระยะห่างล่าสุด: ${lastDistance!.toStringAsFixed(0)} เมตร',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : submitAction,
                    style: FilledButton.styleFrom(backgroundColor: headerColor),
                    child: Text(
                      isCheckIn ? 'ยืนยัน Check In' : 'ยืนยัน Check Out',
                    ),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => searchLocation(),
                decoration: const InputDecoration(
                  hintText: 'ค้นหาสถานที่...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: searching ? null : searchLocation,
              child: searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ค้นหา'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: widget.locationLoading ? null : widget.onRefreshLocation,
          icon: const Icon(Icons.my_location),
          label: Text(
            widget.locationLoading
                ? 'กำลังอัปเดตตำแหน่ง...'
                : 'อัปเดตตำแหน่งปัจจุบัน',
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 360,
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                        color: Color(0xFF1F3C88),
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
        const SizedBox(height: 10),
        const Text(
          'หมุดน้ำเงิน: สำนักงาน • จุดฟ้า: ตำแหน่งปัจจุบัน • หมุดส้ม: ผลการค้นหา',
        ),
        if (searchLabel != null) ...[
          const SizedBox(height: 6),
          Text('ผลการค้นหา: $searchLabel'),
        ],
      ],
    );
  }
}
