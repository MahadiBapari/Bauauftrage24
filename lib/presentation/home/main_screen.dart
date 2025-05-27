import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();

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
        const MyFavouritePageScreen(key: ValueKey('my_favourite_page')),
        AllOrdersPageScreen(key: ValueKey('all_orders_page'))
      ];

      _icons = [Icons.home, Icons.person, Icons.favorite, Icons.shopping_bag];
      _labels = ['Home', 'Profile', 'Favorites', 'All Orders'];
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
    setState(() => _selectedIndex = index);
  }


  @override
  Widget build(BuildContext context) {
    bool isClient = widget.role == 'um_client';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: const Text('Dashboard'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: AppDrawer(
        role: widget.role,
        onItemTap: _onItemTapped,
        onNavigateToSupport: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SupportAndHelpPageScreen(),
            ),
          );
        },
        onNavigateToMyMembership: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyMembershipPageScreen(),
            ),
          );
        },
        //onNavigateToMyOrders: _navigateToMyOrders,
      ),
      body: _screens[_selectedIndex],
      floatingActionButton: isClient
          ? FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 77, 2, 2),
              elevation: 6,
              onPressed: () {
                _onItemTapped(2); // Navigate to AddNewOrder screen
              },
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 32,
                weight: 800, // Boldness (if Flutter 3.10+)
              ),
              tooltip: 'Add New Order',
              shape: const CircleBorder(),
            )
          : null,
      floatingActionButtonLocation: isClient
          ? FloatingActionButtonLocation.centerDocked
          : null,
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

