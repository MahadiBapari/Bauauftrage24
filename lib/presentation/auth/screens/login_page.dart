import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false; 

  Future<void> login() async {
    const url = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/login/';
    const apiKey = '1234567890abcdef'; 

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': apiKey,
        },
        body: json.encode({
          'username': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        // Handle success
        print('Login successful!'); //  Good practice to log
        Navigator.pushReplacementNamed(context, '/home'); // Go to homepage
      } else {
        // Handle error.  Important to provide user feedback.
        print('Login failed: ${response.body}'); // Log the error
        _showErrorSnackBar('Login failed: ${response.body}');
      }
    } catch (e) {
      // Catch any exceptions, such as network errors.
      print('Error during login: $e');
      _showErrorSnackBar('Error: $e'); // Show error to user
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red, //  make error more obvious
      ),
    );
  }

  @override
  void dispose() {
    //  Clean up controllers when the widget is disposed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Match the background
      body: Padding(
        padding: const EdgeInsets.all(20.0), // Slightly reduced padding
        child: Center(
          child: SingleChildScrollView( // Make the whole screen scrollable
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Logo (replace with your actual logo asset)
                Image.asset(
                  'assets/images/logo.png', //  Placeholder
                  height: 80, // Adjust as needed
                ),
                const SizedBox(height: 20),
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Consistent text color
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                // Email Text Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email_outlined), // Use the outlined version
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  style: const TextStyle(color: Colors.black), // Ensure text color is black
                ),
                const SizedBox(height: 16),
                // Password Text Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible, // Use the boolean
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton( // Added for password visibility
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 24),
                // Login Button
                ElevatedButton(
                  onPressed: login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800, // Match the button color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Log In'),
                ),
                const SizedBox(height: 16),
                // Forgot Password?
                TextButton(
                  onPressed: () {
                    //  Add navigation
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.grey), //  color
                  ),
                ),
                const SizedBox(height: 20),
                // Don't have an account? Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Haven't an account? ",
                      style: TextStyle(color: Colors.black),
                    ),
                    GestureDetector(
                      onTap: () {
                        //  Add navigation
                      },
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          color: Color.fromARGB(255, 180, 43, 41), // Match the "Register" color
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

