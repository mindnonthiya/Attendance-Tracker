import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://daeabscimokdvebfzgyg.supabase.co',
    anonKey: 'sb_publishable_RUiNlrxvA179OgKIc2_5vw_u_h6vbDp',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF3F7BFA),
      scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );

    return MaterialApp(
      title: 'Attendance Tracker',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,
      home: const LoginPage(),
    );
  }
}
