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

  Future<void> refreshCurrentLocation() async {
    setState(() => locationLoading = true);
    try {
      final position = await LocationService.getCurrentLocation();
      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
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
    required this.locationLoading,
    required this.onRefreshLocation,
  });

  final String userLabel;
  final DateTime now;
  final double? currentLatitude;
  final double? currentLongitude;
  final bool locationLoading;
  final VoidCallback onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('HH:mm:ss').format(now);
    final dateText = DateFormat('EEE, dd MMM yyyy').format(now);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'เวลาปัจจุบัน',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2A5A),
                  ),
                ),
                Text(dateText),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ตำแหน่งปัจจุบัน', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  currentLatitude != null && currentLongitude != null
                      ? '${currentLatitude!.toStringAsFixed(6)}, ${currentLongitude!.toStringAsFixed(6)}'
                      : 'ยังไม่มีข้อมูลตำแหน่ง',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: locationLoading ? null : onRefreshLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    locationLoading
                        ? 'กำลังอัปเดตตำแหน่ง...'
                        : 'อัปเดตตำแหน่งปัจจุบัน',
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

class _AttendanceActionTab extends StatefulWidget {
  const _AttendanceActionTab({required this.action, required this.onLocationUpdated});

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
    final title = widget.action == AttendanceAction.checkIn
        ? 'หน้าลงเวลาเข้า (Check In)'
        : 'หน้าลงเวลาออก (Check Out)';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: loading ? null : takeSelfie,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    selfieBytes == null ? 'สแกนหน้า (ถ่ายรูป)' : 'สแกนใหม่',
                  ),
                ),
                if (selfieBytes != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      selfieBytes!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (lastDistance != null) ...[
                  const SizedBox(height: 10),
                  Text('ระยะห่างล่าสุด: ${lastDistance!.toStringAsFixed(0)} เมตร'),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: loading ? null : submitAction,
                  child: Text(
                    widget.action == AttendanceAction.checkIn
                        ? 'ยืนยัน Check In'
                        : 'ยืนยัน Check Out',
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
    final current = widget.currentLatitude != null && widget.currentLongitude != null
        ? LatLng(widget.currentLatitude!, widget.currentLongitude!)
        : null;

    final points = [office, if (current != null) current, if (searchPoint != null) searchPoint!];

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
        Text('หมุดน้ำเงิน: สำนักงาน • จุดฟ้า: ตำแหน่งปัจจุบัน • หมุดส้ม: ผลการค้นหา'),
        if (searchLabel != null) ...[
          const SizedBox(height: 6),
          Text('ผลการค้นหา: $searchLabel'),
        ],
      ],
    );
  }
}
