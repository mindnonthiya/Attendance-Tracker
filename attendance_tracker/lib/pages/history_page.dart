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
  String selectedFilter = 'all';

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

  String formatTime(dynamic dateString) {
    if (dateString == null) return '--:--';
    final dt = DateTime.tryParse(dateString.toString());
    if (dt == null) return '--:--';
    return DateFormat('hh:mm a').format(dt.toLocal());
  }

  List<Map<String, dynamic>> get filteredData {
    if (selectedFilter == 'all') return data;
    return data.where((item) => item['shift']?.toString() == selectedFilter).toList();
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

  Widget _buildFilterChips() {
    final filters = const [
      ('all', 'All'),
      ('morning', 'Morning'),
      ('afternoon', 'Afternoon'),
      ('evening', 'Evening'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(item.$2),
                  selected: selectedFilter == item.$1,
                  onSelected: (_) => setState(() => selectedFilter = item.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final lat = (item['latitude'] as num?)?.toDouble();
    final lon = (item['longitude'] as num?)?.toDouble();
    final distance = lat != null && lon != null
        ? LocationService.distanceFromOffice(latitude: lat, longitude: lon) / 1000
        : null;

    final selfieUrl =
        item['selfie_display_url']?.toString() ?? item['selfie_url']?.toString();
    final validImageUrl = selfieUrl != null && selfieUrl.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE, MMM d').format(
                      DateTime.tryParse((item['date'] ?? '').toString()) ?? DateTime.now(),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 30),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F2EB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Color(0xFF4D8A7E), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Completed',
                        style: TextStyle(
                          color: Color(0xFF4D8A7E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Shift: ${(item['shift'] ?? 'general').toString().replaceFirstMapped(RegExp(r'^.'), (m) => m.group(0)!.toUpperCase())}',
              style: const TextStyle(color: Color(0xFF6F7F79)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.login, color: Color(0xFF4D8A7E), size: 18),
                          SizedBox(width: 8),
                          Text('Check In', style: TextStyle(color: Color(0xFF7B8A85))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatTime(item['check_in']),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 36),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.logout, color: Color(0xFFC7745F), size: 18),
                          SizedBox(width: 8),
                          Text('Check Out', style: TextStyle(color: Color(0xFF7B8A85))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatTime(item['check_out']),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 36),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.location_on_outlined, size: 17, color: Color(0xFF8B9994)),
                SizedBox(width: 6),
                Text('Office - Main Building', style: TextStyle(color: Color(0xFF71807B))),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distance from office',
                        style: TextStyle(color: Color(0xFF72807B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        distance != null ? '${distance.toStringAsFixed(1)} km' : '-',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 32),
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 78,
                    height: 78,
                    child: validImageUrl
                        ? Image.network(
                            selfieUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFE6EEF8),
                              alignment: Alignment.center,
                              child: const Icon(Icons.camera_alt_outlined, color: Color(0xFFA1B2C5)),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFE6EEF8),
                            alignment: Alignment.center,
                            child: const Icon(Icons.camera_alt_outlined, color: Color(0xFFA1B2C5)),
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

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          const Text('Filter By', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 10),
          _buildFilterChips(),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 10),
                  const Text('โหลดประวัติไม่สำเร็จ'),
                  const SizedBox(height: 8),
                  Text(errorMessage!, textAlign: TextAlign.center),
                ],
              ),
            )
          else if (filteredData.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 90),
              child: Center(
                child: Text(
                  'No records yet',
                  style: TextStyle(color: Color(0xFFA0ABA7)),
                ),
              ),
            )
          else
            ...filteredData.map(_buildHistoryCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildBody();

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: _buildBody(),
    );
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
          if (selfieUrl != null && selfieUrl.startsWith('http'))
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
