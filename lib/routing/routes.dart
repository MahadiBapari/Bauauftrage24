import 'package:flutter/material.dart';
import '../presentation/onboarding/screens/onboarding_screen.dart';
import '../presentation/auth/screens/login_page.dart';
import '../presentation/splash/screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (context) => const SplashScreen(),
  AppRoutes.onboarding: (context) => const OnboardingScreen(),
  AppRoutes.login: (context) => const LoginPage(),
};
