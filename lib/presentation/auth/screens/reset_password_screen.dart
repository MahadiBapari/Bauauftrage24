import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
          },
        body: json.encode({
          'token': widget.token,
          'password': _newPasswordController.text,
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
        appBar: AppBar(title: const Text('Reset Password')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New Password'),
                      validator: (val) =>
                          val == null || val.isEmpty || val.length < 6 ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm Password'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Confirm your password' : null,
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _resetPassword, 
                            child: const Text('Reset Password')
                          ),
                    const SizedBox(height: 20),
                    if (_message.isNotEmpty)
                      Text(
                        _message,
                        style: TextStyle(
                            color: _isSuccess ? Colors.green : Colors.red, fontSize: 16),
                      )
                  ],
                ),
              )
            ],
          ),
        ));
  }
} 