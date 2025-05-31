import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

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

    List<int> galleryImageIds = galleryDynamic
    .whereType<Map>()
    .map((item) => item['id'])
    .whereType<int>()
    .toList();

    try {
      List<Future<dynamic>> futures = [
        http.get(Uri.parse('$usersApiBaseUrl$authorId'), headers: {'X-API-KEY': apiKey}),
        http.get(Uri.parse(categoriesUrl))
      ];

      for (int mediaId in galleryImageIds) {
        futures.add(http.get(Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$mediaId'), headers: {'X-API-KEY': apiKey}));
      }

      List<dynamic> responses = await Future.wait(futures);

      final http.Response userResponse = responses[0];
      Map<String, dynamic>? user;
      if (userResponse.statusCode == 200) {
        user = jsonDecode(userResponse.body);
      }

      final http.Response categoriesResponse = responses[1];
      Map<int, String> categoryMap = {};
      if (categoriesResponse.statusCode == 200) {
        List<dynamic> categories = jsonDecode(categoriesResponse.body);
        for (var cat in categories) {
          if (cat['id'] is int && cat['name'] is String) {
            categoryMap[cat['id']] = cat['name'];
          }
        }
      }

      List<String> imageUrls = [];
      for (int i = 2; i < responses.length; i++) {
        final mediaResponse = responses[i];
        if (mediaResponse.statusCode == 200) {
          final mediaData = jsonDecode(mediaResponse.body);
          final imageUrl = mediaData['source_url'];
          if (imageUrl != null) imageUrls.add(imageUrl);
        }
      }

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
      print('Error: $e');
      setState(() {
        _isLoading = false;
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
      var metaData = _user!['meta_data'];
      if (metaData != null) {
        var phoneList = metaData['user_phone'];
        if (phoneList is List && phoneList.isNotEmpty) {
          userPhone = phoneList.first.toString();
        }
      }
    }

return Scaffold(

  backgroundColor: Colors.white, // Safe to keep white now
  body: _isLoading
      ? const Center(child: CircularProgressIndicator())
      : Stack(
          children: [
            // --- White Background (base layer) ---
            Container(
              color: Colors.white,
            ),

            // --- Top Image Gallery ---
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              width: double.infinity,
              child: _imageUrls.isNotEmpty
                  ? PageView.builder(
                      itemCount: _imageUrls.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenGallery(
                                  images: _imageUrls,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: _imageUrls[index],
                            child: CachedNetworkImage(
                              imageUrl: _imageUrls[index],
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  const Center(child: CircularProgressIndicator()),
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Center(child: Text('No images available')),
                    ),
            ),

            // --- Info Card ---
            Positioned(
              top: MediaQuery.of(context).size.height * 0.43,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_orderCategories.isNotEmpty)
                        Text(
                          _orderCategories.join(', '),
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      const SizedBox(height: 8),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text(content, style: const TextStyle(fontSize: 16)),

                      const SizedBox(height: 16),
                      const Divider(),
                      const Text('Contact Info',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Name: $userName'),
                      Text('Email: $userEmail'),
                      Text('Phone: $userPhone'),

                      const SizedBox(height: 16),
                      const Divider(),
                      const Text('Order Details',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Street Address: ${meta['address_1'] ?? 'N/A'}'),
                      Text('Postal Code: ${meta['address_2'] ?? 'N/A'}'),
                      Text('City: ${meta['address_3'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ),
            ), // --- Back Button (Wrapped with SafeArea) ---
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
            ),
    
          ],
        ),
);




  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}

class FullScreenGallery extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGallery({super.key, required this.images, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: images.length,
            pageController: PageController(initialPage: initialIndex),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(images[index]),
                heroAttributes: PhotoViewHeroAttributes(tag: images[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
