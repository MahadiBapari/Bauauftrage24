import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

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

    final localImagePath = prefs.getString('local_profile_image_path');
    if (localImagePath != null && localImagePath.isNotEmpty) {
      final localImageFile = File(localImagePath);
      if (await localImageFile.exists()) {
        setState(() {
          _pickedImage = localImageFile;
        });
      }
    }

    final url =
        'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/$userId';

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

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && image.path.isNotEmpty) {
      final imagePath = image.path;
      final imageFile = File(imagePath);

      if (await imageFile.exists()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_profile_image_path', imagePath);

        setState(() {
          _pickedImage = imageFile;
        });

        await _uploadProfileImage(imageFile);
      } else {
        _showError("Selected image does not exist.");
      }
    } else {
      _showError("Failed to pick image.");
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) {
      _showError('User ID not found');
      return;
    }

    final url =
        'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/edit-user/$userId';

    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers['X-API-Key'] = apiKey
      ..fields['meta_fields[profile-picture]'] = ''
      ..files.add(await http.MultipartFile.fromPath(
        'meta_files[profile-picture]',
        imageFile.path,
      ));

    try {
      final response = await request.send();

      if (response.statusCode == 200) {
        _loadUserData(); // Refresh profile data after upload
      } else {
        _showError('Failed to upload image from phone. Code: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Upload error: $e');
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
      backgroundColor: const Color(0xFFFAFAFD),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('No user data available'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _pickImageFromGallery,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: _pickedImage != null
                                    ? FileImage(_pickedImage!)
                                    : (_userData?['meta_data']
                                                    ?['profile-picture'] !=
                                                null &&
                                            (_userData!['meta_data']
                                                        ['profile-picture']
                                                    as List)
                                                .isNotEmpty)
                                        ? NetworkImage(
                                            _userData!['meta_data']
                                                ['profile-picture'][0])
                                        : null,
                                child: _pickedImage == null &&
                                        (_userData?['meta_data']
                                                    ?['profile-picture'] ==
                                                null ||
                                            (_userData!['meta_data']
                                                        ['profile-picture']
                                                    as List)
                                                .isEmpty)
                                    ? const Icon(Icons.person, size: 50)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickImageFromGallery,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.grey.shade800,
                                    child: const Icon(Icons.camera_alt,
                                        size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _userData!['display_name'] ?? 'No name',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Center(
                        child: Text(
                          _userData!['user_email'] ?? 'No email',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.grey),
                        ),
                      ),
                      Center(
                        child: Text(
                          _userData!['meta_data']?['user_phone']?[0] ??
                              'No phone number',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.grey),
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
            const Icon(Icons.arrow_forward_ios, color: Colors.grey),
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
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
