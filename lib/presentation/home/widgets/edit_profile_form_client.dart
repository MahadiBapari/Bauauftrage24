import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EditProfileFormClient extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function onProfileUpdated;

  const EditProfileFormClient({
    super.key,
    required this.userData,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileFormClient> createState() => _EditProfileFormClientState();
}

class _EditProfileFormClientState extends State<EditProfileFormClient> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firmNameController = TextEditingController();
  final _uidNumberController = TextEditingController();
  final _availableTimeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Set values from userData
    _emailController.text = widget.userData['user_email'] ?? '';
    _phoneController.text = widget.userData['meta_data']?['user_phone_']?[0] ?? '';
    _firstNameController.text = widget.userData['meta_data']?['first_name']?[0] ?? '';
    _lastNameController.text = widget.userData['meta_data']?['last_name']?[0] ?? '';
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        'user_id': widget.userData['ID'].toString(),
        'email': _emailController.text,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'user_phone_': _phoneController.text,
       
      };

      const apiKey = '1234567890abcdef';
      const url = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/edit-user/';

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-API-Key': apiKey,
          },
          body: updatedData,
        );

        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          widget.onProfileUpdated();
          Navigator.of(context).pop();
        } else {
          _showError(responseData['message'] ?? 'Failed to update profile.');
        }
      } catch (e) {
        _showError('Error updating profile: $e');
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value == null || !value.contains('@') ? 'Enter a valid email' : null,
              ),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
           
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateProfile,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
