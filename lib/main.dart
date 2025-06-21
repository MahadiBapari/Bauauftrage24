import 'dart:async';
import 'package:bauauftrage/presentation/auth/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'routing/routes.dart';
import 'package:provider/provider.dart';
import 'common/themes/theme_notifier.dart';

final Color primaryColor = const Color(0xFFB90707);

final ThemeData lightTheme = ThemeData.light().copyWith(
  primaryColor: primaryColor,
  scaffoldBackgroundColor: const Color(0xFFFDF8F8),
  canvasColor: const Color(0xFFFDF8F8),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    iconTheme: IconThemeData(color: Colors.black),
    titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
    elevation: 0,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: Colors.white,
  ),
  colorScheme: ColorScheme.light(
    primary: primaryColor,
    secondary: Colors.black,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black),
    bodyMedium: TextStyle(color: Colors.black87),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  ),
);

final ThemeData darkTheme = ThemeData.dark().copyWith(
  primaryColor: primaryColor,
  scaffoldBackgroundColor: const Color(0xFF18191A),
  canvasColor: const Color(0xFF18191A),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF23272B),
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    elevation: 0,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: Color(0xFF23272B),
  ),
  colorScheme: ColorScheme.dark(
    primary: primaryColor,
    secondary: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set Stripe publishable key
  Stripe.publishableKey = 'pk_live_51R4IEKGByhgsCrrfWagwRb319gQEyYPq8Rjny4TAB0kzXr1F9UsXYiIsxCdS6negbScfR6PYKpctD9NHyP1ClC1a00sxj2EKv5';
  
  // For Apple Pay (and to ensure initialization is awaited)
  Stripe.merchantIdentifier = 'merchant.flutter.stripe.test';
  await Stripe.instance.applySettings();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Listen for incoming links while the app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (mounted) {
        _handleDeepLink(uri);
      }
    });

    // Handle the link that started the app
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      // Handle error
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path.contains('/reset-password')) {
      final token = uri.queryParameters['token'];
      if (token != null) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(token: token),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Your App Name',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          initialRoute: AppRoutes.splash,
          routes: appRoutes,
        );
      },
    );
  }
}