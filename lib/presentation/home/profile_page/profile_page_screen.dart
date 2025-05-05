import 'package:flutter/material.dart';

class ProfilePageScreen extends StatelessWidget {
  const ProfilePageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'mojo jojo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text('mojojojo@email.com', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                children: [
                  _buildProfileOption(Icons.edit, 'Edit Profile', () {
                    // TODO: Add functionality
                  }),
                  _buildProfileOption(Icons.lock, 'Change Password', () {
                    // TODO: Add functionality
                  }),
                  _buildProfileOption(Icons.notifications, 'Notifications', () {
                    // TODO: Add functionality
                  }),
                  _buildProfileOption(Icons.help_outline, 'Help & Support', () {
                    // TODO: Add functionality
                  }),
                  const Divider(),
                  _buildProfileOption(Icons.logout, 'Logout', () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Logout'),
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
                  }, iconColor: Colors.red),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap,
      {Color iconColor = Colors.black87}) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
    );
  }
}
