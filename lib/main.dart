import 'package:card_game_ke/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // DELETED: await ProgressionService().initialize(); 
    // REASON: You cannot load progression before the user logs in!
  } catch (e) {
    print("Startup Error: $e");
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kadi Ke',
      theme: ThemeData(
        // Set a dark theme to match your design immediately
        brightness: Brightness.dark, 
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: HomeScreen(),
    );
  }
}