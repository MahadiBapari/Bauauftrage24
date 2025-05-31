import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Added for Future.wait
import '../all_orders_page/single_order_page_screen.dart';
// Assuming SingleOrderPageScreen is in single_order_page_screen.dart/ <--- Adjust this import path

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  String displayName = "User";
  bool isLoadingUser = true;
  bool isLoadingPromos = true;

  // New state variables for categories and new arrivals
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId; // Stores the ID of the selected category
  List<Map<String, dynamic>> _newArrivalsOrders = []; // Stores combined display and full order data
  bool isLoadingCategories = true;
  bool isLoadingNewArrivals = true;

  // This list will hold orders for the "Promo Cards" section
  List<Map<String, dynamic>> promoOrders = []; 

  String? _authToken;

  static const String apiKey = '1234567890abcdef';


  @override
  void initState() {
    super.initState();
    // Use Future.wait to fetch initial data concurrently
    _loadInitialData(); 
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('auth_token');
    });

    await Future.wait([
      _fetchUser(),
      _fetchPromoOrders(),
      _fetchCategories(),
      // Initial fetch for new arrivals without category filter
      _fetchNewArrivalsOrders(categoryId: _selectedCategoryId), 
    ]);
  }

  @override
  void dispose() {
    promoOrders.clear(); // Clear promo orders when disposing
    super.dispose();
  }

  Future<void> _fetchUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userIdString = prefs.getString('user_id');

    if (userIdString == null) {
      if(mounted) setState(() => isLoadingUser = false);
      return;
    }

    final int? userId = int.tryParse(userIdString);
    if (userId == null) {
      if(mounted) setState(() => isLoadingUser = false);
      return;
    }

    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/$userId');

    try {
      final response = await http.get(url, headers: {'X-API-Key': apiKey});

      if (!mounted) return;

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
          isLoadingUser = false;
        });
      } else {
        debugPrint('Failed to load user data: ${response.statusCode} - ${response.body}');
        if(mounted) setState(() => isLoadingUser = false);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error fetching user data: $e');
      if(mounted) setState(() => isLoadingUser = false);
    }
  }

  // --- Fetch Categories ---
  Future<void> _fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
    });

    final categoriesEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories';
    List<Map<String, dynamic>> fetchedCategories = [
      {'id': null, 'name': 'All Categories'} // Add an "All Categories" option
    ];

    try {
      final response = await http.get(Uri.parse(categoriesEndpoint));

      if (!mounted) return;

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        for (var cat in data) {
          if (cat['id'] != null && cat['name'] != null) {
            fetchedCategories.add({'id': cat['id'].toString(), 'name': cat['name']});
          }
        }
        debugPrint('Fetched ${fetchedCategories.length - 1} categories.');
      } else {
        debugPrint('Failed to load categories: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    } finally {
      if (mounted) {
        setState(() {
          _categories = fetchedCategories;
          isLoadingCategories = false;
        });
      }
    }
  }

  // --- Fetch Newest Orders (for New Arrivals section) ---
  Future<void> _fetchNewArrivalsOrders({String? categoryId}) async {
    setState(() {
      isLoadingNewArrivals = true;
    });

    String ordersEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order?_orderby=date&_order=desc&per_page=6';
    if (categoryId != null) {
      ordersEndpoint += '&order-categories=$categoryId';
    }
    const String mediaEndpointBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';

    List<Map<String, dynamic>> fetchedOrders = [];

    try {
      final headers = <String, String>{};
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final ordersResponse = await http.get(
        Uri.parse(ordersEndpoint),
        headers: headers,
      );

      if (!mounted) return;

      if (ordersResponse.statusCode == 200) {
        List<dynamic> ordersData = json.decode(ordersResponse.body);
        debugPrint('Fetched ${ordersData.length} new arrivals orders (filtered by category ID: $categoryId)');

        for (var order in ordersData) {
          String title = order['title']?['rendered'] ?? 'No Title';
          String categoryName = order['acf']?['category'] ?? 'No Category'; // This gives category name
          String imageUrl = '';

          // --- Image Fetching Logic (now using 'meta') ---
          if (order['meta'] != null && order['meta']['order_gallery'] != null) {
            if (order['meta']['order_gallery'] is List && order['meta']['order_gallery'].isNotEmpty) {
              final dynamic firstGalleryItem = order['meta']['order_gallery'][0];
              int? imageId;

              if (firstGalleryItem is Map<String, dynamic> && firstGalleryItem.containsKey('id')) {
                imageId = firstGalleryItem['id'] as int?;
              } else if (firstGalleryItem is int) {
                imageId = firstGalleryItem;
              }

              if (imageId != null) {
                final mediaUrl = Uri.parse('$mediaEndpointBase$imageId');
                final mediaResponse = await http.get(mediaUrl);
                if (!mounted) return;

                if (mediaResponse.statusCode == 200) {
                  try {
                    final mediaData = json.decode(mediaResponse.body);
                    imageUrl = mediaData['source_url'] ?? '';
                  } catch (e) {
                    debugPrint('Error decoding media data for ID $imageId: $e. Response body: ${mediaResponse.body}');
                  }
                } else {
                  debugPrint('Failed to load media for ID $imageId: ${mediaResponse.statusCode} - ${mediaResponse.body}');
                }
              }
            }
          }
          // --- End Image Fetching Logic ---

          // Store both display data and the full order object
          fetchedOrders.add({
            "displayTitle": title,
            "displayCategory": categoryName,
            "displayImageUrl": imageUrl,
            "fullOrder": order, // Store the complete order object here
          });
        }
      } else {
        debugPrint('Failed to load new arrivals: ${ordersResponse.statusCode} - ${ordersResponse.body}');
      }
    } catch (e) {
      debugPrint('Error fetching new arrivals orders: $e');
    } finally {
      if (mounted) {
        setState(() {
          _newArrivalsOrders = fetchedOrders;
          isLoadingNewArrivals = false;
        });
      }
    }
  }

  // --- EXISTING: Fetch Promo Orders (updated to store full order data) ---
  Future<void> _fetchPromoOrders() async {
    setState(() {
      isLoadingPromos = true;
    });

    final String ordersEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order';
    const String mediaEndpointBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';

    List<Map<String, dynamic>> fetchedPromoOrders = [];

    try {
      final headers = <String, String>{};
      if (_authToken != null) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final ordersResponse = await http.get(
        Uri.parse(ordersEndpoint),
        headers: headers,
      );

      if (!mounted) return;

      if (ordersResponse.statusCode == 200) {
        List<dynamic> ordersData = json.decode(ordersResponse.body);
        debugPrint('Promo Orders Fetched: ${ordersData.length} items');

        for (var order in ordersData) {
          String title = order['title']?['rendered'] ?? 'No Title';
          String categoryName = order['acf']?['category'] ?? 'No Category';
          String imageUrl = '';

          // --- Image Fetching Logic (using 'meta') ---
          if (order['meta'] != null && order['meta']['order_gallery'] != null) {
            if (order['meta']['order_gallery'] is List && order['meta']['order_gallery'].isNotEmpty) {
              final dynamic firstGalleryItem = order['meta']['order_gallery'][0];
              int? imageId;

              if (firstGalleryItem is Map<String, dynamic> && firstGalleryItem.containsKey('id')) {
                imageId = firstGalleryItem['id'] as int?;
              } else if (firstGalleryItem is int) {
                imageId = firstGalleryItem;
              }

              if (imageId != null) {
                final mediaUrl = Uri.parse('$mediaEndpointBase$imageId');
                final mediaResponse = await http.get(mediaUrl);
                if (!mounted) return;

                if (mediaResponse.statusCode == 200) {
                  try {
                    final mediaData = json.decode(mediaResponse.body);
                    imageUrl = mediaData['source_url'] ?? '';
                  } catch (e) {
                    debugPrint('Error decoding media data for ID $imageId: $e. Response body: ${mediaResponse.body}');
                  }
                } else {
                  debugPrint('Failed to load media for ID $imageId: ${mediaResponse.statusCode} - ${mediaResponse.body}');
                }
              }
            }
          }
          // --- End Image Fetching Logic ---

          // Store both display data and the full order object
          fetchedPromoOrders.add({
            "displayTitle": title,
            "displayCategory": categoryName,
            "displayImageUrl": imageUrl,
            "fullOrder": order, // Store the complete order object here
          });
        }
      } else {
        debugPrint('Failed to load orders: ${ordersResponse.statusCode} - ${ordersResponse.body}');
        if (ordersResponse.statusCode == 401) {
          debugPrint('Authentication required for orders endpoint.');
        }
      }
    } catch (e) {
      debugPrint('Error fetching promo orders: $e');
    } finally {
      if (mounted) {
        setState(() {
          promoOrders = fetchedPromoOrders;
          isLoadingPromos = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ListView(
            children: [
              Text(
                'Welcome back,',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                isLoadingUser ? "..." : displayName,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

               const SizedBox(height: 24),

              // Promo Cards displayed horizontally
              isLoadingPromos
                  ? const Center(child: CircularProgressIndicator())
                  : promoOrders.isEmpty
                      ? const Center(child: Text("No promotions available."))
                      : SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: promoOrders.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final promo = promoOrders[index];
                              // This card isn't made tappable to SingleOrderPageScreen yet.
                              // If you want it to be, uncomment the InkWell wrapper and adjust onTap.
                              return _buildOrderCard(
                                  promo["displayTitle"]!, promo["displayCategory"]!, promo["displayImageUrl"]);
                            },
                          ),
                        ),
              const SizedBox(height: 24),

              // --- UPDATED: Category Section ---
              _buildCategorySection(),
              const SizedBox(height: 20),

              // --- UPDATED: New Arrivals Section ---
              _buildNewArrivals(),
            ],
          ),
        ),
      ),
    );
  }

  // Renamed _buildPromoCard to _buildOrderCard for reusability
  // This widget is for displaying a single order card.
  Widget _buildOrderCard(String title, String category, String? imageUrl) {
    return Container(
      width: 280, 
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: imageUrl != null && imageUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.4),
                  BlendMode.darken,
                ),
                onError: (exception, stackTrace) {
                  debugPrint('NetworkImage failed to load: $imageUrl\nException: $exception');
                },
              )
            : null,
        gradient: (imageUrl == null || imageUrl.isEmpty)
            ? const LinearGradient(
                colors: [Color.fromARGB(255, 85, 21, 1), Color.fromARGB(255, 121, 26, 3)],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Category: $category",
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // --- UPDATED: _buildCategorySection ---
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        isLoadingCategories
            ? const Center(child: CircularProgressIndicator())
            : _categories.isEmpty
                ? const Text("No categories available.")
                : SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategoryId == category['id'];
                        return ActionChip(
                          label: Text(category['name']!),
                          backgroundColor: isSelected ? const Color.fromARGB(255, 85, 21, 1) : Colors.grey[200],
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          onPressed: () {
                            setState(() {
                              // If already selected, deselect (set to null)
                              // Otherwise, select the new category ID
                              _selectedCategoryId = isSelected ? null : category['id'];
                            });
                            _fetchNewArrivalsOrders(categoryId: _selectedCategoryId);
                          },
                        );
                      },
                    ),
                  ),
      ],
    );
  }

  // --- UPDATED: _buildNewArrivals ---
  Widget _buildNewArrivals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("New Arrivals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        isLoadingNewArrivals
            ? const Center(child: CircularProgressIndicator())
            : _newArrivalsOrders.isEmpty
                ? const Text("No new orders in this category.")
                : SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _newArrivalsOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final orderData = _newArrivalsOrders[index];
                        // Get display properties
                        final String title = orderData["displayTitle"]!;
                        final String category = orderData["displayCategory"]!;
                        final String? imageUrl = orderData["displayImageUrl"];
                        // Get the full order object to pass
                        final Map<String, dynamic> fullOrder = orderData["fullOrder"]!;

                        return InkWell( // Make the card tappable
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SingleOrderPageScreen(
                                  order: fullOrder, // Pass the entire order object
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 160,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              image: imageUrl != null && imageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                      colorFilter: ColorFilter.mode(
                                        Colors.black.withOpacity(0.3),
                                        BlendMode.darken,
                                      ),
                                      onError: (exception, stackTrace) {
                                        debugPrint('NetworkImage failed to load in New Arrivals: $imageUrl\nException: $exception');
                                      },
                                    )
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Spacer(),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: imageUrl != null && imageUrl.isNotEmpty ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (category.isNotEmpty && category != 'No Category')
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: imageUrl != null && imageUrl.isNotEmpty ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ],
    );
  }
}