import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class SingleOrderPageScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const SingleOrderPageScreen({super.key, required this.order});

  @override
  State<SingleOrderPageScreen> createState() => _SingleOrderPageScreenState();
}

class _SingleOrderPageScreenState extends State<SingleOrderPageScreen> {
  Map<String, dynamic>? _user;
  List<String> _imageUrls = [];
  Map<int, String> _categoryMap = {};
  List<String> _orderCategories = [];
  bool _isLoading = true;

  final String mediaUrlBase = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/';
  final String usersApiBaseUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/users/';
  final String categoriesUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories';
  final String apiKey = '1234567890abcdef'; 

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    setState(() {
      _isLoading = true;
    });

    final authorId = widget.order['author'];
    final List<dynamic> galleryDynamic = widget.order['meta']?['order_gallery'] ?? [];
    final List<dynamic> rawCategoryIds = widget.order['order-categories'] ?? [];

    List<int> galleryImageIds = [];
    for (var item in galleryDynamic) {
      if (item is int) {
        galleryImageIds.add(item);
      } else if (item is Map<String, dynamic> && item.containsKey('id') && item['id'] is int) {
        galleryImageIds.add(item['id'] as int);
      } else {
        print('Warning: Unexpected type in order_gallery: $item');
      }
    }

    try {
      List<Future<dynamic>> futures = [];

      // Add user fetch future (using your custom API endpoint)
      futures.add(http.get(
        Uri.parse('$usersApiBaseUrl$authorId'),
        headers: {'X-API-KEY': apiKey},
      ));
      // Add categories fetch future
      futures.add(http.get(Uri.parse(categoriesUrl)));

      // Add futures for all gallery image URLs
      for (int mediaId in galleryImageIds) {
        futures.add(http.get(
          Uri.parse('$mediaUrlBase$mediaId'),
          headers: {'X-API-KEY': apiKey},
        ));
      }

      List<dynamic> responses = await Future.wait(futures);

      // Process user response (first item in responses list)
      final http.Response userResponse = responses[0];
      Map<String, dynamic>? user;
      if (userResponse.statusCode == 200) {
        final decodedUser = jsonDecode(userResponse.body);
        user = decodedUser is Map<String, dynamic> ? decodedUser : null;
        print('Fetched User Data: $user'); // Keep this for debugging the structure
      } else {
        print('Failed to fetch user: ${userResponse.statusCode}');
      }

      // Process categories response (second item in responses list)
      final http.Response categoriesResponse = responses[1];
      Map<int, String> categoryMap = {};
      if (categoriesResponse.statusCode == 200) {
        List<dynamic> categories = jsonDecode(categoriesResponse.body);
        for (var cat in categories) {
          if (cat['id'] is int && cat['name'] is String) {
            categoryMap[cat['id']] = cat['name'];
          }
        }
      } else {
        print('Failed to fetch categories: ${categoriesResponse.statusCode}');
      }

      // Process gallery image responses (remaining items in responses list, starting from index 2)
      List<String> imageUrls = [];
      for (int i = 2; i < responses.length; i++) {
        final http.Response mediaResponse = responses[i];
        if (mediaResponse.statusCode == 200) {
          final mediaData = jsonDecode(mediaResponse.body);
          final imageUrl = mediaData['source_url'];
          if (imageUrl != null && imageUrl is String) {
            imageUrls.add(imageUrl);
          }
        } else {
          print('Failed to fetch media ID ${galleryImageIds[i - 2]}: Status ${mediaResponse.statusCode}');
        }
      }

      // Map raw category IDs from the order to names
      List<String> orderCategories = [];
      for (var id in rawCategoryIds) {
        if (id is int) {
          orderCategories.add(categoryMap[id] ?? 'Unknown Category');
        }
      }

      setState(() {
        _user = user;
        _imageUrls = imageUrls;
        _categoryMap = categoryMap;
        _orderCategories = orderCategories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching details: $e');
      setState(() {
        _isLoading = false;
        _user = null;
        _imageUrls = [];
        _categoryMap = {};
        _orderCategories = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final meta = order['meta'] ?? {};
    final title = order['title']?['rendered'] ?? 'No title';
    final content = _stripHtml(order['content']?['rendered'] ?? '');

    final userName = _user?['display_name'] ?? 'N/A'; 
    final userEmail = _user?['user_email'] ?? 'N/A'; 

    String userPhone = 'N/A'; 

   
    if (_user != null) {
      // Safely access 'meta_data'
      Map<String, dynamic>? metaData = _user!['meta_data'];

      if (metaData != null) {
        // Safely access 'user_phone' from 'meta_data'
        dynamic phoneList = metaData['user_phone'];

       
        if (phoneList is List && phoneList.isNotEmpty) {
          dynamic phoneValue = phoneList.first;
          
          userPhone = phoneValue.toString();
        }
      }
    }


    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_orderCategories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Categories: ${_orderCategories.join(', ')}',
                        style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text('Street Address: ${meta['address_1'] ?? 'N/A'}'),
                  Text('Postal Code: ${meta['address_2'] ?? 'N/A'}'),
                  Text('City: ${meta['address_3'] ?? 'N/A'}'),
                  const SizedBox(height: 16),
                  const Text('Description:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(content),
                  const SizedBox(height: 24),
                  if (_user != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const Text('Posted by:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Name: $userName'),
                          Text('Email: $userEmail'),
                          Text('Phone: $userPhone'),
                          const SizedBox(height: 24),
                        ],
                      ),

                  if (_imageUrls.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gallery:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: _imageUrls.length,
                          itemBuilder: (context, index) {
                            final imageUrl = _imageUrls[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('No gallery images available.'),
                    ),
                ],
              ),
            ),
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}