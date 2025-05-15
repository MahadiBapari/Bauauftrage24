import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePageScreenClient extends StatefulWidget {
  const ProfilePageScreenClient({super.key});

  @override
  State<ProfilePageScreenClient> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePageScreenClient> {
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
        _showError(
            'Failed to upload image from phone. Code: ${response.statusCode}');
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
    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _userData == null
            ? const Center(child: Text('No user data available'))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: Colors.white,
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
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: _pickImageFromGallery,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _userData!['display_name'] ?? 'No name',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 30),

                      // SECTION: Personal Information
                      _buildSectionTitle('Personal Information'),
                      _buildInfoRow(
                        context,
                        'Email',
                        _userData!['user_email'] ?? 'No email',
                        Icons.email,
                      ),
                      _buildInfoRow(
                        context,
                        'Phone',
                        _userData!['meta_data']?['user_phone']?[0] ??
                            'No phone number',
                        Icons.phone,
                      ),

                      const SizedBox(height: 30),

                      // SECTION: Utilities
                      _buildSectionTitle('Utilities'),
                      _buildProfileOption(
                        context,
                        'Help & Support',
                        Icons.question_mark,
                      ),
                      _buildProfileOption(
                        context,
                        'Logout',
                        Icons.logout,
                      ),
                    ],
                  ),
                ),
              ),
  );
}

Widget _buildSectionTitle(String title) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    ),
  );
}

Widget _buildInfoRow(
  BuildContext context,
  String title,
  String value,
  IconData icon,
) {
  return Card(
    elevation: 1.5,
    margin: const EdgeInsets.symmetric(vertical: 6),
    color: const Color(0xFFF8F8F8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: Color.fromARGB(255, 88, 4, 1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
                Text(value,
                    style: TextStyle(
                        fontSize: 15, color: const Color.fromARGB(255, 121, 105, 105))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildProfileOption(
  BuildContext context,
  String title,
  IconData icon,
) {
  return GestureDetector(
    onTap: () {
      if (title == 'Logout') {
        _handleLogout(context);
      }
    },
    child: Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFFF8F8F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: Color.fromARGB(255, 88, 4, 1)),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color.fromARGB(255, 243, 239, 239)),
          ],
        ),
      ),
    ),
  );
}


  void _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
