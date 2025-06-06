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
  // Loading states
  bool _isLoadingOrders = true;
  bool _isLoadingCategories = true;

  // Data lists
  List<Map<String, dynamic>> _orders = []; // Stores raw fetched orders with image URLs
  List<Map<String, dynamic>> _filteredOrders = []; // Stores orders after search/category filter
  List<Map<String, dynamic>> _categories = []; // Stores fetched categories with ID and Name

  // Filter/Search states
  int? _selectedCategoryId; // null for "All Categories"
  String _searchText = '';

  // API constants
  final String ordersEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order';
  final String categoriesEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories';
  final String mediaEndpointBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';
  final String apiKey = '1234567890abcdef'; // Assuming API key needed for user data

  @override
  void initState() {
    super.initState();
    _loadAllData(); // Start fetching all necessary data
  }

  // Combines all data fetching operations using Future.wait
  Future<void> _loadAllData() async {
    // Set initial loading states
    if (mounted) {
      setState(() {
        _isLoadingOrders = true;
        _isLoadingCategories = true;
      });
    }

    try {
      // Fetch orders and categories concurrently
      await Future.wait([
        _fetchOrders(),
        _fetchCategories(),
      ]);
    } catch (e) {
      debugPrint('Error loading all data: $e');
    } finally {
      // Ensure loading states are false even if there's an error
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
          _isLoadingCategories = false;
        });
        // Call filter after data is loaded
        _filterOrders();
      }
    }
  }

  Future<void> _fetchOrders() async {
    List<Map<String, dynamic>> fetchedOrders = [];
    try {
      final headers = <String, String>{};
      // You might need an Authorization header here if orders are protected
      // if (_authToken != null) {
      //   headers['Authorization'] = 'Bearer $_authToken';
      // }

      final response = await http.get(Uri.parse(ordersEndpoint), headers: headers);

      if (!mounted) return; // Crucial check after await

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        for (var order in data) {
          String imageUrl = '';
          List<dynamic> galleryDynamic = order['meta']?['order_gallery'] ?? [];

          // Robustly extract first image ID
          if (galleryDynamic.isNotEmpty) {
            dynamic firstItem = galleryDynamic[0];
            int? firstImageId;

            if (firstItem is Map && firstItem.containsKey('id') && firstItem['id'] is int) {
              firstImageId = firstItem['id'];
            } else if (firstItem is int) {
              firstImageId = firstItem;
            }

            if (firstImageId != null) {
              final mediaUrl = '$mediaEndpointBase$firstImageId';
              final mediaResponse = await http.get(Uri.parse(mediaUrl)); // Media endpoint generally public

              if (!mounted) return; // Crucial check after inner await

              if (mediaResponse.statusCode == 200) {
                try {
                  final mediaData = jsonDecode(mediaResponse.body);
                  // Prioritize 'source_url' directly from media endpoint, if available
                  // 'media_details.sizes.full.source_url' is more common for images from posts/pages
                  // but less common for direct media endpoint responses unless embedded.
                  imageUrl = mediaData['source_url'] ?? mediaData['media_details']?['sizes']?['full']?['source_url'] ?? '';
                } catch (e) {
                  debugPrint('Error decoding media data for ID $firstImageId: $e');
                }
              } else {
                debugPrint('Failed to fetch media for ID $firstImageId: ${mediaResponse.statusCode}');
              }
            }
          }
          // Add imageUrl directly to the order map for easier access
          order['imageUrl'] = imageUrl;
          fetchedOrders.add(order);
        }

        if (mounted) {
          setState(() {
            _orders = fetchedOrders;
            // No need to call _filterOrders here, it's called after _loadAllData
          });
        }
      } else {
        debugPrint('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _fetchCategories() async {
    List<Map<String, dynamic>> fetchedCategories = [
      {'id': null, 'name': 'All Categories'} // Add an "All Categories" option
    ];
    try {
      final response = await http.get(Uri.parse(categoriesEndpoint));

      if (!mounted) return; // Crucial check after await

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var cat in data) {
          if (cat['id'] is int && cat['name'] is String) {
            fetchedCategories.add({'id': cat['id'], 'name': cat['name']});
          }
        }
        if (mounted) {
          setState(() {
            _categories = fetchedCategories;
          });
        }
      } else {
        debugPrint('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  void _filterOrders() {
    String normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'\\s+'), '');

    final search = normalize(_searchText);

    if (mounted) { 
      setState(() {
        _filteredOrders = _orders.where((order) {
          final title = normalize(order['title']?['rendered'].toString() ?? '');
          final matchesSearch = title.contains(search);

          if (_selectedCategoryId == null) {
            return matchesSearch; // If "All Categories" is selected
          }

          final orderCategoryIds = order['order-categories'] ?? [];
          final matchesCategory = orderCategoryIds.contains(_selectedCategoryId);

          return matchesSearch && matchesCategory;
        }).toList();
      });
    }
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
                final imageUrl = order['imageUrl'] ?? '';
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
