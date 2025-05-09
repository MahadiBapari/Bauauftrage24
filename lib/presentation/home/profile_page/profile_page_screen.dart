import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePageScreen extends StatefulWidget {
  const ProfilePageScreen({super.key});

  @override
  State<ProfilePageScreen> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePageScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  final String apiKey = '1234567890abcdef';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      _showError('User ID not found');
      return;
    }

    final url = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/$userId';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      } else {
        _showError('Failed to load profile: ${response.body}');
      }
    } catch (e) {
      _showError('Error: $e');
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
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('No user data available'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Align items to the start
                    children: [
                      Center( // Center the CircleAvatar
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              _userData!['meta_data']?['profile_image_url'] != null
                                  ? NetworkImage(
                                      _userData!['meta_data']?['profile_image_url']?[0] ??
                                          '')
                                  : null,
                          child: _userData!['meta_data']?['profile_image_url'] == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center( //Center the name and email
                        child: Text(
                          _userData!['display_name'] ?? 'No name',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Center(
                        child: Text(
                          _userData!['user_email'] ?? 'No email',
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildProfileOption(context, 'Edit Profile', Icons.edit),
                      _buildProfileOption(
                          context, 'Change Password', Icons.lock),
                      _buildProfileOption(
                          context, 'Notifications', Icons.notifications),
                      _buildProfileOption(
                          context, 'Help & Support', Icons.question_mark), 
                      _buildProfileOption(context, 'Logout', Icons.logout),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileOption(
      BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: GestureDetector(
        onTap: () {
          // Handle the tap,  Add navigation or functionality here
          if (title == 'Logout') {
             _showLogoutDialog();
          }
        },
        child: Row(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.grey), 
          ],
        ),
      ),
    );
  }
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Implement logout logic here
                // Clear shared preferences, navigate to login, etc.
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // Clear all data
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login'); // Navigate to login
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

