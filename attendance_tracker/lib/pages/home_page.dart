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
        return 'Morning (9 AM - 5 PM)';
      case AttendanceShift.afternoon:
        return 'Afternoon (1 PM - 9 PM)';
      case AttendanceShift.evening:
        return 'Evening (5 PM - 1 AM)';
    }
  }

  String get shortLabel {
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
  bool recentLoading = false;
  double? currentLatitude;
  double? currentLongitude;
  String? currentAddress;
  List<Map<String, dynamic>> recentActivities = [];
  int historyRefreshToken = 0;

  Future<void> loadRecentActivities() async {
    setState(() => recentLoading = true);
    try {
      final history = await supabaseService.history();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayRecords = history
          .where((item) => item['date']?.toString() == today)
          .take(5)
          .toList();
      if (!mounted) return;
      setState(() => recentActivities = todayRecords);
    } catch (_) {
      if (!mounted) return;
      setState(() => recentActivities = []);
    } finally {
      if (mounted) {
        setState(() => recentLoading = false);
      }
    }
  }

  Future<void> handleAttendanceActionCompleted() async {
    await loadRecentActivities();
    if (!mounted) return;
    setState(() => historyRefreshToken++);
  }

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

  @override
  void initState() {
    super.initState();
    refreshCurrentLocation();
    loadRecentActivities();
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
        supabaseService.currentUser?.email ?? 'User'; // Fallback to 'User' if email is null

    final tabs = [
      _HomeTab(
        userLabel: userLabel,
        now: now,
        locationLoading: locationLoading,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        currentAddress: currentAddress,
        onRefreshLocation: refreshCurrentLocation,
        onTabChanged: (index) => setState(() => selectedTab = index),
        recentActivities: recentActivities,
        recentLoading: recentLoading,
        onLogout: logout,
      ),
      _AttendanceActionTab(
        action: AttendanceAction.checkIn,
        now: now,
        userLabel: userLabel,
        currentAddress: currentAddress,
        locationRefreshing: locationLoading,
        onRefreshLocation: refreshCurrentLocation,
        onActionCompleted: handleAttendanceActionCompleted,
        onLogout: logout,
      ),
      _AttendanceActionTab(
        action: AttendanceAction.checkOut,
        now: now,
        userLabel: userLabel,
        currentAddress: currentAddress,
        locationRefreshing: locationLoading,
        onRefreshLocation: refreshCurrentLocation,
        onActionCompleted: handleAttendanceActionCompleted,
        onLogout: logout,
      ),
      _HistoryTabScreen(
        userLabel: userLabel,
        onLogout: logout,
        refreshToken: historyRefreshToken,
      ),
      _MapTab(
        userLabel: userLabel,
        onLogout: logout,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        currentAddress: currentAddress,
        locationLoading: locationLoading,
        onRefreshLocation: refreshCurrentLocation,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F1),
      body: SafeArea(
        child: IndexedStack(index: selectedTab, children: tabs),
      ),
      bottomNavigationBar: NavigationBar(
        height: 66,
        backgroundColor: Colors.white,
        selectedIndex: selectedTab,
        indicatorColor: const Color(0x1A4D8A7E),
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.login), label: 'Check In'),
          NavigationDestination(icon: Icon(Icons.logout), label: 'Check Out'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.userLabel, required this.onLogout});

  final String userLabel;
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
                style: TextStyle(color: Color(0xFF84928C), fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                userLabel,
                style: const TextStyle(
                  color: Color(0xFF1E2A28),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onLogout,
          child: const CircleAvatar(
            backgroundColor: Color(0xFF4D8A7E),
            child: Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.userLabel,
    required this.now,
    required this.locationLoading,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.currentAddress,
    required this.onRefreshLocation,
    required this.onTabChanged,
    required this.recentActivities,
    required this.recentLoading,
    required this.onLogout,
  });

  final String userLabel;
  final DateTime now;
  final bool locationLoading;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? currentAddress;
  final VoidCallback onRefreshLocation;
  final ValueChanged<int> onTabChanged;
  final List<Map<String, dynamic>> recentActivities;
  final bool recentLoading;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        _HeaderBar(userLabel: userLabel, onLogout: onLogout),
        const SizedBox(height: 10),
        _SoftPanel(
          child: Column(
            children: [
              Text(
                DateFormat('EEEE, MMM d, y').format(now),
                style: const TextStyle(
                  color: Color(0xFF84918C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('hh:mm').format(now),
                style: const TextStyle(
                  fontSize: 56,
                  color: Color(0xFF1C2A27),
                  fontWeight: FontWeight.w700,
                  height: 0.95,
                ),
              ),
              Text(
                ':${DateFormat('ss').format(now)} ${DateFormat('a').format(now)}',
                style: const TextStyle(
                  color: Color(0xFF78857F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftPanel(
          child: Builder(
            builder: (_) {
              final latest = recentActivities.isNotEmpty
                  ? recentActivities.first
                  : null;
              final checkInTime = latest?['check_in'] != null
                  ? DateFormat('hh:mm a').format(
                      DateTime.parse(latest!['check_in'].toString()).toLocal(),
                    )
                  : '--:--';
              final checkOutTime = latest?['check_out'] != null
                  ? DateFormat('hh:mm a').format(
                      DateTime.parse(latest!['check_out'].toString()).toLocal(),
                    )
                  : '--:--';
              final checkedIn = latest?['check_in'] != null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: checkedIn
                            ? const Color(0xFF4D8A7E)
                            : const Color(0xFFE3B362),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        checkedIn ? 'Currently Working' : 'Not Checked In',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F3F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Check In',
                                style: TextStyle(color: Color(0xFF95A29D)),
                              ),
                              Text(
                                checkInTime,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F3F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Check Out',
                                style: TextStyle(color: Color(0xFF95A29D)),
                              ),
                              Text(
                                checkOutTime,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                title: 'Check In',
                subtitle: 'Start shift',
                icon: Icons.login,
                color: const Color(0xFF4D8A7E),
                onTap: () => onTabChanged(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                title: 'Check Out',
                subtitle: 'End shift',
                icon: Icons.logout,
                color: const Color.fromARGB(255, 123, 20, 20),
                onTap: () => onTabChanged(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Recent Activity',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Spacer(),
                  Text('Today', style: TextStyle(color: Color(0xFF9FAAA6))),
                ],
              ),
              const SizedBox(height: 12),
              if (recentLoading)
                const Center(child: CircularProgressIndicator())
              else if (recentActivities.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No activity yet today',
                      style: TextStyle(color: Color(0xFFA0ABA7)),
                    ),
                  ),
                )
              else
                ...recentActivities.take(3).map((item) {
                  final checkIn = item['check_in'] != null
                      ? DateFormat('hh:mm a').format(
                          DateTime.parse(item['check_in'].toString()).toLocal(),
                        )
                      : '--:--';
                  final checkOut = item['check_out'] != null
                      ? DateFormat('hh:mm a').format(
                          DateTime.parse(
                            item['check_out'].toString(),
                          ).toLocal(),
                        )
                      : '--:--';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Color(0xFF4D8A7E),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item['shift'] ?? 'general'} • In $checkIn • Out $checkOut',
                            style: const TextStyle(color: Color(0xFF51615B)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: locationLoading ? null : onRefreshLocation,
          icon: const Icon(Icons.refresh),
          label: Text(locationLoading ? 'Refreshing...' : 'Refresh Location'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4D8A7E),
          ),
        ),
        if (currentAddress != null) ...[
          const SizedBox(height: 6),
          Text(
            '$currentAddress (${currentLatitude?.toStringAsFixed(4) ?? '--'}, ${currentLongitude?.toStringAsFixed(4) ?? '--'})',
            style: const TextStyle(color: Color(0xFF83908B), fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
            ),
            Text(subtitle, style: const TextStyle(color: Color(0xD6FFFFFF))),
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
    required this.currentAddress,
    required this.locationRefreshing,
    required this.onRefreshLocation,
    required this.onActionCompleted,
    required this.onLogout,
  });

  final AttendanceAction action;
  final DateTime now;
  final String userLabel;
  final String? currentAddress;
  final bool locationRefreshing;
  final Future<void> Function() onRefreshLocation;
  final Future<void> Function() onActionCompleted;
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

  Future<void> showSuccessNotification(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF2E9F78)),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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
        await supabaseService.clockOut(
          shift: selectedShift.dbValue,
          selfieUrl: selfiePath,
        );
      }

      await showSuccessNotification(
        widget.action == AttendanceAction.checkIn
            ? 'Check In สำเร็จ (${selectedShift.shortLabel})'
            : 'Check Out สำเร็จ (${selectedShift.shortLabel})',
      );
      await widget.onActionCompleted();
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
    final accent = isCheckIn
        ? const Color(0xFF4D8A7E)
        : const Color(0xFFC7745F);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        _HeaderBar(userLabel: widget.userLabel, onLogout: widget.onLogout),
        const SizedBox(height: 10),
        _SoftPanel(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: isCheckIn
                    ? const Color(0xFFE3F2ED)
                    : const Color(0xFFF9E8E4),
                child: Icon(
                  isCheckIn ? Icons.login : Icons.logout,
                  size: 30,
                  color: accent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isCheckIn ? 'Check In' : 'Check Out',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 34,
                ),
              ),
              Text(
                DateFormat('hh:mm a').format(widget.now),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 48,
                  color: accent,
                ),
              ),
              Text(
                DateFormat('EEEE, MMM d, y').format(widget.now),
                style: const TextStyle(color: Color(0xFF8E9A95)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Shift',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AttendanceShift>(
                value: selectedShift,
                items: AttendanceShift.values
                    .map(
                      (shift) => DropdownMenuItem<AttendanceShift>(
                        value: shift,
                        child: Text(shift.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedShift = value);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftPanel(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Verification Selfie',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: loading ? null : takeSelfie,
                child: Container(
                  height: 132,
                  width: 132,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F2EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: selfieBytes == null
                      ? const Icon(
                          Icons.camera_alt_outlined,
                          size: 38,
                          color: Color(0xFF4D8A7E),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(selfieBytes!, fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: loading ? null : takeSelfie,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4D8A7E),
                ),
                child: const Text('Take Photo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Color(0xFF75847F),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Location',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Office - Main Building',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Distance: ${(lastDistance ?? 0).toStringAsFixed(1)} m',
                style: const TextStyle(color: Color(0xFF8E9A95)),
              ),
              if (widget.currentAddress != null)
                Text(
                  widget.currentAddress!,
                  style: const TextStyle(
                    color: Color(0xFF8E9A95),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: widget.locationRefreshing
                    ? null
                    : widget.onRefreshLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  widget.locationRefreshing
                      ? 'Refreshing current address...'
                      : 'Refresh Current Address',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftPanel(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: Color(0xFF75847F)),
                  SizedBox(width: 6),
                  Text(
                    'Work Duration',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '-- hrs -- min',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 36,
                  color: Color(0xFF1E2A28),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: loading || selfieBytes == null ? null : submitAction,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
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

class _HistoryTabScreen extends StatelessWidget {
  const _HistoryTabScreen({
    required this.userLabel,
    required this.onLogout,
    required this.refreshToken,
  });

  final String userLabel;
  final Future<void> Function() onLogout;
  final int refreshToken;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: _HeaderBar(userLabel: userLabel, onLogout: onLogout),
        ),
        Expanded(
          child: HistoryPage(key: ValueKey(refreshToken), embedded: true),
        ),
      ],
    );
  }
}

class _MapTab extends StatefulWidget {
  const _MapTab({
    required this.userLabel,
    required this.onLogout,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.currentAddress,
    required this.locationLoading,
    required this.onRefreshLocation,
  });

  final String userLabel;
  final Future<void> Function() onLogout;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? currentAddress;
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        _HeaderBar(userLabel: widget.userLabel, onLogout: widget.onLogout),
        const SizedBox(height: 10),
        _SoftPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: SizedBox(
                  height: 240,
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: current ?? office,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.attendance_tracker',
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
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4D8A7E),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
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
                                color: Color(0xFFC7745F),
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
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, color: Color(0xFF4D8A7E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Your Location\n${widget.currentAddress ?? 'Office - Main Building'}\n${current?.latitude.toStringAsFixed(4) ?? '--'}, ${current?.longitude.toStringAsFixed(4) ?? '--'}',
                        style: const TextStyle(color: Color(0xFF65736E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SoftPanel(
          child: Row(
            children: const [
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE2F1EC),
                child: Icon(
                  Icons.location_city,
                  size: 18,
                  color: Color(0xFF4D8A7E),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Office Info\nMain Office\n123 Business Street\nNew York, NY 10001',
                  style: TextStyle(color: Color(0xFF6C7974)),
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
          icon: const Icon(Icons.refresh),
          label: Text(
            widget.locationLoading ? 'Refreshing...' : 'Refresh Location',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4D8A7E),
          ),
        ),
      ],
    );
  }
}
