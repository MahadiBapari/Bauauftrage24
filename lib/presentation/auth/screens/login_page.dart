import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false; 

  Future<void> login() async {
    const url = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/login/';
    const apiKey = '1234567890abcdef';

    if (_isLoading) return;  // Prevent multiple login attempts
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: json.encode({
          'username': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        final userId = responseData['user_id']?.toString();
        final username = responseData['username'] ?? 'Unknown User';
        final email = responseData['email'] ?? '';
        final displayName = responseData['display_name'] ?? '';
        final role = responseData['role'];
        final token = responseData['token'];

        if (userId != null && token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', userId);
          await prefs.setString('username', username);
          await prefs.setString('user_email', email);
          await prefs.setString('displayName', displayName);
          await prefs.setString('user_role', role);
          await prefs.setString('auth_token', token);

          print('Login successful! Token: $token'); //debugging
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (Route<dynamic> route) => false,
            arguments: {'role': role},
          );
        } else {
          _showError('Login failed: Email or password is wrong');
        }
      } else {
        _showError('Login failed: Email or password is wrong');
      }
    } catch (e) {
      _showError('Login failed: Email or password is wrong');
    } finally {
      if (mounted) { //check mounted
         setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return; //check mounted
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK',
              style: TextStyle(color: Color.fromARGB(255, 185, 7, 7)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Image.asset(
                  'assets/images/logo.png',
                  height: 100,
                ),
                const SizedBox(height: 30),
                const Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Log in to your account to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Add forgot password logic
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => login(), 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Log In'),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        "Don't have an account?",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                      icon: const Icon(Icons.person_outline, color: Color.fromARGB(255, 185, 7, 7)),
                      onPressed: () {
                        Navigator.pushNamed(context, '/register_client');
                      },
                      label: const Text(
                        'Register as Client',
                        style: TextStyle(color: Color.fromARGB(255, 185, 7, 7)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: Color.fromARGB(255, 185, 7, 7),
                      ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton.icon(
                      icon: const Icon(Icons.business_center_outlined, color: Color.fromARGB(255, 185, 7, 7)),
                      onPressed: () {
                        Navigator.pushNamed(context, '/register_contractor');
                      },
                      label: const Text(
                        'Register as Contractor',
                        style: TextStyle(color: Color.fromARGB(255, 185, 7, 7)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: Color.fromARGB(255, 185, 7, 7),
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