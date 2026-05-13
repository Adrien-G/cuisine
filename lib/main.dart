import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CuisineApp());
}

class CuisineApp extends StatelessWidget {
  const CuisineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cuisine',
      debugShowCheckedModeBanner: false,
      theme : AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}