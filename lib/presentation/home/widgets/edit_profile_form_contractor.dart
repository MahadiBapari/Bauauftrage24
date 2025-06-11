import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileFormContractor extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function onProfileUpdated;

  const EditProfileFormContractor({
    super.key,
    required this.userData,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileFormContractor> createState() =>
      _EditProfileFormContractorState();
}

class _EditProfileFormContractorState
    extends State<EditProfileFormContractor> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  // Email controller is not strictly needed if it's read-only and initialValue is used.
  // Keeping it for consistency if it might become editable in the future,
  // but initialValue on TextFormField is often enough for read-only fields.
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
    // Initialize controllers with existing user data
    _emailController.text = widget.userData['user_email'] ?? ''; // Read-only, but good to set
    _phoneController.text =
        widget.userData['meta_data']?['user_phone_']?[0] ?? '';
    _firmNameController.text =
        widget.userData['meta_data']?['firmenname_']?[0] ?? '';
    _uidNumberController.text =
        widget.userData['meta_data']?['uid_nummer']?[0] ?? '';
    _availableTimeController.text =
        widget.userData['meta_data']?['available_time']?[0] ?? '';
    _firstNameController.text =
        widget.userData['meta_data']?['first_name']?[0] ?? '';
    _lastNameController.text =
        widget.userData['meta_data']?['last_name']?[0] ?? '';
  }

  @override
  void dispose() {
    // Dispose all TextEditingControllers to prevent memory leaks
    _emailController.dispose();
    _phoneController.dispose();
    _firmNameController.dispose();
    _uidNumberController.dispose();
    _availableTimeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        'user_id': widget.userData['ID'].toString(),
        // FIX: Include the email from widget.userData['user_email'] here
        'user_email': widget.userData['user_email'] ?? '',
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'user_phone_': _phoneController.text,
        'firmenname_': _firmNameController.text,
        'uid_nummer': _uidNumberController.text,
        'available_time': _availableTimeController.text,
      };

      const apiKey = '1234567890abcdef';
      const url =
          'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/edit-user/';

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-API-Key': apiKey,
          },
          body: updatedData,
        );

        // Ensure widget is still mounted before interacting with the UI
        if (!mounted) return;

        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          widget.onProfileUpdated(); // Callback to refresh parent data
          Navigator.of(context).pop(); // Close the dialog
        } else {
          _showError(responseData['message'] ?? 'Failed to update profile.');
        }
      } catch (e) {
        _showError('Error updating profile: $e');
      }
    }
  }

  void _showError(String message) {
    // Ensure widget is still mounted before interacting with the UI
    if (!mounted) return;

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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Column( // This outer Column manages the layout of header, scrollable content, and button
        mainAxisSize: MainAxisSize.min, // Ensures dialog takes minimum vertical space
        children: [
          // Header with X icon and Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                const Text(
                  'Edit Contractor Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const SizedBox(width: 48), // To balance the close button
              ],
            ),
          ),

          const Divider(height: 1),

          // Flexible content area for the form fields
          // This allows the SingleChildScrollView to take available height and scroll if needed
          Flexible( // Use Flexible to allow content to take available height but not overflow
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, // Dismiss keyboard on scroll
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Inner column should still shrink-wrap its children
                    children: [
                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email (readonly)
                      TextFormField(
                        initialValue: widget.userData['user_email'] ?? '', // Use initialValue for readOnly
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email (not editable)',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Firm Name
                      TextFormField(
                        controller: _firmNameController,
                        decoration: const InputDecoration(
                          labelText: 'Firm Name',
                          prefixIcon: Icon(Icons.business_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // UID Number
                      TextFormField(
                        controller: _uidNumberController,
                        decoration: const InputDecoration(
                          labelText: 'UID Number',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Available Time Dropdown
                      DropdownButtonFormField<String>(
                        value: _availableTimeController.text.isNotEmpty
                            ? _availableTimeController.text
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Available Time',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: '08.00 - 12.00 Uhr',
                              child: Text('08.00 - 12.00 Uhr')),
                          DropdownMenuItem(
                              value: '12.00 - 14.00 Uhr',
                              child: Text('12.00 - 14.00 Uhr')),
                          DropdownMenuItem(
                              value: '14.00 - 18.00 Uhr',
                              child: Text('14.00 - 18.00 Uhr')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _availableTimeController.text = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 16), // Spacing after last field
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Save Button - positioned outside the scrollable area
          Padding(
            padding: const EdgeInsets.all(20), // Padding for the button
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updateProfile,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color.fromARGB(255, 185, 7, 7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}