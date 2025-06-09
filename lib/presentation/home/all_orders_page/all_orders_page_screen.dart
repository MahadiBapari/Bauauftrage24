import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Added for Future.wait
import 'package:shared_preferences/shared_preferences.dart';

// Ensure this is imported if used for images
import 'single_order_page_screen.dart'; // Ensure this is imported
import '../../../widgets/membership_required_dialog.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../../utils/cache_manager.dart';

class AllOrdersPageScreen extends StatefulWidget {
  const AllOrdersPageScreen({super.key});

  @override
  _AllOrdersPageScreenState createState() => _AllOrdersPageScreenState();
}

class _AllOrdersPageScreenState extends State<AllOrdersPageScreen> {
  // Loading states
  bool _isLoadingOrders = true;
  bool _isLoadingCategories = true;
  bool _isFetchingMore = false; // New: To track if more orders are being fetched

  // Data lists
  List<Map<String, dynamic>> _orders = []; // Stores raw fetched orders with image URLs
  List<Map<String, dynamic>> _filteredOrders = []; // Stores orders after search/category filter
  List<Map<String, dynamic>> _categories = []; // Stores fetched categories with ID and Name

  // Filter/Search states
  int? _selectedCategoryId; // null for "All Categories"
  String _searchText = '';

  // Pagination states
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreOrders = true; // New: To check if there are more pages to load

  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  // API constants
  final String ordersEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order';
  final String categoriesEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories';
  final String mediaEndpointBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';
  final String apiKey = '1234567890abcdef'; // Assuming API key needed for user data

  // Add membership state
  bool _isActiveMembership = false;
  bool _isLoadingMembership = true;
  final String _membershipEndpoint = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/user-membership';

  // Add CacheManager instance
  final CacheManager _cacheManager = CacheManager();

  @override
  void initState() {
    super.initState();
    _loadAllData(); // Start fetching initial data
    _scrollController.addListener(_scrollListener); // Add listener for pagination
    _fetchMembershipStatus(); // Add membership check
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Listener for scroll events to trigger pagination
  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isFetchingMore && _hasMoreOrders) {
      _loadMoreOrders();
    }
  }

  // Combines all initial data fetching operations using Future.wait
  Future<void> _loadAllData() async {
    if (mounted) {
      setState(() {
        _isLoadingOrders = true;
        _isLoadingCategories = true;
      });
    }

    try {
      // Load from cache first
      final cachedData = await Future.wait([
        _cacheManager.loadFromCache('all_orders'),
        _cacheManager.loadFromCache('categories'),
      ]);

      if (mounted) {
        setState(() {
          if (cachedData[0] != null) {
            _orders = List<Map<String, dynamic>>.from(cachedData[0] as List);
            _filterOrders();
          }
          if (cachedData[1] != null) {
            _categories = List<Map<String, dynamic>>.from(cachedData[1] as List);
            _isLoadingCategories = false;
          }
        });
      }

      // Check if cache is expired
      final needsRefresh = await Future.wait([
        _cacheManager.isCacheExpired('all_orders'),
        _cacheManager.isCacheExpired('categories'),
      ]);

      // Refresh only if cache is expired
      if (needsRefresh.any((needs) => needs)) {
        await Future.wait([
          _fetchOrders(page: 1, perPage: _perPage, append: false),
          _fetchCategories(),
        ]);
      }
    } catch (e) {
      debugPrint('Error loading all data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
          _isLoadingCategories = false;
        });
      }
    }
  }

  // New method to load more orders for pagination
  Future<void> _loadMoreOrders() async {
    if (mounted) {
      setState(() {
        _isFetchingMore = true;
      });
    }
    _currentPage++;
    await _fetchOrders(page: _currentPage, perPage: _perPage, append: true);

    if (mounted) {
      setState(() {
        _isFetchingMore = false;
      });
    }
  }

  Future<void> _fetchOrders({required int page, required int perPage, required bool append}) async {
    List<Map<String, dynamic>> currentFetchedOrders = [];
    try {
      final headers = <String, String>{};
      // You might need an Authorization header here if orders are protected
      // if (_authToken != null) {
      //   headers['Authorization'] = 'Bearer $_authToken';
      // }

      final response = await http.get(
        Uri.parse('$ordersEndpoint?page=$page&per_page=$perPage'),
        headers: headers,
      );

      if (!mounted) return; // Crucial check after await

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        for (var order in data) {
          String imageUrl = '';
          List<dynamic> galleryDynamic = order['meta']?['order_gallery'] ?? [];

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
              final mediaResponse = await http.get(Uri.parse(mediaUrl));

              if (!mounted) return; // Crucial check after inner await

              if (mediaResponse.statusCode == 200) {
                try {
                  final mediaData = jsonDecode(mediaResponse.body);
                  imageUrl = mediaData['source_url'] ?? mediaData['media_details']?['sizes']?['full']?['source_url'] ?? '';
                } catch (e) {
                  debugPrint('Error decoding media data for ID $firstImageId: $e');
                }
              } else {
                debugPrint('Failed to fetch media for ID $firstImageId: ${mediaResponse.statusCode}');
              }
            }
          }
          order['imageUrl'] = imageUrl;
          currentFetchedOrders.add(order);
        }

        if (mounted) {
          setState(() {
            if (append) {
              _orders.addAll(currentFetchedOrders); // Append for pagination
            } else {
              _orders = currentFetchedOrders; // Overwrite for initial load
              // Save to cache when fetching fresh data
              _cacheManager.saveToCache('all_orders', currentFetchedOrders);
            }
            _hasMoreOrders = data.length == _perPage; // Check if the number of fetched items equals perPage
          });
        }
      } else {
        debugPrint('Failed to load orders: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _hasMoreOrders = false; // No more orders if fetch failed
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) {
        setState(() {
          _hasMoreOrders = false; // No more orders on error
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

      if (!mounted) return;

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
          // Save to cache
          await _cacheManager.saveToCache('categories', fetchedCategories);
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
    String normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    final search = normalize(_searchText);

    if (mounted) {
      setState(() {
        _filteredOrders = _orders.where((order) {
          final title = normalize(order['title']?['rendered'].toString() ?? '');
          final matchesSearch = title.contains(search);

          if (_selectedCategoryId == null) {
            return matchesSearch;
          }

          final orderCategoryIds = order['order-categories'] ?? [];
          final matchesCategory = orderCategoryIds.contains(_selectedCategoryId);

          return matchesSearch && matchesCategory;
        }).toList();
      });
    }
  }

  // Add membership status fetch
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
            _isLoadingMembership = false;
          });
        }
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

        if (mounted) {
          setState(() {
            _isActiveMembership = active;
            _isLoadingMembership = false;
          });
        }
      } else {
        debugPrint('Failed to load membership status: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _isActiveMembership = false;
            _isLoadingMembership = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching membership status: $e');
      if (mounted) {
        setState(() {
          _isActiveMembership = false;
          _isLoadingMembership = false;
        });
      }
    }
  }

  // Add refresh method
  Future<void> _onRefresh() async {
    await Future.wait([
      _fetchOrders(page: 1, perPage: _perPage, append: false),
      _fetchCategories(),
      _fetchMembershipStatus(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
     
      body: GestureDetector( // Main GestureDetector for the body
        behavior: HitTestBehavior.opaque, // Ensures taps are registered outside widgets
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
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
                      // controller: _searchController, // Uncomment and declare if you need to clear programmatically
                      decoration: InputDecoration(
                        hintText: 'Search by title...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                        suffixIcon: _searchText.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade600),
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      _searchText = '';
                                      // _searchController?.clear(); // If using controller
                                    });
                                  }
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
                        if (mounted) {
                          setState(() {
                            _searchText = value;
                          });
                        }
                        _filterOrders();
                      },
                    ),
                  ),
                ),
              ),

              // Category Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _isLoadingCategories
                        ? const CustomLoadingIndicator(
                            message: 'Loading categories...',
                            isHorizontal: true,
                            itemCount: 5,
                            itemHeight: 40,
                            itemWidth: 100,
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
                                    final id = category['id'];
                                    final name = category['name'];
                                    final isSelected = _selectedCategoryId == id;

                                    return ActionChip(
                                      label: Text(name!),
                                      backgroundColor: isSelected
                                          ? const Color.fromARGB(255, 85, 21, 1)
                                          : Colors.grey[200],
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      onPressed: () {
                                        // Dismiss keyboard when a category chip is tapped
                                        FocusScope.of(context).unfocus();
                                        if (mounted) {
                                          setState(() {
                                            _selectedCategoryId = isSelected ? null : id;
                                          });
                                        }
                                        _filterOrders();
                                      },
                                    );
                                  },
                                ),
                              ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Orders List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: _isLoadingOrders
                      ? const CustomLoadingIndicator(
                          message: 'Loading orders...',
                          itemCount: 5,
                          itemHeight: 120,
                          itemWidth: double.infinity,
                          isScrollable: true,
                        )
                      : _filteredOrders.isEmpty
                          ? const Center(child: Text("No orders found matching your criteria."))
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: _filteredOrders.length + (_hasMoreOrders ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _filteredOrders.length) {
                                  return _isFetchingMore
                                      ? const CustomLoadingIndicator(
                                          size: 30.0,
                                          message: 'Loading more...',
                                        )
                                      : const SizedBox.shrink();
                                }

                                final order = _filteredOrders[index];
                                final imageUrl = order['imageUrl'] ?? '';
                                final title = order['title']['rendered'] ?? 'Untitled';
                                final categoryName = order['acf']?['category'] ?? 'N/A';

                                return GestureDetector(
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    if (_isActiveMembership) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SingleOrderPageScreen(order: order),
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
                                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    height: 180,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: imageUrl.isNotEmpty
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
                                      gradient: imageUrl.isEmpty
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
                                          Text(
                                            categoryName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}