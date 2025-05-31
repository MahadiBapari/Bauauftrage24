import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'single_order_page_screen.dart';

class AllOrdersPageScreen extends StatefulWidget {
  const AllOrdersPageScreen({super.key});

  @override
  _AllOrdersPageScreenState createState() => _AllOrdersPageScreenState();
}

class _AllOrdersPageScreenState extends State<AllOrdersPageScreen> {
  List<dynamic> _orders = [];
  List<dynamic> _filteredOrders = [];
  final Map<int, String> _orderImages = {};
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    fetchOrders();
    fetchCategories();
  }

  Future<void> fetchOrders() async {
    final response = await http.get(Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        _orders = data;
      });

      _filterOrders();

      for (var order in data) {
        List<dynamic> gallery = order['meta']?['order_gallery'] ?? [];
        if (gallery.isNotEmpty) {
          int firstImageId = gallery[0]['id'];
          final mediaUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$firstImageId';
          final mediaResponse = await http.get(Uri.parse(mediaUrl));

          if (mediaResponse.statusCode == 200) {
            final mediaData = jsonDecode(mediaResponse.body);
            final imageUrl = mediaData['media_details']?['sizes']?['full']?['source_url'] ?? mediaData['source_url'];

            setState(() {
              _orderImages[order['id']] = imageUrl;
            });
          }
        }
      }
    } else {
      print('Failed to load orders: ${response.statusCode}');
    }
  }

  Future<void> fetchCategories() async {
    final response = await http.get(Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        _categories = data;
      });
    } else {
      print('Failed to load categories: ${response.statusCode}');
    }
  }

  void _filterOrders() {
    String normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'\\s+'), '');

    final search = normalize(_searchText);

    setState(() {
      _filteredOrders = _orders.where((order) {
        final title = normalize(order['title']['rendered'].toString());
        final matchesSearch = title.contains(search);

        if (_selectedCategoryId == null) return matchesSearch;

        final orderCategories = order['order-categories'] ?? [];
        final matchesCategory = orderCategories.contains(_selectedCategoryId);

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }


 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque, // Ensures taps are registered outside widgets
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Column(
          children: [
            // 🔍 Search Bar
                Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
                  child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                    ],
                  ),
                  child: TextField(
                    //controller: _searchController,
                    decoration: InputDecoration(
                    hintText: 'Search by title...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                    suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade600),
                        onPressed: () {
                          setState(() {
                          _searchText = '';
                           // _searchController.clear();
                          });
                          _filterOrders();
                          FocusScope.of(context).unfocus();
                        },
                        )
                      : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10.0),
                    ),
                    onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                    _filterOrders();
                    },
                  ),
                  ),
                ),
                ),


// 📂 Category Filter (Improved Design)
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _categories.isEmpty
                      ? const Text("No categories available.")
                      : SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length + 1, // Include "All" chip
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final isAll = index == 0;
                              final category = isAll ? null : _categories[index - 1];
                              final id = isAll ? null : category!['id'];
                              final name = isAll ? 'All' : category!['name'];
                              final isSelected = _selectedCategoryId == id;

                              return ActionChip(
                                label: Text(name),
                                backgroundColor: isSelected
                                    ? const Color.fromARGB(255, 85, 21, 1)
                                    : Colors.grey[200],
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                onPressed: () {
                                  setState(() {
                                    // Tap again to deselect
                                    _selectedCategoryId = isSelected ? null : id;
                                  });
                                  _filterOrders(); // or _fetchNewArrivalsOrders(categoryId: _selectedCategoryId);
                                },
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),


            const SizedBox(height: 10),

            // 📦 Orders List
Expanded(
  child: _orders.isEmpty
      ? const Center(child: CircularProgressIndicator())
      : _filteredOrders.isEmpty
          ? const Center(child: Text("No orders match your criteria."))
          : ListView.builder(
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                final imageUrl = _orderImages[order['id']];
                final title = order['title']['rendered'] ?? 'Untitled';
                //final category = order['categories_names']?.join(', ') ?? 'Uncategorized';

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SingleOrderPageScreen(order: order),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: imageUrl != null && imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.4),
                                BlendMode.darken,
                              ),
                              onError: (exception, stackTrace) {
                                debugPrint('Failed to load image: $imageUrl');
                              },
                            )
                          : null,
                      gradient: (imageUrl == null || imageUrl.isEmpty)
                          ? const LinearGradient(
                              colors: [
                                Color.fromARGB(255, 85, 21, 1),
                                Color.fromARGB(255, 121, 26, 3),
                              ],
                            )
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
),

          ],
        ),
      ),
    ),
  );
}


}
