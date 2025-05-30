import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  String displayName = "User";
  bool isLoadingUser = true;
  bool isLoadingPromos = true;
  String? _authToken;

  static const String apiKey = '1234567890abcdef';

  List<String> categories = [];
  List<Map<String, String>> products = [];
  List<Map<String, dynamic>> promoOrders = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _loadAuthTokenAndFetchAllData();
    _loadCategoriesAndProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthTokenAndFetchAllData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('auth_token');
    });
    await Future.wait([
      _fetchUser(),
      _fetchPromoOrders(),
    ]);
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
        // Note: This _fetchUser still correctly uses 'meta_data' based on its endpoint.
        // The change to 'meta' is only for _fetchPromoOrders.
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

  void _loadCategoriesAndProducts() {
    setState(() {
      categories = ["Elektriker", "Flachdach", "Gärtner", "Gipser"];
      products = [
        {"title": "DEMO 1"},
        {"title": "DEMO 2"},
        {"title": "DEMO 3"},
      ];
    });
  }

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
        debugPrint('Orders Fetched: ${ordersData.length} items');

        for (var order in ordersData) {
          String title = order['title']?['rendered'] ?? 'No Title';
          String category = order['acf']?['category'] ?? 'No Category';
          String imageUrl = '';

          // --- START Image Fetching Logic with corrected key 'meta' ---
          // CHANGED: Access 'meta' instead of 'meta_data'
          if (order['meta'] != null && order['meta']['order_gallery'] != null) {
            debugPrint('Order ID: ${order['id']}, Gallery Raw: ${order['meta']['order_gallery']}');

            // CHANGED: Access 'meta' instead of 'meta_data'
            if (order['meta']['order_gallery'] is List && order['meta']['order_gallery'].isNotEmpty) {
              final dynamic firstGalleryItem = order['meta']['order_gallery'][0];
              int? imageId;

              // Check if the item is a Map and contains 'id', or if it's just an int (ID)
              if (firstGalleryItem is Map<String, dynamic> && firstGalleryItem.containsKey('id')) {
                imageId = firstGalleryItem['id'] as int?;
              } else if (firstGalleryItem is int) {
                imageId = firstGalleryItem;
              }

              debugPrint('Extracted imageId for Order ${order['id']}: $imageId');

              if (imageId != null) {
                final mediaUrl = Uri.parse('$mediaEndpointBase$imageId');
                debugPrint('Attempting to fetch media from: $mediaUrl');

                final mediaResponse = await http.get(mediaUrl);
                if (!mounted) return;

                if (mediaResponse.statusCode == 200) {
                  try {
                    final mediaData = json.decode(mediaResponse.body);
                    imageUrl = mediaData['source_url'] ?? '';
                    debugPrint('Successfully fetched image URL for ID $imageId: $imageUrl');
                  } catch (e) {
                    debugPrint('Error decoding media data for ID $imageId: $e. Response body: ${mediaResponse.body}');
                  }
                } else {
                  debugPrint('Failed to load media for ID $imageId: ${mediaResponse.statusCode} - ${mediaResponse.body}');
                }
              } else {
                debugPrint('No valid imageId found in first gallery item for Order ${order['id']}');
              }
            } else {
              debugPrint('Order ${order['id']}: order_gallery is empty or not a list.');
            }
          } else {
            // Updated debug message to reflect checking 'meta'
            debugPrint('Order ${order['id']}: "meta" field or "order_gallery" within "meta" not found or is null.');
          }
          // --- END Image Fetching Logic ---

          fetchedPromoOrders.add({
            "title": title,
            "category": category,
            "imageUrl": imageUrl,
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
                              debugPrint('Promo Card Image URL: ${promo["imageUrl"]} for ${promo["title"]}');
                              return _buildPromoCard(
                                  promo["title"]!, promo["category"]!, promo["imageUrl"]);
                            },
                          ),
                        ),
              const SizedBox(height: 24),

              _buildCategorySection(),
              const SizedBox(height: 20),
              _buildNewArrivals(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoCard(String title, String category, String? imageUrl) {
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

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        categories.isEmpty
            ? const Text("No categories available.")
            : SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return Chip(
                      label: Text(categories[index]),
                      backgroundColor: Colors.grey[200],
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildNewArrivals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("New Arrivals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        products.isEmpty
            ? const Text("No new products.")
            : SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Text(
                            product['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}