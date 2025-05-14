import 'package:flutter/material.dart';

class SupportAndHelpPageScreen extends StatelessWidget {
  const SupportAndHelpPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text('Support and Help'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Container(
        color: const Color(0xFFFAFAFD),
        child: const Center(
          child: Text(
            'support and help page',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}