import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: data.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = data[index];

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                          Text(
                            'Lat/Lng: ${item['latitude'] ?? '-'}, ${item['longitude'] ?? '-'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
