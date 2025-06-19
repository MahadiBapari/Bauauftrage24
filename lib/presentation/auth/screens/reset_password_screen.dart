import 'dart:convert';
import 'package:bauauftrage/core/network/safe_http.dart';
import 'package:flutter/material.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _message = '';
  bool _isSuccess = false;
  bool _isLoading = false;
  final String apiKey = '1234567890abcdef'; 

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _message = 'Passwords do not match.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/custom/v1/reset-password');
    try {
      final response = await SafeHttp.safePost(
        context,
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
          },
        body: json.encode({
          'token': widget.token,
          'new_password': _newPasswordController.text,
          'confirm_password': _confirmPasswordController.text,
        }),
      );

      final responseData = json.decode(response.body);

      setState(() {
        _isLoading = false;
        if (response.statusCode == 200) {
          _message = responseData['message'] ?? 'Password reset successful.';
          _isSuccess = true;
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        } else {
          _message = responseData['message'] ?? 'Password reset failed.';
          _isSuccess = false;
        }
      });
    } catch (e) {
       setState(() {
        _isLoading = false;
        _message = 'An error occurred: $e';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 250, 250),
      appBar: AppBar(
        title: const Text('Reset Password'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 5,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 48, color: Color.fromARGB(255, 185, 7, 7)),
                  const SizedBox(height: 16),
                  const Text(
                    'Set a New Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create a new password. Ensure it is strong and secure.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter new password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty || val.length < 6 ? 'Password must be at least 6 characters' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Confirm your new password',
                      prefixIcon: const Icon(Icons.lock_person_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Confirm your password' : null,
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 185, 7, 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _resetPassword, 
                          child: const Text('Reset Password', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                  const SizedBox(height: 20),
                  if (_message.isNotEmpty)
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700, fontSize: 16, fontWeight: FontWeight.w500),
                    )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 