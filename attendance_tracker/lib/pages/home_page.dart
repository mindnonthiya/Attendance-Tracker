import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/location_service.dart';
import 'history_page.dart';

class HomePage extends StatelessWidget {
  final supabase = Supabase.instance.client;

  Future<void> clockIn() async {

    final user = supabase.auth.currentUser;

    final position = await LocationService.getCurrentLocation();

    await supabase.from('attendance').insert({
      'user_id': user!.id,
      'check_in': DateTime.now().toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'date': DateTime.now().toString().split(' ')[0],
    });

    print("Clock In success");
  }

  Future<void> clockOut() async {

    final user = supabase.auth.currentUser;

    final today = DateTime.now().toString().split(' ')[0];

    await supabase
        .from('attendance')
        .update({
          'check_out': DateTime.now().toIso8601String()
        })
        .eq('user_id', user!.id)
        .eq('date', today);

    print("Clock Out success");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Tracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HistoryPage()),
              );
            },
          )
        ],
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            ElevatedButton(
              onPressed: clockIn,
              child: Text("Clock In"),
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: clockOut,
              child: Text("Clock Out"),
            ),

          ],
        ),
      ),
    );
  }
}