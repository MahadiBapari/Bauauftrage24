import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Bauaufträge24',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 143, 23, 15), // Match the color in the image
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 8),
            const Text(
              'Log in',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 24),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'E-mail',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              obscureText: true, // Hide the password
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: const Icon(Icons.visibility_outlined), // Eye icon
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Implement your login logic here
                print('Log in button pressed');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800, // Match the button color
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'Log in',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Implement forgot password logic
                print('Forgot Password? pressed');
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
        
            const SizedBox(height: 32),
            // You can add social login buttons here if needed
            const Spacer(), // Pushes the register text to the bottom
            TextButton(
              onPressed: () {
                // Navigate to the registration page
                print("Register pressed");
                Navigator.pushNamed(context, '/register'); // Assuming you have a '/register' route
              },
              child: const Text(
                "Haven't an account? Register",
                style: TextStyle(color: Color.fromARGB(255, 143, 23, 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}