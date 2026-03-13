import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/supabase_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final supabaseService = AttendanceSupabaseService();
  final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  List<Map<String, dynamic>> data = [];
  bool loading = true;
  String? errorMessage;

  Future<void> loadData() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await supabaseService.history();
      if (!mounted) return;
      setState(() => data = response);
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String formatDate(dynamic dateString) {
    if (dateString == null) return '-';

    final dt = DateTime.tryParse(dateString.toString());
    if (dt == null) return dateString.toString();

    return dateFormat.format(dt.toLocal());
  }

  void openDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoryDetailPage(item: item)),
    );
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'โหลดประวัติไม่สำเร็จ',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(errorMessage!, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (data.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 120),
            const Icon(Icons.history_toggle_off, size: 48),
            const SizedBox(height: 12),
            const Center(child: Text('ยังไม่มีข้อมูลประวัติลงเวลา')),
            const SizedBox(height: 8),
            Text(
              'Current user: ${supabaseService.currentUser?.id ?? '-'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = data[index];
          final selfieUrl =
              item['selfie_display_url']?.toString() ?? item['selfie_url']?.toString();

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => openDetail(item),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: selfieUrl != null && selfieUrl.isNotEmpty
                          ? Image.network(
                              selfieUrl,
                              width: 82,
                              height: 82,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 82,
                                height: 82,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image),
                              ),
                            )
                          : Container(
                              width: 82,
                              height: 82,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['date']} • ${item['shift'] ?? 'general'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('In: ${formatDate(item['check_in'])}'),
                          Text('Out: ${formatDate(item['check_out'])}'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5FF),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text('แตะเพื่อดูรายละเอียด'),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    return Scaffold(appBar: AppBar(title: const Text('Attendance History')), body: _buildBody());
  }
}

class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({super.key, required this.item});

  final Map<String, dynamic> item;

  String formatDate(dynamic dateString) {
    if (dateString == null) return '-';

    final dt = DateTime.tryParse(dateString.toString());
    if (dt == null) return dateString.toString();

    return DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final latitude = (item['latitude'] as num?)?.toDouble();
    final longitude = (item['longitude'] as num?)?.toDouble();
    final selfieUrl =
        item['selfie_display_url']?.toString() ?? item['selfie_url']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดประวัติ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (selfieUrl != null && selfieUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                selfieUrl,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 240,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Text('โหลดรูปไม่สำเร็จ'),
                ),
              ),
            )
          else
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('ไม่มีรูปถ่าย'),
            ),
          const SizedBox(height: 16),
          Text('วันที่: ${item['date'] ?? '-'}'),
          Text('กะ: ${item['shift'] ?? 'general'}'),
          Text('เวลาเข้างาน: ${formatDate(item['check_in'])}'),
          Text('เวลาออกงาน: ${formatDate(item['check_out'])}'),
          const SizedBox(height: 8),
          Text('ละติจูด: ${latitude?.toStringAsFixed(6) ?? '-'}'),
          Text('ลองจิจูด: ${longitude?.toStringAsFixed(6) ?? '-'}'),
          const SizedBox(height: 12),
          if (latitude != null && longitude != null) ...[
            Text(
              'จุดฟ้า = ตำแหน่งที่ลงเวลา • หมุด = สำนักงาน',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _HistoryMap(latitude: latitude, longitude: longitude),
          ] else
            const Text('ไม่มีพิกัดในรายการนี้ จึงไม่สามารถแสดงแผนที่ได้'),
        ],
      ),
    );
  }
}

class _HistoryMap extends StatelessWidget {
  const _HistoryMap({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final office = LatLng(LocationService.officeLatitude, LocationService.officeLongitude);
    final attendancePoint = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: attendancePoint,
            initialZoom: 17,
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds.fromPoints([office, attendancePoint]),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.attendance_tracker',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: office,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Color(0xFF1F3C88), size: 34),
                ),
                Marker(
                  point: attendancePoint,
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
