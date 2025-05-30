import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/edit_profile_form_contractor.dart'; // Make sure this path is correct

class ProfilePageScreenContractor extends StatefulWidget {
  const ProfilePageScreenContractor({super.key});

  @override
  State<ProfilePageScreenContractor> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePageScreenContractor> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  File? _pickedImage; // To hold the locally picked image
  final ImagePicker _picker = ImagePicker(); // Image picker instance
  final String apiKey = '1234567890abcdef'; // Your actual API key.

  String? _authToken; // Store auth token
  String? _userId;    // Store user ID

  @override
  void initState() {
    super.initState();
    _initAndLoadUserData(); // Combined initialization and data loading
  }

  // A new method to handle async initialization for initState
  Future<void> _initAndLoadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
    await _loadUserData(); // Proceed to load user data from API
  }

  Future<void> _loadUserData() async {
    if (!mounted) return; // Always check mounted before setState or context operations

    if (_userId == null) {
      _showError('User ID not found');
      setState(() => _isLoading = false);
      return;
    }

    // Load local image path first
    final prefs = await SharedPreferences.getInstance(); // Re-get prefs if needed
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
        'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/$_userId';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // If no local image was picked and the network data has a profile picture,
        // use the network picture for display.
        if (_pickedImage == null &&
            data['meta_data']?['profile-picture'] != null &&
            (data['meta_data']['profile-picture'] as List).isNotEmpty) {
          // You could optionally cache the network image locally here if desired.
        }

        setState(() {
          _userData = data;
          _isLoading = false;
        });
      } else {
        _showError('Failed to load profile: ${response.body}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  // --- UPDATED _pickImage function for single image and autosave ---
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text("Gallery"),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera),
            title: const Text("Camera"),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source == null) return; // User cancelled selection

    // --- Only pick a single image ---
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null && pickedFile.path.isNotEmpty) {
      final imageFile = File(pickedFile.path);

      if (await imageFile.exists()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_profile_image_path', imageFile.path); // Persist local path

        if (!mounted) return;
        setState(() {
          _pickedImage = imageFile; // Immediately show the picked image locally
        });

        // --- AUTOSAVE: Directly trigger upload and link ---
        await _uploadAndLinkProfileImage(imageFile); // Auto-save
      } else {
        if (!mounted) return;
        _showError("Selected image does not exist.");
      }
    }
  }

  // --- _uploadAndLinkProfileImage (orchestrates upload to media library and linking) ---
  Future<void> _uploadAndLinkProfileImage(File imageFile) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final mediaId = await _uploadImageToMediaLibrary(imageFile);

    if (mediaId != null) {
      await _linkProfileImageToUser(mediaId);
    } else {
      // Error message already shown by _uploadImageToMediaLibrary if it failed
      if (mounted) {
        setState(() {
          _isLoading = false; // Ensure loading state is reset if upload fails
        });
      }
    }
  }

  // --- _uploadImageToMediaLibrary (uploads to wp/v2/media) ---
Future<int?> _uploadImageToMediaLibrary(File imageFile) async {
  
  try {
    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media');
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll({
        'Authorization': 'Bearer $_authToken',
        'X-API-Key': apiKey,
        'Content-Disposition': 'attachment; filename="${path.basename(imageFile.path)}"',
      })
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      final data = jsonDecode(responseBody);
      final mediaId = data['id'] as int? ?? 0;// Ensure media ID is an int
      if (mediaId > 0) {
        debugPrint('Image uploaded successfully with ID: $mediaId');
        return mediaId; // Return the media ID for linking
      } else {
        debugPrint('Image upload returned no valid media ID: $responseBody');
        _showError('Image upload failed: No valid media ID returned.');
        return null;
      }
    } else {
      debugPrint('Image upload failed with status ${response.statusCode}: $responseBody');
      _showError('Image upload failed: $responseBody');
      return null;
    }
  } catch (e) {
    debugPrint('Exception during image upload: $e');
    _showError('Exception during image upload: $e');
    return null;
  } // Return the upload ID if needed

}

  // --- _linkProfileImageToUser (links media ID to user meta) ---
  Future<void> _linkProfileImageToUser(int mediaId) async {
    if (_userId == null || _authToken == null) {
      if (mounted) _showError('Missing user ID or token. Cannot update profile.');
      // setState(() => _isLoading = false); // Will be handled by _uploadAndLinkProfileImage
      return;
    }

    final url =
        'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/edit-user/$_userId';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
          'X-API-Key': apiKey, 
        },
        body: json.encode({
          'meta_input': {
            'profile-picture': [mediaId.toString()], // Ensure it's a LIST of string IDs
          },
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('Profile picture meta updated successfully!');
        // Reload user data to get the updated profile-picture URL from the server
        await _loadUserData(); // This will also set _isLoading to false upon completion
      } else {
        print('Failed to update user meta. Status: ${response.statusCode}, Body: ${response.body}');
        _showError('Failed to update profile picture: ${response.body}');
        setState(() => _isLoading = false); // Stop loading on failure
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error linking image to profile: $e');
      setState(() => _isLoading = false); // Stop loading on exception
    }
  }

  void _showError(String message) {
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
                                    const BoxShadow(
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
                                      ? FileImage(_pickedImage!) // Display local image if picked
                                      : (_userData?['meta_data']?['profile-picture'] != null &&
                                              (_userData!['meta_data']['profile-picture'] as List).isNotEmpty)
                                          ? NetworkImage(_userData!['meta_data']['profile-picture'][0]) // Otherwise network image
                                          : null,
                                  child: _pickedImage == null &&
                                          (_userData?['meta_data']?['profile-picture'] == null ||
                                              (_userData!['meta_data']['profile-picture'] as List).isEmpty)
                                      ? const Icon(Icons.person, size: 50) // Default icon
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: _pickImage, // This triggers local image picking and then autosave
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
                        // Removed the "Save Profile Image" button as it's now autosave
                        const SizedBox(height: 12),
                        Text(
                          '${_userData!['meta_data']?['first_name']?[0] ?? ''} ${_userData!['meta_data']?['last_name']?[0] ?? ''}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 30),
                        _buildSectionTitle(
                          'Personal Information',
                          onEditTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => EditProfileFormContractor(
                                userData: _userData!,
                                onProfileUpdated: _loadUserData,
                              ),
                            );
                          },
                        ),
                        _buildInfoRow(
                          context,
                          'Email',
                          _userData!['user_email'] ?? 'No email',
                          Icons.email,
                        ),
                        _buildInfoRow(
                          context,
                          'Phone',
                          _userData!['meta_data']?['user_phone_']?[0] ??
                              'No phone number',
                          Icons.phone,
                        ),
                        _buildInfoRow(
                          context,
                          'Firm Name',
                          _userData!['meta_data']?['firmenname_']?[0] ??
                              'No firm name',
                          Icons.business,
                        ),
                        _buildInfoRow(
                          context,
                          'UID Number',
                          _userData!['meta_data']?['uid_nummer']?[0] ??
                              'No UID number',
                          Icons.badge,
                        ),
                        _buildInfoRow(
                          context,
                          'Available Time',
                          _userData!['meta_data']?['available_time']?[0] ??
                              'No Available time',
                          Icons.access_time,
                        ),
                        const SizedBox(height: 30),
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

  // --- Helper Widgets (unchanged, just included for completeness) ---
  Widget _buildSectionTitle(String title, {VoidCallback? onEditTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Align(
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
        ),
        if (onEditTap != null)
          InkWell(
            onTap: onEditTap,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 18, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ],
              ),
            ),
          ),
      ],
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
            Icon(icon, color: const Color.fromARGB(255, 88, 4, 1)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15,
                          color: Color.fromARGB(255, 121, 105, 105))),
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
              Icon(icon, color: const Color.fromARGB(255, 88, 4, 1)),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontSize: 16)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Color.fromARGB(255, 243, 239, 239)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

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