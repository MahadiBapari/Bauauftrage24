import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Added for Future.wait

import '../../../utils/cache_manager.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../../widgets/membership_required_dialog.dart';
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

  static const String apiKey = '1234567890abcdef'; 

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

  final CacheManager _cacheManager = CacheManager();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _authToken = prefs.getString('auth_token');
        });
      }

      // Load all data from cache first
      final cachedData = await Future.wait([
        _cacheManager.loadFromCache('user_data'),
        _cacheManager.loadFromCache('promo_orders'),
        _cacheManager.loadFromCache('categories'),
        _cacheManager.loadFromCache('new_arrivals'),
        _cacheManager.loadFromCache('membership_status'),
        _cacheManager.loadFromCache('partners'),
      ]);

      if (mounted) {
        setState(() {
          // Update state with cached data
          if (cachedData[0] != null) {
            displayName = cachedData[0] as String;
            isLoadingUser = false;
          }
          if (cachedData[1] != null) {
            promoOrders = List<Map<String, dynamic>>.from(cachedData[1] as List);
            isLoadingPromos = false;
          }
          if (cachedData[2] != null) {
            _categories = List<Map<String, dynamic>>.from(cachedData[2] as List);
            isLoadingCategories = false;
          }
          if (cachedData[3] != null) {
            _newArrivalsOrders = List<Map<String, dynamic>>.from(cachedData[3] as List);
            isLoadingNewArrivals = false;
          }
          if (cachedData[4] != null) {
            final membershipData = cachedData[4] as Map<String, dynamic>;
            _isActiveMembership = membershipData['active'] as bool;
            _membershipStatusMessage = membershipData['message'] as String;
            _isLoadingMembership = false;
          }
          if (cachedData[5] != null) {
            _partners = (cachedData[5] as List)
                .map((item) => Partner.fromJson(item as Map<String, dynamic>))
                .toList();
            _isLoadingPartners = false;
          }
        });
      }

      // Check which data needs refreshing
      final needsRefresh = await Future.wait([
        _cacheManager.isCacheExpired('user_data'),
        _cacheManager.isCacheExpired('promo_orders'),
        _cacheManager.isCacheExpired('categories'),
        _cacheManager.isCacheExpired('new_arrivals'),
        _cacheManager.isCacheExpired('membership_status'),
        _cacheManager.isCacheExpired('partners'),
      ]);

      // Refresh only expired data
      if (needsRefresh.any((needs) => needs)) {
        await _refreshDataInBackground();
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
    } catch (e) {
      debugPrint('Background refresh failed: $e');
    }
  }

  Future<void> _fetchUser() async {
    if (!mounted) return;
    setState(() => isLoadingUser = true);

    try {
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
        await _cacheManager.saveToCache('user_data', newDisplayName);
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
        await _cacheManager.saveToCache('membership_status', {'active': false, 'message': 'Please log in to check your membership status.'});
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
        await _cacheManager.saveToCache('membership_status', {'active': active, 'message': message});
      } else {
        debugPrint('Failed to load membership status: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _isActiveMembership = false;
            _membershipStatusMessage = 'Error checking membership status. Please try again.';
          });
        }
        await _cacheManager.saveToCache('membership_status', {'active': false, 'message': 'Error checking membership status. Please try again.'});
      }
    } catch (e) {
      debugPrint('Error fetching membership status: $e');
      if (mounted) {
        setState(() {
          _isActiveMembership = false;
          _membershipStatusMessage = 'Could not connect to membership service. Check your internet.';
        });
      }
      await _cacheManager.saveToCache('membership_status', {'active': false, 'message': 'Could not connect to membership service. Check your internet.'});
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
        await _cacheManager.saveToCache('categories', fetchedCategories);
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
        await _cacheManager.saveToCache('new_arrivals', fetchedOrders);
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
        await _cacheManager.saveToCache('promo_orders', fetchedPromoOrders);
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
        await _cacheManager.saveToCache('partners', fetchedPartners.map((p) => p.toJson()).toList());
      } else {
        debugPrint('Failed to load partners: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching partners: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPartners = false);
    }
  }

  // Add refresh method
  Future<void> _onRefresh() async {
    await Future.wait([
      _fetchUser(),
      _fetchPromoOrders(),
      _fetchCategories(),
      _fetchNewArrivalsOrders(categoryId: _selectedCategoryId),
      _fetchMembershipStatus(),
      _fetchPartners(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const CustomLoadingIndicator(
              message: 'Loading data...',
              itemCount: 5,
              itemHeight: 120,
              itemWidth: double.infinity,
              isScrollable: true,
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200, // Account for app bar and bottom navigation
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
                            ? const CustomLoadingIndicator(
                                size: 30.0,
                                message: 'Loading user data...',
                                itemCount: 1,
                                itemHeight: 40,
                                itemWidth: 200,
                              )
                            : Text(
                                displayName,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                              ),
                        const SizedBox(height: 24),

                        // --- Conditional "Get Membership" Card ---
                        _isLoadingMembership
                            ? const CustomLoadingIndicator(
                                size: 30.0,
                                message: 'Loading membership status...',
                                itemCount: 1,
                                itemHeight: 120,
                                itemWidth: double.infinity,
                              )
                            : !_isActiveMembership
                                ? _buildGetMembershipCard(context)
                                : const SizedBox.shrink(),

                        const SizedBox(height: 24),

                        // Text("Promotions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        // const SizedBox(height: 12),
                        isLoadingPromos
                            ? const CustomLoadingIndicator(
                                size: 30.0,
                                message: 'Loading promotions...',
                                isHorizontal: true,
                                itemCount: 3,
                                itemHeight: 160,
                                itemWidth: 280,
                              )
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

                        isLoadingNewArrivals
                            ? const CustomLoadingIndicator(
                                size: 30.0,
                                message: 'Loading new arrivals...',
                                isHorizontal: true,
                                itemCount: 3,
                                itemHeight: 220,
                                itemWidth: 160,
                              )
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
                                            if (_isActiveMembership) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => SingleOrderPageScreen(
                                                    order: fullOrder,
                                                  ),
                                                ),
                                              );
                                            } else {
                                              showDialog(
                                                context: context,
                                                builder: (context) => MembershipRequiredDialog(
                                                  context: context,
                                                  message: 'A membership is required to view order details. Get a membership to access all order information.',
                                                ),
                                              );
                                            }
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
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Newest Orders", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        isLoadingCategories
            ? const CustomLoadingIndicator(
                size: 30.0,
                message: 'Loading categories...',
              )
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
            Row(
            children: [
              const Icon(
              Icons.workspace_premium,
              color: Colors.amberAccent,
              size: 42,
              ),
              const SizedBox(width: 16),
              const Text(
              'Unlock Premium Features!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              ),
            ],
            ),
            const SizedBox(height: 16),
          const SizedBox(height: 8),
            Center(
            child: Text(
              _membershipStatusMessage.isEmpty
                ? 'Your current membership is not active. Get a membership to access exclusive benefits and advanced tools.'
                : _membershipStatusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              ),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
              ),
              child: const Text(
                'Get Membership Now',
                style: TextStyle(
                  fontSize: 14,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              height: 80, // Add fixed height
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
            ? const CustomLoadingIndicator(
                size: 30.0,
                message: 'Loading partners...',
                isHorizontal: true,
                itemCount: 4,
                itemHeight: 180,
                itemWidth: 150,
              )
            : _partners.isEmpty
                ? const Text("No partners available at the moment.")
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