import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MyOrderPageScreen extends StatefulWidget {
  const MyOrderPageScreen({super.key});

  @override
  _MyOrderPageScreenState createState() => _MyOrderPageScreenState();
}

class _MyOrderPageScreenState extends State<MyOrderPageScreen> {
  late Future<List<String>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _fetchImages();
  }

  // Function to fetch images from the WordPress media endpoint
  Future<List<String>> _fetchImages() async {
    // Using per_page=100 to try and fetch up to 100 images in one request.
    // If there are more than 100 images, pagination logic would be needed.
    final response = await http.get(
      Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media?per_page=100'),
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      List<String> imageUrls = [];

      for (var item in data) {
        // Check if the item has media_details and sizes, then get the 'medium' or 'full' size
        if (item.containsKey('media_details') &&
            item['media_details'].containsKey('sizes') &&
            item['media_details']['sizes'].containsKey('medium') &&
            item['media_details']['sizes']['medium'].containsKey('source_url')) {
          imageUrls.add(item['media_details']['sizes']['medium']['source_url']);
        } else if (item.containsKey('source_url')) {
          // Fallback to source_url if specific sizes are not available
          imageUrls.add(item['source_url']);
        }
      }
      return imageUrls;
    } else {
      throw Exception('Failed to load images. Status Code: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Gallery'),
      ),
      body: FutureBuilder<List<String>>(
        future: _imagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No images found.'));
          } else {
            final imageUrls = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 images per row
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 1.0, // Square images
              ),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final imageUrl = imageUrls[index];
                return Card(
                  clipBehavior: Clip.antiAlias, // Clip image to card shape
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null, // Calculate progress or set to null if total bytes are unknown
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
