import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AllOrdersPageScreen extends StatefulWidget {
  const AllOrdersPageScreen({super.key});

  @override
  State<AllOrdersPageScreen> createState() => _AllOrdersPageScreenState();
}

class _AllOrdersPageScreenState extends State<AllOrdersPageScreen> {
  List<dynamic> _orders = [];
  Map<int, String> _categoryMap = {};
  bool _isLoading = true;

  final String ordersUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order';
  final String categoriesUrl = 'https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories';
  final String apiKey = 'YOUR_API_KEY_HERE'; // Replace with your actual API key

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final categoriesResponse = await http.get(Uri.parse(categoriesUrl));
      if (categoriesResponse.statusCode == 200) {
        List<dynamic> categories = jsonDecode(categoriesResponse.body);
        _categoryMap = {
          for (var cat in categories) cat['id']: cat['name']
        };
      }

      final ordersResponse = await http.get(
        Uri.parse(ordersUrl),
        headers: {'X-API-KEY': apiKey},
      );
      if (ordersResponse.statusCode == 200) {
        setState(() {
          _orders = jsonDecode(ordersResponse.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch orders');
      }
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_orders.isEmpty) return const Center(child: Text('No orders found.'));

    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final meta = order['meta'] ?? {};
        final contentHtml = order['content']?['rendered'] ?? '';
        final title = order['title']?['rendered'] ?? 'No title';

        // Convert category IDs to names
        List<int> categoryIds = List<int>.from(order['order-categories'] ?? []);
        String categoryNames = categoryIds
            .map((id) => _categoryMap[id] ?? 'Unknown')
            .join(', ');

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Categories: $categoryNames'),
                Text('Street Address: ${meta['address_'] ?? 'N/A'}'),
                Text('Postal Code: ${meta['_address__2'] ?? 'N/A'}'),
                Text('City: ${meta['_address__3'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_stripHtml(contentHtml)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}
