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
  List<dynamic> _filteredOrders = [];
  final Map<int, String> _orderImages = {};
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    fetchOrders();
    fetchCategories();
  }

  Future<void> fetchOrders() async {
    final response = await http.get(Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        _orders = data;
      });

      _filterOrders();

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
          }
        }
      }
    } else {
      print('Failed to load orders: ${response.statusCode}');
    }
  }

  Future<void> fetchCategories() async {
    final response = await http.get(Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        _categories = data;
      });
    } else {
      print('Failed to load categories: ${response.statusCode}');
    }
  }

  void _filterOrders() {
    String normalize(String input) => input.toLowerCase().replaceAll(RegExp(r'\\s+'), '');

    final search = normalize(_searchText);

    setState(() {
      _filteredOrders = _orders.where((order) {
        final title = normalize(order['title']['rendered'].toString());
        final matchesSearch = title.contains(search);

        if (_selectedCategoryId == null) return matchesSearch;

        final orderCategories = order['order-categories'] ?? [];
        final matchesCategory = orderCategories.contains(_selectedCategoryId);

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }


 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque, // Ensures taps are registered outside widgets
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Column(
          children: [
            // 🔍 Search Bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by title...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: const BorderSide(
                      color: Color.fromARGB(143, 51, 1, 1),
                      width: 1,
                    ),
                  ),
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                onChanged: (value) {
                  _searchText = value;
                  _filterOrders();
                },
              ),
            ),

            // 📂 Category Filter
            SizedBox(
              height: 65,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final category = isAll ? null : _categories[index - 1];
                  final id = isAll ? null : category['id'];
                  final name = isAll ? 'All' : category['name'];
                  final isSelected = _selectedCategoryId == id;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: isSelected,
                      selectedColor: Colors.brown.shade100,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryId = id;
                        });
                        _filterOrders();
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // 📦 Orders List
            Expanded(
              child: _orders.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                      ? const Center(child: Text("No orders match your criteria."))
                      : ListView.builder(
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            final imageUrl = _orderImages[order['id']];

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
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
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 20),
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
                                              child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    ),
  );
}


}
