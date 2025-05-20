import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SingleOrderPage extends StatefulWidget {
  final int orderId;

  const SingleOrderPage({super.key, required this.orderId});

  @override
  State<SingleOrderPage> createState() => _SingleOrderPageState();
}

class _SingleOrderPageState extends State<SingleOrderPage> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order/${widget.orderId}?_embed');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _order = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load order');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final title = _order?['title']['rendered'] ?? '';
    final content = _order?['content']['rendered'] ?? '';
    final meta = _order?['meta'] ?? {};
    final image = _order?['_embedded']?['wp:featuredmedia']?[0]?['source_url'];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null)
              Image.network(image, height: 200, width: double.infinity, fit: BoxFit.cover),
            const SizedBox(height: 20),
            Text('Street: ${meta['address_'] ?? '-'}'),
            Text('Postal Code: ${meta['_address__2'] ?? '-'}'),
            Text('City: ${meta['_address__3'] ?? '-'}'),
            const SizedBox(height: 10),
            const Divider(),
            const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(content.replaceAll(RegExp(r'<[^>]*>'), '')), // remove HTML tags
          ],
        ),
      ),
    );
  }
}