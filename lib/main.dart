import 'package:flutter/material.dart';
import 'routing/routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Name',
      theme: ThemeData(
        //primarySwatch: Colors.blue,
        // fontFamily: 'Poppins',
        // textTheme: const TextTheme(
        //   bodyText1: TextStyle(fontSize: 16.0, color: Colors.black),
        //   bodyText2: TextStyle(fontSize: 14.0, color: Colors.black54),
        // ),
          scaffoldBackgroundColor: Color(0xFFFDF8F8), // ← your desired background color
          canvasColor: Color(0xFFFDF8F8),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromARGB(255, 255, 255, 255), // ← your desired app bar color
            //iconTheme: IconThemeData(color: Colors.black),
            //titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
      ),
      
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      routes: appRoutes,
    );
  }
}