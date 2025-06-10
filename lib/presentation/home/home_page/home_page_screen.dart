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
import 'package:shimmer/shimmer.dart';

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
    _clearCacheAndLoad();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    promoOrders.clear();
    super.dispose();
  }

  Future<void> _clearCacheAndLoad() async {
    // Clear the cache first
    await _cacheManager.clearCache('partners');
    debugPrint('Cleared partners cache'); // Debug log
    
    // Then load data
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Load cached data first
      final cachedPartners = await _cacheManager.loadFromCache('partners');
      debugPrint('Cached partners: $cachedPartners'); // Debug log
      
      if (cachedPartners != null && cachedPartners is List && cachedPartners.isNotEmpty) {
        final partners = cachedPartners.map((p) => Partner.fromJson(p)).toList();
        debugPrint('Loaded ${partners.length} partners from cache'); // Debug log
        
        if (mounted) {
          setState(() {
            _partners = partners;
            _isLoadingPartners = false;
          });
        }
      }

      // Load all data in parallel
      await Future.wait([
        _fetchUser(),
        _fetchPromoOrders(),
        _fetchCategories(),
        _fetchNewArrivalsOrders(categoryId: _selectedCategoryId),
        _fetchMembershipStatus(),
        _loadPartners(),
      ]);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserData() async {
    final cachedData = await _cacheManager.loadFromCache('user_data');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          displayName = cachedData as String;
          isLoadingUser = false;
        });
      }
    }
    await _fetchUser();
  }

  Future<void> _loadPromoOrders() async {
    final cachedData = await _cacheManager.loadFromCache('promo_orders');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          promoOrders = List<Map<String, dynamic>>.from(cachedData as List);
          isLoadingPromos = false;
        });
      }
    }
    await _fetchPromoOrders();
  }

  Future<void> _loadCategories() async {
    final cachedData = await _cacheManager.loadFromCache('categories');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(cachedData as List);
          isLoadingCategories = false;
        });
      }
    }
    await _fetchCategories();
  }

  Future<void> _loadNewArrivals() async {
    final cachedData = await _cacheManager.loadFromCache('new_arrivals');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _newArrivalsOrders = List<Map<String, dynamic>>.from(cachedData as List);
          isLoadingNewArrivals = false;
        });
      }
    }
    await _fetchNewArrivalsOrders(categoryId: _selectedCategoryId);
  }

  Future<void> _loadMembershipStatus() async {
    final cachedData = await _cacheManager.loadFromCache('membership_status');
    if (cachedData != null) {
      if (mounted) {
        final membershipData = cachedData as Map<String, dynamic>;
        setState(() {
          _isActiveMembership = membershipData['active'] as bool;
          _membershipStatusMessage = membershipData['message'] as String;
          _isLoadingMembership = false;
        });
      }
    }
    await _fetchMembershipStatus();
  }

  Future<void> _loadPartners() async {
    if (!mounted) return;
    
    try {
      // Check if cache is expired
      final isExpired = await _cacheManager.isCacheExpired('partners');
      debugPrint('Partners cache expired: $isExpired'); // Debug log
      
      if (!isExpired) {
        // Try to load from cache first
        final cachedPartners = await _cacheManager.loadFromCache('partners');
        debugPrint('Loading partners from cache: $cachedPartners'); // Debug log
        
        if (cachedPartners != null && cachedPartners is List && cachedPartners.isNotEmpty) {
          final partners = cachedPartners.map((p) => Partner.fromJson(p)).toList();
          debugPrint('Loaded ${partners.length} partners from cache'); // Debug log
          
          if (mounted) {
            setState(() {
              _partners = partners;
              _isLoadingPartners = false;
            });
          }
          // Fetch fresh data in background
          _fetchPartners();
          return;
        }
      }

      // If no cache or expired, fetch fresh data
      await _fetchPartners();
    } catch (e) {
      debugPrint('Error loading partners: $e');
      if (mounted) {
        setState(() => _isLoadingPartners = false);
      }
    }
  }

  Future<void> _fetchPartners() async {
    if (!mounted) return;
    setState(() => _isLoadingPartners = true);

    try {
      final response = await http.get(Uri.parse(_partnersEndpoint));

      if (!mounted) return;

      if (response.statusCode == 200) {
        List<dynamic> partnersData = json.decode(response.body);
        List<Partner> fetchedPartners = [];

        // First, create partners with basic data
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
          
          fetchedPartners.add(Partner(
            title: title,
            address: address,
            logoId: logoId,
          ));
        }

        debugPrint('Fetched ${fetchedPartners.length} partners from API'); // Debug log

        // Update UI with basic partner data first
        if (mounted) {
          setState(() {
            _partners = fetchedPartners;
            _isLoadingPartners = false;
          });
        }

        // Save basic partner data to cache
        final partnersJson = fetchedPartners.map((p) => p.toJson()).toList();
        debugPrint('Saving partners to cache: $partnersJson'); // Debug log
        await _cacheManager.saveToCache('partners', partnersJson);

        // Then fetch images in the background
        _fetchPartnerImages(fetchedPartners);
      } else {
        debugPrint('Failed to load partners: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() => _isLoadingPartners = false);
        }
      }
    } catch (e) {
      debugPrint('Error fetching partners: $e');
      if (mounted) {
        setState(() => _isLoadingPartners = false);
      }
    }
  }

  Future<void> _fetchPartnerImages(List<Partner> partners) async {
    const String mediaEndpointBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';
    List<Partner> updatedPartners = List.from(partners);

    for (int i = 0; i < partners.length; i++) {
      final partner = partners[i];
      if (partner.logoId != null && partner.logoId != 0) {
        try {
          final mediaUrl = Uri.parse('$mediaEndpointBase${partner.logoId}');
          final mediaResponse = await http.get(mediaUrl);
          
          if (!mounted) return;

          if (mediaResponse.statusCode == 200) {
            try {
              final mediaData = json.decode(mediaResponse.body);
              final imageUrl = mediaData['source_url'] ?? '';
              
              // Update partner with image URL
              updatedPartners[i] = Partner(
                title: partner.title,
                address: partner.address,
                logoId: partner.logoId,
                logoUrl: imageUrl,
              );

              // Update UI with new partner data
              if (mounted) {
                setState(() {
                  _partners = List.from(updatedPartners);
                });
              }
            } catch (e) {
              debugPrint('Error decoding media data for partner logo ID ${partner.logoId}: $e');
            }
          }
        } catch (e) {
          debugPrint('Error fetching image for partner ${partner.title}: $e');
        }
      }
    }

    // Save complete partner data to cache
    if (mounted) {
      await _cacheManager.saveToCache('partners', updatedPartners.map((p) => p.toJson()).toList());
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

  Future<void> _refreshDataInBackground() async {
    if (!mounted) return;
    
    try {
      await Future.wait([
        _fetchUser(),
        _fetchPromoOrders(),
        _fetchCategories(),
        _fetchNewArrivalsOrders(categoryId: _selectedCategoryId),
        _fetchMembershipStatus(),
        _loadPartners(),
      ]);
    } catch (e) {
      debugPrint('Background refresh failed: $e');
    }
  }

  Future<void> _onRefresh() async {
    if (!mounted) return;
    
    try {
      await Future.wait([
        _fetchUser(),
        _fetchPromoOrders(),
        _fetchCategories(),
        _fetchNewArrivalsOrders(categoryId: _selectedCategoryId),
        _fetchMembershipStatus(),
        _loadPartners(),
      ]);
    } catch (e) {
      debugPrint('Refresh failed: $e');
    }
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
                  height: MediaQuery.of(context).size.height - 200,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: ListView(
                      children: [
                        // Welcome Section with Shimmer
                        isLoadingUser
                            ? Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 200,
                                      height: 26,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayName,
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                        const SizedBox(height: 24),

                        // Membership Card with Shimmer
                        _isLoadingMembership
                            ? Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              )
                            : !_isActiveMembership
                                ? _buildGetMembershipCard(context)
                                : const SizedBox.shrink(),

                        const SizedBox(height: 24),

                        // Promotions Section with Shimmer
                        isLoadingPromos
                            ? Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: SizedBox(
                                  height: 160,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 3,
                                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                                    itemBuilder: (_, __) => Container(
                                      width: 280,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
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

                        // New Arrivals Section with Shimmer
                        isLoadingNewArrivals
                            ? Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: SizedBox(
                                  height: 220,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 3,
                                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                                    itemBuilder: (_, __) => Container(
                                      width: 160,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
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
                                        return _buildNewArrivalCard(orderData);
                                      },
                                    ),
                                  ),
                        const SizedBox(height: 24),

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

                        // Partners Section with Shimmer
                        _isLoadingPartners
                            ? Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: SizedBox(
                                  height: 180,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 4,
                                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                                    itemBuilder: (_, __) => Container(
                                      width: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : _buildPartnersSection(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildNewArrivalCard(Map<String, dynamic> orderData) {
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