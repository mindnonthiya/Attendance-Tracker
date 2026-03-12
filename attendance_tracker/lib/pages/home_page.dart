import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentLocation =
        currentLatitude != null && currentLongitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
            },
          ),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4E78FF), Color(0xFF67B9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ลงเวลางานวันนี้',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasCurrentLocation
                      ? 'ตำแหน่งพร้อมแล้ว • แตะ Clock In ได้เลย'
                      : 'กำลังรอตำแหน่งปัจจุบัน...',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เลือกกะการทำงาน',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: loading ? null : takeSelfie,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      selfieBytes == null
                          ? 'ถ่ายรูปยืนยันใบหน้า'
                          : 'ถ่ายรูปใหม่',
                    ),
                  ),
                  if (selfieBytes != null) ...[
                    const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: locationLoading ? null : refreshCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      locationLoading
                          ? 'กำลังอัปเดตตำแหน่ง...'
                          : 'อัปเดตตำแหน่งปัจจุบัน',
                    ),
                  ),
                  if (lastDistance != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: lastDistance! <= LocationService.maxDistanceMeters
                            ? const Color(0xFFEAF8EF)
                            : const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'ระยะห่าง: ${lastDistance!.toStringAsFixed(0)} เมตร',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: loading ? null : handleClockIn,
                  child: const Text('Clock In'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: loading ? null : handleClockOut,
                  child: const Text('Clock Out'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'เงื่อนไข: ต้องแสกนหน้าและอยู่ในรัศมีไม่เกิน 200 เมตรจากจุดทำงาน',
          ),
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
