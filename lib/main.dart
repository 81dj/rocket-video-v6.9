import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const RocketVideoApp());
}

class RocketVideoApp extends StatelessWidget {
  const RocketVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rocket Video AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}