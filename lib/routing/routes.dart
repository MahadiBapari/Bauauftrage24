import 'package:flutter/material.dart';
import '../presentation/onboarding/screens/onboarding_screen.dart';
import '../presentation/auth/screens/login_page.dart';
import '../presentation/auth/screens/register_client_screen.dart';
import '../presentation/auth/screens/register_contractor_screen.dart';
import '../presentation/splash/screens/splash_screen.dart';
import '../presentation/home/main_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String registerClient = '/register_client';
  static const String registerContractor = '/register_contractor';
  static const String home = '/home';

}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (context) => const SplashScreen(),
  AppRoutes.onboarding: (context) => const OnboardingScreen(),
  AppRoutes.login: (context) => const LoginPage(),
  AppRoutes.registerClient: (context) => const RegisterClientPage(), 
  AppRoutes.registerContractor: (context) => const RegisterContractorPage(),
  AppRoutes.home: (context) => const MainScreen(),
};