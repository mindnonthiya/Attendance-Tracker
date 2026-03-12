import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final supabase = Supabase.instance.client;

  List data = [];

  Future<void> loadData() async {
    final user = supabase.auth.currentUser;

    final response = await supabase
        .from('attendance')
        .select()
        .eq('user_id', user!.id)
        .order('date', ascending: false);

    setState(() {
      data = response;
    });
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Attendance History")),

      body: ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) {
          final item = data[index];

          return ListTile(
            title: Text("Date: ${item['date']}"),
            subtitle: Text(
              "In: ${item['check_in']}  |  Out: ${item['check_out'] ?? '-'}",
            ),
          );
        },
      ),
    );
  }
}
