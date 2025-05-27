import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../my_order_page/my_order_page_screen.dart'; // Make sure this is imported

class AppDrawer extends StatelessWidget {
  final String role;
  final Function(int) onItemTap;
  final VoidCallback? onNavigateToSupport;
  final VoidCallback? onNavigateToMyMembership;

  const AppDrawer({
    super.key,
    required this.role,
    required this.onItemTap,
    this.onNavigateToSupport,
    this.onNavigateToMyMembership,
  });

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

  @override
  Widget build(BuildContext context) {
    List<Widget> menuItems = [];

    if (role == 'um_client') {
      menuItems = [
        _buildTile(Icons.home, 'Feed', 0, context),
        _buildTile(Icons.person, 'Profile', 1, context),
        _buildTile(Icons.add_shopping_cart, 'Add new order', 2, context),

        // 🆕 My Orders (client only)
        ListTile(
          leading: const Icon(Icons.shopping_cart),
          title: const Text('My Orders'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyOrderPageScreen()),
            );
          },
        ),
      ];
    } else if (role == 'um_contractor') {
      menuItems = [
        _buildTile(Icons.home, 'Feed', 0, context),
        _buildTile(Icons.person, 'Profile', 1, context),
        _buildTile(Icons.favorite, 'Favorites', 2, context),
        _buildTile(Icons.shopping_bag, 'All Orders', 3, context),
      ];
    }

    return Drawer(
      backgroundColor: const Color(0xFFFAFAFD),
      child: ListView(
        children: [
          ...menuItems,

          // Partners (for both roles)
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Partners'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/partners');
            },
          ),

          // My Membership (contractor only)
          if (role == 'um_contractor')
            ListTile(
              leading: const Icon(Icons.card_membership),
              title: const Text('My membership'),
              onTap: () {
                Navigator.pop(context);
                onNavigateToMyMembership?.call();
              },
            ),

          // Support and Help
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Support and help'),
            onTap: () {
              Navigator.pop(context);
              onNavigateToSupport?.call();
            },
          ),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  ListTile _buildTile(IconData icon, String label, int index, BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        onItemTap(index);
      },
    );
  }
}
