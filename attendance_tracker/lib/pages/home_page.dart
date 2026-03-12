import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/supabase_service.dart';
import 'history_page.dart';
import 'login_page.dart';

enum AttendanceShift { morning, afternoon, evening }

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
  final picker = ImagePicker();

  AttendanceShift selectedShift = AttendanceShift.morning;
  bool loading = false;
  bool locationLoading = false;
  Uint8List? selfieBytes;
  double? lastDistance;
  double? currentLatitude;
  double? currentLongitude;
  DateTime now = DateTime.now();
  Timer? _timeTicker;

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

      setState(() {
        selfieBytes = bytes;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปิดกล้องไม่สำเร็จ: $e')));
    }
  }

  Future<void> refreshCurrentLocation() async {
    setState(() => locationLoading = true);
    try {
      final position = await LocationService.getCurrentLocation();
      final distance = LocationService.distanceFromOffice(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
        lastDistance = distance;
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

  Future<void> handleClockIn() async {
    if (selfieBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาถ่ายรูปยืนยันใบหน้าก่อน Clock In')),
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

      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
        lastDistance = distance;
      });

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

      await supabaseService.clockIn(
        shift: selectedShift.dbValue,
        latitude: position.latitude,
        longitude: position.longitude,
        selfieUrl: selfiePath,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clock In สำเร็จ (${selectedShift.label})')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> handleClockOut() async {
    setState(() => loading = true);
    try {
      await supabaseService.clockOut();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Clock Out สำเร็จ')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => loading = false);
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
    _timeTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timeTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentLocation =
        currentLatitude != null && currentLongitude != null;
    final userLabel =
        supabaseService.currentUser?.email?.split('@').first ?? 'Employee';

    final timeText = DateFormat('h:mm').format(now);
    final period = DateFormat('a').format(now);
    final dateText = DateFormat('EEE, dd MMM yyyy').format(now);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF172B6A), Color(0xFFE61F34)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(34),
                bottomRight: Radius.circular(34),
              ),
            ),
            padding: const EdgeInsets.only(left: 20, right: 20, top: 52, bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Please check in',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: refreshCurrentLocation,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
                IconButton(
                  onPressed: logout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: timeText,
                              style: const TextStyle(
                                color: Color(0xFF1A2A5A),
                                fontSize: 56,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: ' $period',
                              style: const TextStyle(
                                color: Color(0xFFE61F34),
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF1A2A5A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF5BBE6D),
                        size: 42,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'PT Tricor Orisoft Indonesia',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          color: Color(0xFF1A2A5A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasCurrentLocation
                            ? 'Current: ${currentLatitude!.toStringAsFixed(5)}, ${currentLongitude!.toStringAsFixed(5)}'
                            : 'Jalan H. R. Rasuna Said, Setiabudi, South Jakarta',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF6A6F7D)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: loading ? null : handleClockIn,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1D3E8A),
                              ),
                              child: const Text('CHECK IN'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: loading ? null : handleClockOut,
                              child: const Text('CHECK OUT'),
                            ),
                          ),
                        ],
                      ),
                      if (lastDistance != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'ระยะห่างจากจุดลงเวลา: ${lastDistance!.toStringAsFixed(0)} เมตร',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: FilledButton.tonalIcon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('เปิดประวัติการลงเวลา'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ยืนยันตัวตนและตำแหน่ง (ฟังก์ชันเดิม)',
                      style: Theme.of(context).textTheme.titleMedium,
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
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: loading ? null : takeSelfie,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        selfieBytes == null ? 'ถ่ายรูปยืนยันใบหน้า' : 'ถ่ายรูปใหม่',
                      ),
                    ),
                    if (selfieBytes != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          selfieBytes!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: locationLoading ? null : refreshCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        locationLoading
                            ? 'กำลังอัปเดตตำแหน่ง...'
                            : 'อัปเดตตำแหน่งปัจจุบัน',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasCurrentLocation
                          ? 'จุดฟ้า = ตำแหน่งปัจจุบัน • หมุด = จุดลงเวลา'
                          : 'แสดงจุดลงเวลาออฟฟิศ (กดอัปเดตเพื่อแสดงจุดฟ้า)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    _AttendanceMap(
                      currentLatitude: currentLatitude,
                      currentLongitude: currentLongitude,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AttendanceMap extends StatelessWidget {
  const _AttendanceMap({
    required this.currentLatitude,
    required this.currentLongitude,
  });

  final double? currentLatitude;
  final double? currentLongitude;

  @override
  Widget build(BuildContext context) {
    final office = LatLng(
      LocationService.officeLatitude,
      LocationService.officeLongitude,
    );
    final current = currentLatitude != null && currentLongitude != null
        ? LatLng(currentLatitude!, currentLongitude!)
        : null;

    final points = [office, if (current != null) current];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: current ?? office,
            initialZoom: current == null ? 16 : 17,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
            ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
