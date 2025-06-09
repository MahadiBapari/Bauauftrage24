import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Added for Future.wait

import '../all_orders_page/single_order_page_screen.dart'; // Ensure this is correctly imported
import '../my_membership_page/membership_form_page_screen.dart'; // Import for the form page

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  String displayName = "User";
  bool isLoadingUser = true; // Still needed for user name specifically
  bool isLoadingPromos = true;

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _newArrivalsOrders = [];
  bool isLoadingCategories = true;
  bool isLoadingNewArrivals = true;

  List<Map<String, dynamic>> promoOrders = [];

  String? _authToken;

  static const String apiKey = '1234567890abcdef'; // Your API Key

  bool _isLoadingMembership = true;
  bool _isActiveMembership = false;
  String _membershipStatusMessage = '';
  final String _membershipEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/user-membership';

  List<Partner> _partners = [];
  bool _isLoadingPartners = true;
  final String _partnersEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/partners';

  // Add cache expiration constants
  static const Duration _cacheExpiration = Duration(hours: 1);
  static const String _lastRefreshKey = 'last_refresh_timestamp';
  
  // Add refresh timer
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Set up periodic refresh
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _refreshDataInBackground();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    promoOrders.clear();
    super.dispose();
  }

  // Add method to check if cache is expired
  Future<bool> _isCacheExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefresh = prefs.getInt(_lastRefreshKey);
    if (lastRefresh == null) return true;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - lastRefresh > _cacheExpiration.inMilliseconds;
  }

  // Add method to update last refresh timestamp
  Future<void> _updateLastRefreshTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRefreshKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Add background refresh method
  Future<void> _refreshDataInBackground() async {
    if (!mounted) return;
    
    try {
      await Future.wait([
        _fetchUser(),
        _fetchPromoOrders(),
        _fetchCategories(),
        _fetchNewArrivalsOrders(categoryId: _selectedCategoryId),
        _fetchMembershipStatus(),
        _fetchPartners(),
      ]);
      await _updateLastRefreshTimestamp();
    } catch (e) {
      debugPrint('Background refresh failed: $e');
    }
  }

  // --- Helper to save data to SharedPreferences ---
  Future<void> _saveDataToCache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data is String) {
      prefs.setString(key, data);
    } else if (data is bool) {
      prefs.setBool(key, data);
    } else if (data is int) {
      prefs.setInt(key, data);
    } else if (data is double) {
      prefs.setDouble(key, data);
    } else if (data is List<String>) {
      prefs.setStringList(key, data);
    } else if (data is List) { // Handle List<Map<String, dynamic>> by encoding
      prefs.setString(key, json.encode(data));
    } else if (data is Map) { // Handle Map<String, dynamic> by encoding
       prefs.setString(key, json.encode(data));
    } else {
      debugPrint('Warning: Attempting to save unsupported type for key $key: ${data.runtimeType}');
    }
    await _updateLastRefreshTimestamp();
    debugPrint('Data cached for key: $key');
  }

  // --- Helper to load data from SharedPreferences ---
  Future<dynamic> _loadDataFromCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.get(key);
    debugPrint('Loading data for key: $key, raw type: ${cachedData.runtimeType}');
    if (cachedData != null) {
      if (cachedData is String) {
        try {
          return json.decode(cachedData);
        } catch (e) {
          return cachedData;
        }
      }
      return cachedData;
    }
    return null;
  }

  // This method now focuses on loading cache first, then initiating network fetches.
  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _authToken = prefs.getString('auth_token');
      });
    }

    // Check if cache is expired
    final isExpired = await _isCacheExpired();

    // --- Phase 1: Load from Cache (Synchronously for immediate display) ---
    final cachedUser = await _loadDataFromCache('cached_user_data');
    final cachedPromos = await _loadDataFromCache('cached_promo_orders');
    final cachedCategories = await _loadDataFromCache('cached_categories');
    final cachedNewArrivals = await _loadDataFromCache('cached_new_arrivals');
    final cachedMembershipActive = await _loadDataFromCache('cached_membership_active');
    final cachedMembershipMessage = await _loadDataFromCache('cached_membership_message');
    final cachedPartners = await _loadDataFromCache('cached_partners');

    if (mounted) {
      setState(() {
        // User Name
        if (cachedUser is String) {
          displayName = cachedUser;
          isLoadingUser = false;
        } else {
          isLoadingUser = true; // Still loading if not in cache
        }
        // Promo Orders
        if (cachedPromos is List) {
          promoOrders = List<Map<String, dynamic>>.from(cachedPromos);
          isLoadingPromos = false;
        } else {
          isLoadingPromos = true;
        }
        // Categories
        if (cachedCategories is List) {
          _categories = List<Map<String, dynamic>>.from(cachedCategories);
          isLoadingCategories = false;
        } else {
          isLoadingCategories = true;
        }
        // New Arrivals
        if (cachedNewArrivals is List) {
          _newArrivalsOrders = List<Map<String, dynamic>>.from(cachedNewArrivals);
          isLoadingNewArrivals = false;
        } else {
          isLoadingNewArrivals = true;
        }
        // Membership Status
        if (cachedMembershipActive is bool) {
          _isActiveMembership = cachedMembershipActive;
          _isLoadingMembership = false;
        } else {
          _isLoadingMembership = true;
        }
        if (cachedMembershipMessage is String) {
          _membershipStatusMessage = cachedMembershipMessage;
        }
        // Partners
        if (cachedPartners is List) {
          _partners = cachedPartners.map((item) => Partner.fromJson(item as Map<String, dynamic>)).toList();
          _isLoadingPartners = false;
        } else {
          _isLoadingPartners = true;
        }
      });
    }

    // --- Phase 2: Fetch Fresh Data if cache is expired or empty ---
    if (isExpired || cachedUser == null || cachedPromos == null || cachedCategories == null) {
      _refreshDataInBackground();
    }
  }

  Future<void> _fetchUser() async {
    if (!mounted) return;
    setState(() => isLoadingUser = true); // Set loading for this specific section

    final prefs = await SharedPreferences.getInstance();
    final userIdString = prefs.getString('user_id');

    if (userIdString == null) {
      if (mounted) setState(() => isLoadingUser = false);
      return;
    }

    final int? userId = int.tryParse(userIdString);
    if (userId == null) {
      if (mounted) setState(() => isLoadingUser = false);
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

        final newDisplayName = '${firstName.trim()} ${lastName.trim()}'.trim().isEmpty
            ? 'User'
            : '${firstName.trim()} ${lastName.trim()}';

        if (mounted) {
          setState(() {
            displayName = newDisplayName;
          });
        }
        await _saveDataToCache('cached_user_data', newDisplayName);
      } else {
        debugPrint('Failed to load user data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    } finally {
      if (mounted) setState(() => isLoadingUser = false);
    }
  }

  Future<void> _fetchMembershipStatus() async {
    if (!mounted) return;
    setState(() => _isLoadingMembership = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (authToken == null) {
        if (mounted) {
          setState(() {
            _isActiveMembership = false;
            _membershipStatusMessage = 'Please log in to check your membership status.';
          });
        }
        await _saveDataToCache('cached_membership_active', false);
        await _saveDataToCache('cached_membership_message', 'Please log in to check your membership status.');
        return;
      }

      final response = await http.get(
        Uri.parse(_membershipEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
          'Authorization': 'Bearer $authToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final bool active = data['success'] == true && data['active'] == true;
        final String message = active ? '' : 'You do not have an active membership.';

        if (mounted) {
          setState(() {
            _isActiveMembership = active;
            _membershipStatusMessage = message;
          });
        }
        await _saveDataToCache('cached_membership_active', active);
        await _saveDataToCache('cached_membership_message', message);
      } else {
        debugPrint('Failed to load membership status: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _isActiveMembership = false;
            _membershipStatusMessage = 'Error checking membership status. Please try again.';
          });
        }
        await _saveDataToCache('cached_membership_active', false);
        await _saveDataToCache('cached_membership_message', 'Error checking membership status. Please try again.');
      }
    } catch (e) {
      debugPrint('Error fetching membership status: $e');
      if (mounted) {
        setState(() {
          _isActiveMembership = false;
          _membershipStatusMessage = 'Could not connect to membership service. Check your internet.';
        });
      }
      await _saveDataToCache('cached_membership_active', false);
      await _saveDataToCache('cached_membership_message', 'Could not connect to membership service. Check your internet.');
    } finally {
      if (mounted) setState(() => _isLoadingMembership = false);
    }
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;
    setState(() => isLoadingCategories = true);

    final categoriesEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories';
    List<Map<String, dynamic>> fetchedCategories = [
      {'id': null, 'name': 'All Categories'}
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
        if (mounted) {
          setState(() {
            _categories = fetchedCategories;
          });
        }
        await _saveDataToCache('cached_categories', fetchedCategories);
      } else {
        debugPrint('Failed to load categories: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    } finally {
      if (mounted) setState(() => isLoadingCategories = false);
    }
  }

  Future<void> _fetchNewArrivalsOrders({String? categoryId}) async {
    if (!mounted) return;
    setState(() => isLoadingNewArrivals = true);

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

        for (var order in ordersData) {
          String title = order['title']?['rendered'] ?? 'No Title';
          String categoryName = order['acf']?['category'] ?? 'No Category';
          String imageUrl = '';

          if (order['meta'] != null && order['meta']['order_gallery'] is List && order['meta']['order_gallery'].isNotEmpty) {
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

          fetchedOrders.add({
            "displayTitle": title,
            "displayCategory": categoryName,
            "displayImageUrl": imageUrl,
            "fullOrder": order,
          });
        }
        if (mounted) {
          setState(() {
            _newArrivalsOrders = fetchedOrders;
          });
        }
        await _saveDataToCache('cached_new_arrivals', fetchedOrders);
      } else {
        debugPrint('Failed to load new arrivals: ${ordersResponse.statusCode} - ${ordersResponse.body}');
      }
    } catch (e) {
      debugPrint('Error fetching new arrivals orders: $e');
    } finally {
      if (mounted) setState(() => isLoadingNewArrivals = false);
    }
  }

  Future<void> _fetchPromoOrders() async {
    if (!mounted) return;
    setState(() => isLoadingPromos = true);

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

        for (var order in ordersData) {
          String title = order['title']?['rendered'] ?? 'No Title';
          String categoryName = order['acf']?['category'] ?? 'No Category';
          String imageUrl = '';

          if (order['meta'] != null && order['meta']['order_gallery'] is List && order['meta']['order_gallery'].isNotEmpty) {
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

          fetchedPromoOrders.add({
            "displayTitle": title,
            "displayCategory": categoryName,
            "displayImageUrl": imageUrl,
            "fullOrder": order,
          });
        }
        if (mounted) {
          setState(() {
            promoOrders = fetchedPromoOrders;
          });
        }
        await _saveDataToCache('cached_promo_orders', fetchedPromoOrders);
      } else {
        debugPrint('Failed to load orders: ${ordersResponse.statusCode} - ${ordersResponse.body}');
      }
    } catch (e) {
      debugPrint('Error fetching promo orders: $e');
    } finally {
      if (mounted) setState(() => isLoadingPromos = false);
    }
  }

  Future<void> _fetchPartners() async {
    if (!mounted) return;
    setState(() => _isLoadingPartners = true);

    const String mediaEndpointBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';
    List<Partner> fetchedPartners = [];

    try {
      final response = await http.get(Uri.parse(_partnersEndpoint));

      if (!mounted) return;

      if (response.statusCode == 200) {
        List<dynamic> partnersData = json.decode(response.body);

        for (var item in partnersData) {
          final title = item['title']?['rendered'] ?? 'No Title';
          final address = (item['meta']?['adresse'] is List && item['meta']['adresse'].isNotEmpty)
              ? item['meta']['adresse'][0]
              : 'No Address';

          int? logoId;
          final dynamic rawLogoData = item['meta']?['logo'];

          if (rawLogoData != null) {
            if (rawLogoData is int) {
              logoId = rawLogoData;
            } else if (rawLogoData is String) {
              logoId = int.tryParse(rawLogoData);
            } else if (rawLogoData is List && rawLogoData.isNotEmpty) {
              final dynamic firstElement = rawLogoData[0];
              if (firstElement is int) {
                logoId = firstElement;
              } else if (firstElement is String) {
                logoId = int.tryParse(firstElement);
              } else if (firstElement is Map && firstElement.containsKey('id')) {
                logoId = firstElement['id'] as int?;
              }
            } else if (rawLogoData is Map && rawLogoData.containsKey('id')) {
              logoId = rawLogoData['id'] as int?;
            }
          }

          if (logoId == null && item['featured_media'] != null && item['featured_media'] is int) {
            logoId = item['featured_media'] as int?;
          }

          String imageUrl = '';
          if (logoId != null && logoId != 0) {
            final mediaUrl = Uri.parse('$mediaEndpointBase$logoId');
            final mediaResponse = await http.get(mediaUrl);
            if (!mounted) return;
            if (mediaResponse.statusCode == 200) {
              try {
                final mediaData = json.decode(mediaResponse.body);
                imageUrl = mediaData['source_url'] ?? '';
              } catch (e) {
                debugPrint('Error decoding media data for partner logo ID $logoId: $e. Response body: ${mediaResponse.body}');
              }
            } else {
              debugPrint('Failed to load media for partner logo ID $logoId: Status ${mediaResponse.statusCode} - ${mediaResponse.body}');
            }
          }
          
          fetchedPartners.add(Partner(
            title: title,
            address: address,
            logoId: logoId,
            logoUrl: imageUrl,
          ));
        }
        if (mounted) {
          setState(() {
            _partners = fetchedPartners;
          });
        }
        await _saveDataToCache('cached_partners', fetchedPartners.map((p) => p.toJson()).toList());
      } else {
        debugPrint('Failed to load partners: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching partners: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPartners = false);
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
              isLoadingUser
                  ? const CircularProgressIndicator.adaptive() // Show loading only for username
                  : Text(
                      displayName,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
              const SizedBox(height: 24),

              // --- Conditional "Get Membership" Card ---
              _isLoadingMembership
                  ? const Center(child: CircularProgressIndicator.adaptive()) // Show loading for membership card
                  : !_isActiveMembership
                      ? _buildGetMembershipCard(context)
                      : const SizedBox.shrink(),

              const SizedBox(height: 24),




              Text("Promotions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              isLoadingPromos
                  ? const Center(child: CircularProgressIndicator.adaptive()) // Show loading for promos
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
                              return _buildOrderCard(
                                  promo["displayTitle"]!, promo["displayCategory"]!, promo["displayImageUrl"]);
                            },
                          ),
                        ),
              const SizedBox(height: 24),

              _buildCategorySection(),
              const SizedBox(height: 20),

              _buildNewArrivals(),
              const SizedBox(height: 24),

                            // --- Coupon Card Widget directly in Home Page ---
              _buildCouponCard(
                imageUrl: 'assets/images/kpsa_logo.png',
                discountText: '20% discount',
                descriptionText: '20% discount on workwear for construction contracts24 craftsmen! Order your work clothes directly at www.kpsa.ch. Log into our website account or register to receive your exclusive discount code.\n\nAfter logging in you will find the code in your profile.',
                onShowDiscountCode: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discount code will be shown here!')),
                  );
                },
              ),
              const SizedBox(height: 24),

              _buildPartnersSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        isLoadingCategories
            ? const Center(child: CircularProgressIndicator.adaptive())
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

  Widget _buildNewArrivals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("New Arrivals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        isLoadingNewArrivals
            ? const Center(child: CircularProgressIndicator.adaptive())
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
                        final String title = orderData["displayTitle"]!;
                        final String category = orderData["displayCategory"]!;
                        final String? imageUrl = orderData["displayImageUrl"];
                        final Map<String, dynamic> fullOrder = orderData["fullOrder"]!;

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SingleOrderPageScreen(
                                  order: fullOrder,
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

  Widget _buildGetMembershipCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 85, 21, 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 85, 21, 1),
            Color.fromARGB(255, 121, 26, 3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium,
            color: Colors.amberAccent,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Unlock Premium Features!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _membershipStatusMessage.isEmpty
                ? 'Your current membership is not active. Get a membership to access exclusive benefits and advanced tools.'
                : _membershipStatusMessage,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MembershipFormPageScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color.fromARGB(255, 85, 21, 1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
              ),
              child: const Text(
                'Get Membership Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard({
    required String imageUrl,
    required String discountText,
    required String descriptionText,
    required VoidCallback onShowDiscountCode,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFFF5F5F5),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discountText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    descriptionText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onShowDiscountCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 185, 33, 33),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                      'Show discount code',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Our Partners", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _isLoadingPartners
            ? const Center(child: CircularProgressIndicator.adaptive()) // Show loading for partners
            : _partners.isEmpty
                ? const Center(child: Text("No partners available at the moment."))
                : SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _partners.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final partner = _partners[index];
                        return _buildPartnerCard(partner);
                      },
                    ),
                  ),
      ],
    );
  }

  Widget _buildPartnerCard(Partner partner) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapped on ${partner.title}')),
        );
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (partner.logoUrl != null && partner.logoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  partner.logoUrl!,
                  height: 80,
                  width: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading partner image ${partner.logoUrl}: $error');
                    return const Icon(
                      Icons.business,
                      size: 60,
                      color: Colors.grey,
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.expectedTotalBytes! > 0
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null
                            : null,
                        strokeWidth: 2,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),
              )
            else
              const Icon(Icons.business, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              partner.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              partner.address,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Partner {
  final String title;
  final String address;
  final int? logoId;
  final String? logoUrl;

  Partner({
    required this.title,
    required this.address,
    this.logoId,
    this.logoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'address': address,
      'logoId': logoId,
      'logoUrl': logoUrl,
    };
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      title: json['title'] as String,
      address: json['address'] as String,
      logoId: json['logoId'] as int?,
      logoUrl: json['logoUrl'] as String?,
    );
  }
}