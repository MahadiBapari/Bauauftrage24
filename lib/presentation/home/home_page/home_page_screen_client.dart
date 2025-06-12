import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bauauftrage/utils/cache_manager.dart';
import '../my_order_page/single_myorders_page_screen.dart';
import 'package:bauauftrage/widgets/custom_loading_indicator.dart';
import 'package:extended_image/extended_image.dart';
import 'package:bauauftrage/core/network/safe_http.dart';

class HomePageScreenClient extends StatefulWidget {
  const HomePageScreenClient({Key? key}) : super(key: key);

  @override
  State<HomePageScreenClient> createState() => _HomePageScreenClientState();
}

class _HomePageScreenClientState extends State<HomePageScreenClient> {
  final CacheManager _cacheManager = CacheManager();
  bool _isLoading = true;
  bool _isLoadingCategories = true;
  bool _isLoadingPartners = true;
  bool _isLoadingOrders = true;
  
  List<Category> _categories = [];
  List<Partner> _partners = [];
  List<Order> _orders = [];

  // Add user data state variables
  String displayName = "User";
  bool isLoadingUser = true;
  int? currentUserId; // Store the current user ID

  static const String apiKey = '1234567890abcdef';

  @override
  void initState() {
    super.initState();
    _loadFromCacheThenBackground();
  }

  Future<void> _loadFromCacheThenBackground() async {
    // Load all sections from cache first (no loading spinner)
    await Future.wait([
      _loadUserFromCache(),
      _loadCategoriesFromCache(),
      _loadPartnersFromCache(),
      _loadOrdersFromCache(),
    ]);
    // Then fetch fresh data in background (will update UI if new data)
    _refreshAllDataInBackground();
  }

  Future<void> _loadUserFromCache() async {
    final cachedData = await _cacheManager.loadFromCache('user_data');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          displayName = cachedData as String;
          isLoadingUser = false;
        });
      }
    }
  }

  Future<void> _loadCategoriesFromCache() async {
    final cachedCategories = await _cacheManager.loadFromCache('categories');
    if (cachedCategories != null && cachedCategories is List && cachedCategories.isNotEmpty) {
      final filtered = cachedCategories.where((c) {
        final id = c['id'];
        final valid = id != null && (id is int || int.tryParse('$id') != null);
        if (!valid) debugPrint('Skipping cached category with invalid id: $id');
        return valid;
      }).toList();
      final categories = filtered.map((c) => Category.fromJson(c)).toList();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadPartnersFromCache() async {
    final cachedPartners = await _cacheManager.loadFromCache('partners');
    if (cachedPartners != null && cachedPartners is List && cachedPartners.isNotEmpty) {
      final partners = cachedPartners.map((p) => Partner.fromJson(p)).toList();
      if (mounted) {
        setState(() {
          _partners = partners;
          _isLoadingPartners = false;
        });
      }
    }
  }

  Future<void> _loadOrdersFromCache() async {
    final cachedOrders = await _cacheManager.loadFromCache('orders');
    if (cachedOrders != null && cachedOrders is List && cachedOrders.isNotEmpty) {
      final orders = cachedOrders.map((o) => Order.fromJson(o)).where((order) {
        if (order.fullOrder != null && currentUserId != null) {
          return order.fullOrder!['author'] == currentUserId;
        }
        return false;
      }).toList();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoadingOrders = false;
        });
      }
    }
  }

  Future<void> _refreshAllDataInBackground() async {
    await _fetchUser();
    await Future.wait([
      _loadCategories(),
      _loadPartners(),
      _loadOrders(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No auto-refresh on navigation; rely on manual refresh only
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _isLoading = true;
      isLoadingUser = true;
      _isLoadingCategories = true;
      _isLoadingPartners = true;
      _isLoadingOrders = true;
    });
    await _fetchUser();
    await Future.wait([
      _loadCategories(),
      _loadPartners(),
      _loadOrders(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _onRefresh() async {
    // Clear category cache before refreshing all data
    await _cacheManager.saveToCache('categories', []);
    await _refreshAllData();
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

      currentUserId = userId; // Store the user ID
      final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/$userId');
      final response = await SafeHttp.safeGet(context, url, headers: {'X-API-Key': apiKey});

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

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoadingCategories = true);

    try {
      // Try to load from cache first
      final cachedCategories = await _cacheManager.loadFromCache('categories');
      debugPrint('Loaded cachedCategories: ' + cachedCategories.toString());
      if (cachedCategories != null && cachedCategories is List && cachedCategories.isNotEmpty) {
        final filtered = cachedCategories.where((c) {
          final id = c['id'];
          final valid = id != null && (id is int || int.tryParse('$id') != null);
          if (!valid) debugPrint('Skipping cached category with invalid id: $id');
          return valid;
        }).toList();
        final categories = filtered.map((c) => Category.fromJson(c)).toList();
        debugPrint('Parsed categories from cache: ' + categories.length.toString());
        if (mounted) {
          setState(() {
            _categories = categories;
            _isLoadingCategories = false;
          });
        }
        return;
      }

      // If no cache, fetch fresh data
      final response = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100'), headers: {'X-API-Key': apiKey});

      debugPrint('Categories API status: ' + response.statusCode.toString());
      debugPrint('Categories API body: ' + response.body.toString());

      if (!mounted) return;

      if (response.statusCode == 200) {
        List<dynamic> categoriesData = json.decode(response.body);
        debugPrint('Parsed categoriesData: ' + categoriesData.length.toString() + ' items');
        List<_CategoryTemp> tempCategories = [];
        Set<int> mediaIds = {};
        for (var item in categoriesData) {
          if (item['id'] == null || (item['id'] is! int && int.tryParse(item['id'].toString()) == null)) {
            debugPrint('Skipping fetched category with invalid id: ${item['id']}');
            continue;
          }
          final id = item['id'] is int ? item['id'] : int.parse(item['id'].toString());
          final name = item['name'] as String;
          int? imageMediaId;
          final catImage = item['meta']?['cat_image'];
          if (catImage != null && catImage is Map && catImage['id'] != null) {
            if (catImage['id'] is int) {
              imageMediaId = catImage['id'];
            } else if (catImage['id'] is String && int.tryParse(catImage['id']) != null) {
              imageMediaId = int.parse(catImage['id']);
            }
            if (imageMediaId != null) mediaIds.add(imageMediaId);
          }
          tempCategories.add(_CategoryTemp(id: id, name: name, imageMediaId: imageMediaId));
        }
        // Fetch all media URLs in parallel
        Map<int, String> mediaUrlMap = {};
        for (var mediaId in mediaIds) {
          try {
            final mediaResponse = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$mediaId'), headers: {'X-API-Key': apiKey});
            if (mediaResponse.statusCode == 200) {
              final mediaData = json.decode(mediaResponse.body);
              if (mediaData['source_url'] != null) {
                mediaUrlMap[mediaId] = mediaData['source_url'];
              }
            } else {
              debugPrint('Failed to fetch media for category image id $mediaId: status ${mediaResponse.statusCode}');
            }
          } catch (e) {
            debugPrint('Error fetching media for category image id $mediaId: $e');
          }
        }
        List<Category> fetchedCategories = tempCategories.map((c) => Category(
          id: c.id,
          name: c.name,
          imageUrl: c.imageMediaId != null ? mediaUrlMap[c.imageMediaId!] : null,
        )).toList();
        debugPrint('Final fetchedCategories count: ' + fetchedCategories.length.toString());
        for (var c in fetchedCategories) {
          debugPrint('Category: id=' + c.id.toString() + ', name=' + c.name + ', imageUrl=' + (c.imageUrl ?? 'null'));
        }
        if (mounted) {
          setState(() {
            _categories = fetchedCategories;
            _isLoadingCategories = false;
          });
        }
        // Save to cache
        await _cacheManager.saveToCache('categories', fetchedCategories.map((c) => c.toJson()).toList());
      } else {
        debugPrint('Failed to load categories: ' + response.statusCode.toString());
        if (mounted) {
          setState(() => _isLoadingCategories = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  Future<void> _loadPartners() async {
    if (!mounted) return;
    setState(() => _isLoadingPartners = true);

    try {
      // Try to load from cache first
      final cachedPartners = await _cacheManager.loadFromCache('partners');
      if (cachedPartners != null && cachedPartners is List && cachedPartners.isNotEmpty) {
        final partners = cachedPartners.map((p) => Partner.fromJson(p)).toList();
        if (mounted) {
          setState(() {
            _partners = partners;
            _isLoadingPartners = false;
          });
        }
        debugPrint('Loaded ${partners.length} partners from cache');
        return;
      }

      // If no cache, fetch fresh data
      final response = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/partners'));

      if (!mounted) return;

      debugPrint('Partners API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> partnersData = json.decode(response.body);
        debugPrint('Partners API returned ${partnersData.length} items');
        
        // Print the first partner's full structure for debugging
        if (partnersData.isNotEmpty) {
          debugPrint('First partner full structure: ${partnersData[0]}');
        }
        
        List<Partner> fetchedPartners = [];

        for (var item in partnersData) {
          final title = item['title']?['rendered'] as String? ?? '';
          debugPrint('\n--- Processing partner: $title ---');
          
          // Check if meta exists
          if (item['meta'] != null) {
            debugPrint('Meta exists for $title');
            final meta = item['meta'];
            
            // Check if logo exists in meta
            if (meta['logo'] != null) {
              debugPrint('Logo field exists in meta for $title');
              debugPrint('Logo field type: ${meta['logo'].runtimeType}');
              debugPrint('Logo field content: ${meta['logo']}');
              
              // Check if it's the expected structure
              if (meta['logo'] is Map) {
                final logoMap = meta['logo'] as Map;
                debugPrint('Logo is a Map with keys: ${logoMap.keys.toList()}');
                
                if (logoMap['url'] != null) {
                  debugPrint('URL found in logo: ${logoMap['url']}');
                } else {
                  debugPrint('No URL field in logo map');
                }
                
                if (logoMap['id'] != null) {
                  debugPrint('ID found in logo: ${logoMap['id']}');
                } else {
                  debugPrint('No ID field in logo map'); 
                }
              } else {
                debugPrint('Logo is not a Map, it is: ${meta['logo']}');
              }
            } else {
              debugPrint('No logo field in meta for $title');
            }
            
            // Check address
            final address = meta['adresse'] as String? ?? '';
            debugPrint('Address for $title: $address');
          } else {
            debugPrint('No meta field for $title');
          }

          final address = item['meta']?['adresse'] as String? ?? '';
          String? logoUrl;

          // Extract logo URL using the exact structure shown
          if (item['meta'] != null && 
              item['meta']['logo'] != null && 
              item['meta']['logo'] is Map &&
              item['meta']['logo']['url'] != null) {
            logoUrl = item['meta']['logo']['url'] as String;
            debugPrint('✓ Successfully extracted logo URL for $title: $logoUrl');
          } else {
            debugPrint('✗ Failed to extract logo URL for $title');
            debugPrint('  Meta exists: ${item['meta'] != null}');
            debugPrint('  Logo exists: ${item['meta']?['logo'] != null}');
            debugPrint('  Logo is Map: ${item['meta']?['logo'] is Map}');
            debugPrint('  URL exists: ${item['meta']?['logo']?['url'] != null}');
          }

          fetchedPartners.add(Partner(
            title: title,
            address: address,
            logoId: item['meta']?['logo']?['id'],
            logoUrl: logoUrl,
          ));
        }

        debugPrint('\n=== SUMMARY ===');
        debugPrint('Created ${fetchedPartners.length} partner objects');
        debugPrint('Partners with logos: ${fetchedPartners.where((p) => p.logoUrl != null && p.logoUrl!.isNotEmpty).length}');
        
        // List all partners and their logo status
        for (var partner in fetchedPartners) {
          debugPrint('${partner.title}: ${partner.logoUrl != null ? "HAS LOGO" : "NO LOGO"}');
          if (partner.logoUrl != null) {
            debugPrint('  URL: ${partner.logoUrl}');
          }
        }

        if (mounted) {
          setState(() {
            _partners = fetchedPartners;
            _isLoadingPartners = false;
          });
        }

        // Save to cache
        await _cacheManager.saveToCache('partners', fetchedPartners.map((p) => p.toJson()).toList());
      } else {
        debugPrint('Failed to load partners: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        if (mounted) {
          setState(() => _isLoadingPartners = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading partners: $e');
      if (mounted) {
        setState(() => _isLoadingPartners = false);
      }
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _isLoadingOrders = true);

    try {
      // Try to load from cache first
      final cachedOrders = await _cacheManager.loadFromCache('orders');
      if (cachedOrders != null && cachedOrders is List && cachedOrders.isNotEmpty) {
        final orders = cachedOrders.map((o) => Order.fromJson(o)).where((order) {
          // Filter by current user
          if (order.fullOrder != null && currentUserId != null) {
            return order.fullOrder!['author'] == currentUserId;
          }
          return false;
        }).toList();
        if (mounted) {
          setState(() {
            _orders = orders;
            _isLoadingOrders = false;
          });
        }
        return;
      }

      // If no cache, fetch fresh data
      final response = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order?_embed'));

      if (!mounted) return;

      if (response.statusCode == 200) {
        List<dynamic> ordersData = json.decode(response.body);
        List<Order> fetchedOrders = [];

        for (var item in ordersData) {
          final title = item['title']?['rendered'] as String? ?? '';
          final description = item['content']?['rendered'] as String? ?? '';
          final status = item['acf']?['status'] as String? ?? '';
          final date = item['date'] as String? ?? '';
          String? imageUrl;

          // Get the first image from the order gallery
          if (item['meta']?['order_gallery'] != null) {
            final gallery = item['meta']?['order_gallery'];
            debugPrint('Order "$title" order_gallery: $gallery');
            if (gallery is List && gallery.isNotEmpty) {
              final firstImage = gallery[0];
              debugPrint('Order "$title" firstImage: $firstImage');
              if (firstImage is Map && firstImage['id'] != null) {
                final imageId = firstImage['id'];
                debugPrint('Order "$title" imageId: $imageId');
                try {
                  final mediaResponse = await SafeHttp.safeGet(context, Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$imageId'), headers: {'X-API-KEY': apiKey});
                  if (mediaResponse.statusCode == 200) {
                    final mediaData = json.decode(mediaResponse.body);
                    imageUrl = mediaData['source_url'];
                    debugPrint('Order "$title" fetched imageUrl: $imageUrl');
                  } else {
                    debugPrint('Order "$title" failed to fetch media for ID $imageId: ${mediaResponse.statusCode}');
                  }
                } catch (e) {
                  debugPrint('Order "$title" error fetching media for ID $imageId: $e');
                }
              } else {
                debugPrint('Order "$title" firstImage is not a Map or has no id');
              }
            } else {
              debugPrint('Order "$title" gallery is not a List or is empty');
            }
          } else {
            debugPrint('Order "$title" has no order_gallery');
          }

          fetchedOrders.add(Order(
            title: title,
            description: description,
            status: status,
            date: date,
            imageUrl: imageUrl,
            fullOrder: item, // Store the complete order data for navigation
          ));
        }

        // Filter by current user
        List<Order> userOrders = fetchedOrders.where((order) {
          if (order.fullOrder != null && currentUserId != null) {
            return order.fullOrder!['author'] == currentUserId;
          }
          return false;
        }).toList();
        debugPrint('Created ${userOrders.length} user order objects');
        debugPrint('Orders with images: ${userOrders.where((o) => o.imageUrl != null && o.imageUrl!.isNotEmpty).length}');

        if (mounted) {
          setState(() {
            _orders = userOrders;
            _isLoadingOrders = false;
          });
        }

        // Save to cache
        await _cacheManager.saveToCache('orders', fetchedOrders.map((o) => o.toJson()).toList());
      } else {
        debugPrint('Failed to load orders: ${response.statusCode}');
        if (mounted) {
          setState(() => _isLoadingOrders = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building HomePageScreenClient');
    debugPrint('Categories count: ${_categories.length}');
    debugPrint('Partners count: ${_partners.length}');
    debugPrint('Orders count: ${_orders.length}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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

                  // Categories Section
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _isLoadingCategories
                      ? _buildCategoryShimmer()
                      : _categories.isEmpty
                          ? const Center(child: Text('No categories available or failed to load.'))
                          : SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _categories.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  return _buildCategoryCard(category);
                                },
                              ),
                            ),
                  const SizedBox(height: 24),

                  // Partners Section
                  const Text(
                    'Our Partners',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _isLoadingPartners
                      ? _buildPartnerShimmer()
                      : _partners.isEmpty
                          ? const Center(child: Text('No partners available'))
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
                  const SizedBox(height: 24),

                  // My Orders Section
                  const Text(
                    'My Orders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _isLoadingOrders
                      ? _buildOrderShimmer()
                      : _orders.isEmpty
                          ? const Center(child: Text('No orders available'))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _orders.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                return _buildOrderCard(order);
                              },
                            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to category details
        },
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 100,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 253, 250),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 59, 59, 59).withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (category.imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: ExtendedImage.network(
                      category.imageUrl!,
                      height: 60,
                      width: 100,
                      fit: BoxFit.cover,
                      cache: true,
                      enableLoadState: true,
                      loadStateChanged: (state) {
                        if (state.extendedImageLoadState == LoadState.completed) {
                          return ExtendedRawImage(
                            image: state.extendedImageInfo?.image,
                            fit: BoxFit.cover,
                          );
                        } else if (state.extendedImageLoadState == LoadState.failed) {
                          return Container(
                            height: 60,
                            width: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.category, color: Colors.grey),
                          );
                        }
                        return null;
                      },
                    ),
                  )
                else
                  Container(
                    height: 60,
                    width: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.category, color: Colors.grey),
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerCard(Partner partner) {
    debugPrint('Building partner card for: ${partner.title}');
    debugPrint('Partner logo URL: ${partner.logoUrl}');
    debugPrint('Logo URL is empty: ${partner.logoUrl?.isEmpty ?? true}');
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to partner details
        },
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 59, 59, 59).withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: partner.logoUrl != null && partner.logoUrl!.isNotEmpty
                      ? ExtendedImage.network(
                        partner.logoUrl!,
                        height: 80,
                        width: 100,
                        fit: BoxFit.contain,
                        cache: true,
                        enableLoadState: true,
                        loadStateChanged: (state) {
                        if (state.extendedImageLoadState == LoadState.completed) {
                          return ExtendedRawImage(
                          image: state.extendedImageInfo?.image,
                          fit: BoxFit.contain,
                          );
                        } else if (state.extendedImageLoadState == LoadState.failed) {
                          return Container(
                          height: 110,
                          width: 150,
                          color: Colors.grey[200],
                          child: const Icon(Icons.business, size: 60, color: Colors.grey),
                          );
                        }
                        return null;
                        },
                      )
                    : Container(
                        height: 110,
                        width: 150,
                        color: Colors.grey[200],
                        child: const Icon(Icons.business, size: 60, color: Colors.grey),
                      ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return InkWell(
      onTap: () {
        debugPrint('Order card tapped. fullOrder: \\${order.fullOrder}');
        if (order.fullOrder != null) {
          debugPrint('Navigating to SingleMyOrderPageScreen with order: \\${order.fullOrder}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SingleMyOrderPageScreen(order: order.fullOrder!),
            ),
          );
        } else {
          debugPrint('Order fullOrder is null, not navigating.');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              if (order.imageUrl != null && order.imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    order.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300]),
                  ),
                ),
              // Full overlay across the whole card
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(172, 0, 0, 0).withOpacity(0.4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            order.date,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryShimmer() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPartnerShimmer() {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderShimmer() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class Category {
  final int id;
  final String name;
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    int? safeId;
    if (rawId is int) {
      safeId = rawId;
    } else if (rawId is String) {
      safeId = int.tryParse(rawId);
    }
    return Category(
      id: safeId ?? 0, // Use 0 if id is null or not convertible
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
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

class Order {
  final String title;
  final String description;
  final String status;
  final String date;
  final String? imageUrl;
  final Map<String, dynamic>? fullOrder;

  Order({
    required this.title,
    required this.description,
    required this.status,
    required this.date,
    this.imageUrl,
    this.fullOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'date': date,
      'imageUrl': imageUrl,
      'fullOrder': fullOrder,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      date: json['date'] as String,
      imageUrl: json['imageUrl'] as String?,
      fullOrder: json['fullOrder'] as Map<String, dynamic>?,
    );
  }
}

// Helper class for temp category data
class _CategoryTemp {
  final int id;
  final String name;
  final int? imageMediaId;
  _CategoryTemp({required this.id, required this.name, this.imageMediaId});
}
