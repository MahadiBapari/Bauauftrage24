import 'package:flutter/material.dart';

class MyMembershipPageScreen extends StatelessWidget {
  const MyMembershipPageScreen({super.key});

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
        title: const Text('My membership'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Container(
        color: const Color(0xFFFAFAFD),
        child: const Center(
          child: Text(
            'membership page',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}