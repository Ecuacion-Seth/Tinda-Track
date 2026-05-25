import 'package:flutter/material.dart';
import 'screens/main_nav.dart';
import 'db/database_helper.dart';

void main() async {
  // 1. Ensure Flutter bindings are ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. CRITICAL: Wait for SQLite to initialize and seed BEFORE running the app
  await DatabaseHelper.instance.database;
  debugPrint("✅ SQLite Database Initialized successfully!");
  
  // 3. Launch UI
  runApp(const TindaTrackApp());
}

class TindaTrackApp extends StatelessWidget {
  const TindaTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TindaTrack',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          primary: Colors.amber.shade700,
          secondary: Colors.teal,
        ),
        useMaterial3: true,
        // Global AppBar Polish
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.amber.shade500,
          foregroundColor: Colors.black87,
          titleTextStyle: const TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
        // Global Card Polish
        cardTheme: CardThemeData(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        // Global FAB Polish
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.amber.shade600,
          foregroundColor: Colors.black87,
          elevation: 4,
        ),
      ),
      home: const MainNavScreen(),
    );
  }
}