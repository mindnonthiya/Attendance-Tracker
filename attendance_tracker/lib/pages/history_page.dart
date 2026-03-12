import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/location_service.dart';
import '../services/supabase_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final supabaseService = AttendanceSupabaseService();
  final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  List<Map<String, dynamic>> data = [];
  bool loading = true;

  Future<void> loadData() async {
    setState(() => loading = true);
    try {
      final response = await supabaseService.history();
      setState(() {
        data = response;
      });
    } finally {
      setState(() => loading = false);
    }
  }

  String formatDate(dynamic dateString) {
    if (dateString == null) {
      return '-';
    }

    final dt = DateTime.tryParse(dateString.toString());
    if (dt == null) {
      return dateString.toString();
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : data.isEmpty
          ? RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                children: const [
                  SizedBox(height: 150),
                  Center(
                    child: Text('ยังไม่มีข้อมูลประวัติลงเวลา'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: data.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = data[index];
                  final selfieUrl = item['selfie_url']?.toString();

                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => openDetail(item),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: selfieUrl != null && selfieUrl.isNotEmpty
                                  ? Image.network(
                                      selfieUrl,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 72,
                                        height: 72,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    )
                                  : Container(
                                      width: 72,
                                      height: 72,
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
                                  const SizedBox(height: 6),
                                  Text(
                                    'กดเพื่อดูรายละเอียด',
                                    style: Theme.of(context).textTheme.bodySmall,
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
            ),
    );
  }
}

class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({super.key, required this.item});

  final Map<String, dynamic> item;

  String formatDate(dynamic dateString) {
    if (dateString == null) {
      return '-';
    }

    final dt = DateTime.tryParse(dateString.toString());
    if (dt == null) {
      return dateString.toString();
    }

    return DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final latitude = (item['latitude'] as num?)?.toDouble();
    final longitude = (item['longitude'] as num?)?.toDouble();
    final selfieUrl = item['selfie_url']?.toString();

    final mapUrl = (latitude != null && longitude != null)
        ? LocationService.buildStaticMapUrl(
            currentLatitude: latitude,
            currentLongitude: longitude,
          )
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดประวัติ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (selfieUrl != null && selfieUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                selfieUrl,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 220,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Text('โหลดรูปไม่สำเร็จ'),
                ),
              ),
            )
          else
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
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
          if (mapUrl != null) ...[
            Text(
              'แผนที่ย่อ (จุดสีฟ้า = สำนักงาน, จุดสีแดง = จุดลงเวลา)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                mapUrl,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 170,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Text('โหลดแผนที่ไม่สำเร็จ'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
