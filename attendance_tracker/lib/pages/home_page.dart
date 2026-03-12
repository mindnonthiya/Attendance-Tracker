import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  Uint8List? selfieBytes;
  double? lastDistance;

  Future<void> takeSelfie() async {
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

      final selfieUrl = await supabaseService.uploadSelfie(
        selfieBytes: selfieBytes!,
      );

      await supabaseService.clockIn(
        shift: selectedShift.dbValue,
        latitude: position.latitude,
        longitude: position.longitude,
        selfieUrl: selfieUrl,
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
      await supabaseService.clockOut(shift: selectedShift.dbValue);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clock Out สำเร็จ (${selectedShift.label})')),
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
  Widget build(BuildContext context) {
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
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  if (lastDistance != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'ระยะห่างจากจุดลงเวลา: ${lastDistance!.toStringAsFixed(0)} เมตร',
                    ),
                  ],
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