import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/edit_profile_form_client.dart'; // Make sure this path is correct
import '../support_and_help_page/support_and_help_page_screen.dart'; // Import the new screen

class ProfilePageScreenClient extends StatefulWidget {
  const ProfilePageScreenClient({super.key});

  @override
  State<ProfilePageScreenClient> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePageScreenClient> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  // File? _pickedImage; // Removed: No longer needed for static profile picture
  final ImagePicker _picker = ImagePicker(); // Keep if other image picking is needed
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

    // Removed: No longer loading local image path for profile picture
    // final prefs = await SharedPreferences.getInstance();
    // final localImagePath = prefs.getString('local_profile_image_path');
    // if (localImagePath != null && localImagePath.isNotEmpty) {
    //   final localImageFile = File(localImagePath);
    //   if (await localImageFile.exists()) {
    //     setState(() {
    //       _pickedImage = localImageFile;
    //     });
    //   }
    // }

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

        // Removed: No longer checking for network profile picture to use
        // if (_pickedImage == null &&
        //     data['meta_data']?['profile-picture'] != null &&
        //     (data['meta_data']['profile-picture'] as List).isNotEmpty) {
        //   // You could optionally cache the network image locally here if desired.
        // }

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

  // --- _pickImage function (still here but its use for profile pic is commented out in UI) ---
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

    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null && pickedFile.path.isNotEmpty) {
      final imageFile = File(pickedFile.path);

      if (await imageFile.exists()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_profile_image_path', imageFile.path); // Persist local path

        if (!mounted) return;
        // setState(() {
        //   _pickedImage = imageFile; // This line is commented out as we use static image
        // });

        // If you still want to upload the picked image to server even if not displayed
        // await _uploadAndLinkProfileImage(imageFile);
        if (!mounted) return;
        _showError("Profile picture is static. Image was not uploaded.");
      } else {
        if (!mounted) return;
        _showError("Selected image does not exist.");
      }
    }
  }

  // --- _uploadAndLinkProfileImage (will not be called for profile picture display) ---
  Future<void> _uploadAndLinkProfileImage(File imageFile) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final mediaId = await _uploadImageToMediaLibrary(imageFile);

    if (mediaId != null) {
      await _linkProfileImageToUser(mediaId);
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false; // Ensure loading state is reset if upload fails
        });
      }
    }
  }

  // --- _uploadImageToMediaLibrary (will not be called for profile picture display) ---
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
        final mediaId = data['id'] as int? ?? 0;
        if (mediaId > 0) {
          debugPrint('Image uploaded successfully with ID: $mediaId');
          return mediaId;
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
    }
  }

  // --- _linkProfileImageToUser (will not be called for profile picture display) ---
  Future<void> _linkProfileImageToUser(int mediaId) async {
    if (_userId == null || _authToken == null) {
      if (mounted) _showError('Missing user ID or token. Cannot update profile.');
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
            'profile-picture': [mediaId.toString()],
          },
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('Profile picture meta updated successfully!');
        await _loadUserData();
      } else {
        print('Failed to update user meta. Status: ${response.statusCode}, Body: ${response.body}');
        _showError('Failed to update profile picture: ${response.body}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error linking image to profile: $e');
      setState(() => _isLoading = false);
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

  void _showResetPasswordDialog(BuildContext context) {
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_reset, size: 48, color: Color.fromARGB(255, 185, 7, 7)),
              const SizedBox(height: 16),
              const Text(
                'Reset Password',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter your new password below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromARGB(255, 185, 7, 7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 185, 7, 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final newPass = newController.text.trim();
                        final confirm = confirmController.text.trim();
                        if (newPass != confirm) {
                          Navigator.of(ctx).pop();
                          _showError('Passwords do not match.');
                          return;
                        }
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('auth_token');
                        final userId = prefs.getString('user_id');
                        if (token == null || userId == null) {
                          Navigator.of(ctx).pop();
                          _showError('Not authenticated.');
                          return;
                        }
                        // Remove any invisible or stray characters in the URL string
                        final url = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/user/$userId/update-password';
                        try {
                          final response = await http.post(
                            Uri.parse(url),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer $token',
                              'X-API-Key': '1234567890abcdef',
                            },
                            body: json.encode({
                              'password': newPass,
                              'confirm_password': confirm,
                            }),
                          );
                          Navigator.of(ctx).pop();
                          if (response.statusCode == 200) {
                            _showError('Password changed successfully.');
                          } else {
                            _showError('Failed to change password: \\n${response.body}');
                          }
                        } catch (e) {
                          Navigator.of(ctx).pop();
                          _showError('Error: $e');
                        }
                      },
                      child: const Text('Reset', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200, // Account for app bar and bottom navigation
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
                                  child: const CircleAvatar( // Changed to const
                                    radius: 55,
                                    backgroundColor: Colors.white,
                                    backgroundImage: AssetImage('assets/images/profile.png'), // STATIC IMAGE
                                    child: null, // No child needed as we have a background image
                                  ),
                                ),
                                // Positioned(
                                //   bottom: 4,
                                //   right: 4,
                                //   child: GestureDetector(
                                //     onTap: _pickImage, // KEPT: To still allow tapping for demo/future, but gives message
                                //     child: Container(
                                //       padding: const EdgeInsets.all(6),
                                //       decoration: BoxDecoration(
                                //         shape: BoxShape.circle,
                                //         color: Theme.of(context).primaryColor,
                                //       ),
                                //       child: const Icon(Icons.camera_alt,
                                //           size: 18, color: Colors.white),
                                //     ),
                                //   ),
                                // ),
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
                                builder: (context) => EditProfileFormClient(
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
                          // _buildInfoRow(
                          //   context,
                          //   'Firm Name',
                          //   _userData!['meta_data']?['firmenname_']?[0] ??
                          //       'No firm name',
                          //   Icons.business,
                          // ),
                          // _buildInfoRow(
                          //   context,
                          //   'UID Number',
                          //   _userData!['meta_data']?['uid_nummer']?[0] ??
                          //       'No UID number',
                          //   Icons.badge,
                          // ),
                          // _buildInfoRow(
                          //   context,
                          //   'Available Time',
                          //   _userData!['meta_data']?['available_time']?[0] ??
                          //       'No Available time',
                          //   Icons.access_time,
                          // ),
                          const SizedBox(height: 30),
                          _buildSectionTitle('Utilities'),
                          _buildProfileOption(
                            context,
                            'Help & Support',
                            Icons.question_mark,
                          ),
                          _buildProfileOption(
                            context,
                            'Reset Password',
                            Icons.lock_reset,
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
                ),
    );
  }

  // --- Helper Widgets (unchanged) ---
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
            Icon(icon, color: const Color.fromARGB(255, 185, 7, 7)),
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
        } else if (title == 'Help & Support') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SupportAndHelpPageScreen(),
            ),
          );
        } else if (title == 'Reset Password') {
          _showResetPasswordDialog(context);
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
              Icon(icon, color: const Color.fromARGB(255, 185, 7, 7)),
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
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    await prefs.remove('username');
    await prefs.remove('user_email');
    await prefs.remove('displayName');
    // Add any other user/session keys you use, but DO NOT remove 'has_seen_onboarding'

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.logout, size: 48, color: const Color.fromARGB(255, 185, 7, 7)),
          const SizedBox(height: 16),
          const Text(
          'Logout',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
          'Are you sure you want to logout?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          Row(
          children: [
            Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 185, 7, 7),
                ),
              ),
            ),
            ),
            const SizedBox(width: 12),
            Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 185, 7, 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Logout', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            ),
          ],
          ),
        ],
        ),
      ),
      ),
    );
  }
}