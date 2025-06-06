import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Replace these with your actual imports
import 'home_page/home_page_screen.dart';
import '../home/profile_page/profile_page_screen_contractor.dart';
import '../home/profile_page/profile_page_screen_client.dart';
import '../home/my_favourite_page/my_favourite_page_screen.dart';
import '../home/all_orders_page/all_orders_page_screen.dart';
import '../home/add_new_order_page/add_new_order_page_screen.dart';
import '../home/my_membership_page/my_membership_page_screen.dart';
import '../home/support_and_help_page/support_and_help_page_screen.dart';
import '../home/widgets/app_drawer.dart';

class MainScreen extends StatefulWidget {
  final String role;

  const MainScreen({super.key, required this.role});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;
  late final List<IconData> _icons;
  late final List<String> _labels;

  bool isLoading = true;
  String displayName = 'User';

  @override
  void initState() {
    super.initState();
    _initializeScreens();
    _fetchUser();
  }

void _initializeScreens() {
  if (widget.role == 'um_client') {
    _screens = [
      const HomePageScreen(key: ValueKey('home_page')),
      const ProfilePageScreenClient(key: ValueKey('profile_page')),
      const AddNewOrderPageScreen(key: ValueKey('add_new_order_page')),
    ];
    _icons = [Icons.home, Icons.person];
    _labels = ['Home', 'Profile'];
  } else if (widget.role == 'um_contractor') {
    _screens = [
      const HomePageScreen(key: ValueKey('home_page')),
      const ProfilePageScreenContractor(key: ValueKey('profile_page')),
      const MyMembershipPageScreen(key: ValueKey('my_membership_page')),
      AllOrdersPageScreen(key: ValueKey('all_orders_page')),
    ];
    _icons = [Icons.home, Icons.person, Icons.workspace_premium, Icons.shopping_bag];
    _labels = ['Home', 'Profile', 'Membership', 'All Orders'];
  } else {
    _screens = [
      const HomePageScreen(key: ValueKey('home_page')),
      const ProfilePageScreenClient(key: ValueKey('profile_page')),
    ];
    _icons = [Icons.home, Icons.person];
    _labels = ['Home', 'Profile'];
  }
}


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

Future<void> _fetchUser() async {
  final prefs = await SharedPreferences.getInstance();

  // Get user_id as String and try to convert
  final userIdString = prefs.getString('user_id');
  if (userIdString == null) {
    setState(() {
      isLoading = false;
    });
    return;
  }

  final int? userId = int.tryParse(userIdString);
  if (userId == null) {
    setState(() {
      isLoading = false;
    });
    return;
  }

  final String apiKey = '1234567890abcdef';
  final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/$userId');
  final response = await http.get(url, headers: {
    'X-API-Key': apiKey,
  });

  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    final metaData = data['meta_data'];
    final List<dynamic>? firstNameList = metaData?['first_name'];
    final List<dynamic>? lastNameList = metaData?['last_name'];

    final firstName = (firstNameList != null && firstNameList.isNotEmpty) ? firstNameList[0] : '';
    final lastName = (lastNameList != null && lastNameList.isNotEmpty) ? lastNameList[0] : '';

    setState(() {
      displayName = '${firstName.trim()} ${lastName.trim()}'.trim().isEmpty
          ? 'User'
          : '${firstName.trim()} ${lastName.trim()}';
      isLoading = false;
    });
  } else {
    setState(() {
      isLoading = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    bool isClient = widget.role == 'um_client';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'BAUAUFTRÄGE24',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 24, 2, 0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      
      drawer: AppDrawer(
        role: widget.role,
        onItemTap: _onItemTapped,
        onNavigateToSupport: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportAndHelpPageScreen()),
          );
        },
        onNavigateToMyMembership: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyMembershipPageScreen()),
          );
        },
      ),
      body: _screens[_selectedIndex],
      floatingActionButton: isClient
          ? FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 77, 2, 2),
              elevation: 6,
              onPressed: () => _onItemTapped(2),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
              tooltip: 'Add New Order',
              shape: const CircleBorder(),
            )
          : null,
      floatingActionButtonLocation:
          isClient ? FloatingActionButtonLocation.centerDocked : null,
      bottomNavigationBar: BottomAppBar(
        color: const Color.fromARGB(255, 255, 250, 250),
        shape: isClient ? const CircularNotchedRectangle() : null,
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_icons.length, (index) {
            return IconButton(
              icon: Icon(
                _icons[index],
                color: _selectedIndex == index
                    ? const Color.fromARGB(255, 61, 14, 10)
                    : const Color.fromARGB(255, 88, 4, 1),
                size: 32,
              ),
              onPressed: () => _onItemTapped(index),
              tooltip: _labels[index],
            );
          }),
        ),
      ),
    );
  }
}
