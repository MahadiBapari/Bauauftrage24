import 'package:flutter/material.dart';
import 'routing/routes.dart';
import 'presentation/splash/screens/splash_screen.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Name',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      routes: appRoutes,
    );
  }
}