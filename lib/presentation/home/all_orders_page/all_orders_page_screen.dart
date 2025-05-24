import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'single_order_page_screen.dart';

class AllOrdersPageScreen extends StatefulWidget {

  const AllOrdersPageScreen({super.key});

  @override
  _AllOrdersPageScreenState createState() => _AllOrdersPageScreenState();
}

class _AllOrdersPageScreenState extends State<AllOrdersPageScreen> {
  List<dynamic> _orders = [];
  Map<int, String> _orderImages = {};

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final response = await http.get(Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        _orders = data;
      });

      for (var order in data) {
        List<dynamic> gallery = order['meta']?['order_gallery'] ?? [];
        if (gallery.isNotEmpty) {
          int firstImageId = gallery[0]['id'];

          final mediaUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$firstImageId';
          final mediaResponse = await http.get(Uri.parse(mediaUrl));

          if (mediaResponse.statusCode == 200) {
            final mediaData = jsonDecode(mediaResponse.body);
            final imageUrl = mediaData['media_details']?['sizes']?['full']?['source_url'] ?? mediaData['source_url'];

            setState(() {
              _orderImages[order['id']] = imageUrl;
            });
          } else {
            print('Failed to fetch image metadata for ID: $firstImageId');
          }
        } else {
          print('No images found in gallery for order ${order['id']}');
        }
      }
    } else {
      print('Failed to load orders: ${response.statusCode}');
    }
  }

  @override
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('All Orders')),
    body: _orders.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              final order = _orders[index];
              final imageUrl = _orderImages[order['id']];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 3,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SingleOrderPageScreen(order: order),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['title']['rendered'],
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image),
                                ),
                              )
                            : Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image_not_supported,
                                    size: 50, color: Colors.grey),
                              ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
  );
}

}
