import 'package:flutter/material.dart';
import 'home_page/home_page_screen.dart';
import '../home/profile_page/profile_page_screen_contractor.dart';
import '../home/profile_page/profile_page_screen_client.dart';
import '../home/my_favourite_page/my_favourite_page_screen.dart';
import '../home/all_orders_page/all_orders_page_screen.dart';
import '../home/add_new_order_page/add_new_order_page_screen.dart';
import '../home/my_membership_page/my_membership_page_screen.dart';
import '../home/my_order_page/my_order_page_screen.dart';
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
  late final List<BottomNavigationBarItem> _bottomNavItems;

  @override
  void initState() {
    super.initState();

    if (widget.role == 'um_client') {
      _screens = [
        const HomePageScreen(key: ValueKey('home_page')),
        const ProfilePageScreenClient(key: ValueKey('profile_page')),
        const AddNewOrderPageScreen(key: ValueKey('add_new_order_page')),
        const MyOrderPageScreen(key: ValueKey('my_order_page')),
      ];

      _bottomNavItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        BottomNavigationBarItem(icon: Icon(Icons.add_shopping_cart), label: 'Add Order'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'My Orders'),
      ];
    } else if (widget.role == 'um_contractor') {
      _screens = [
        const HomePageScreen(key: ValueKey('home_page')),
        const ProfilePageScreenContractor(key: ValueKey('profile_page')),
        const MyFavouritePageScreen(key: ValueKey('my_favourite_page')),
        const AllOrdersPageScreen(key: ValueKey('all_orders_page')),
      ];

      _bottomNavItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'All Orders'),
      ];
    } else {
      _screens = [
        const HomePageScreen(key: ValueKey('home_page')),
        const ProfilePageScreenClient(key: ValueKey('profile_page')),
      ];
      _bottomNavItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ];
    }
  }

  void _onItemTapped(int index) {
    if (mounted && index < _screens.length) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFD),
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
        // Removed onNavigateToMyContractor since it's in bottomNav now
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: _bottomNavItems.isNotEmpty
          ? BottomNavigationBar(
              backgroundColor: const Color.fromARGB(255, 255, 246, 246),
              items: _bottomNavItems,
              currentIndex: _selectedIndex,
              unselectedItemColor: const Color.fromARGB(255, 88, 4, 1),
              selectedItemColor: const Color.fromARGB(255, 61, 14, 10),
              onTap: _onItemTapped,
            )
          : null,
    );
  }
}
