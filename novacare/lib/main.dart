import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/settings/settings_screens.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/medical_records/medical_records_screen.dart';
// import 'screens/auth/login_screen.dart'

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hkttoorbmvmyqawugyef.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrdHRvb3JibXZteXFhd3VneWVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0Mzg4NjQsImV4cCI6MjA2MzAxNDg2NH0.QVy951TUaHyEgjH1fCIt7XdDqj-Scga_1TpA0Yrns34',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NovaCare',
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      home: const LoginScreen(),
      routes: {
        LoginScreen.routeName: (context) => const LoginScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        AiChatScreen.routeName: (context) => const AiChatScreen(),
        MedicalRecordsScreen.routeName: (context) => const MedicalRecordsScreen(),
      },
    );
  }
}
