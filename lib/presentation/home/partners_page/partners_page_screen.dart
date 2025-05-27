import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; 

class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  late Future<List<Partner>> _partnersFuture;

  // IMPORTANT: Replace 'YOUR_API_KEY_HERE' with your actual API key
  final String _apiKey = 'YOUR_API_KEY_HERE'; 

  @override
  void initState() {
    super.initState();
    _partnersFuture = fetchPartners();
  }

  Future<List<Partner>> fetchPartners() async {
    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/partners');
    final response = await http.get(url, headers: {
      'X-API-Key': _apiKey,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('Failed to load partners: ${response.statusCode}');
    }

    final List data = jsonDecode(response.body);
    List<Partner> partners = [];

    for (var item in data) {
      final title = item['title']?['rendered'] ?? 'No Title';
      final address = item['meta']?['adresse'] ?? 'No Address';
      final logoId = item['meta']?['logo']?['id'];

      partners.add(Partner(title: title, address: address, logoId: logoId));
    }

    return partners;
  }

  Future<String?> fetchLogoUrl(int logoId) async {
    final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media/$logoId');
    final response = await http.get(url, headers: {
      'X-API-Key': _apiKey,
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data != null && data['source_url'] is String) {
        return data['source_url'];
      } else {
        print('Warning: "source_url" not found or not a string for logoId: $logoId');
        return null;
      }
    } else {
      print('Failed to load logo URL for ID $logoId: Status ${response.statusCode}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(title: const Text('Partners')),
      body: FutureBuilder<List<Partner>>(
        future: _partnersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _partnersFuture = fetchPartners(); // Retry fetching data
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No partners found.'));
          }

          final partners = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: partners.length,
            itemBuilder: (context, index) {
              final partner = partners[index];
              return Card(
                color: const Color.fromARGB(255, 255, 253, 252),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // MODIFIED: Logo loading now hides the loading icon
                      partner.logoId != null
                          ? FutureBuilder<String?>(
                              future: fetchLogoUrl(partner.logoId!),
                              builder: (context, logoSnapshot) {
                                // If still waiting for the URL or an error, show an empty SizedBox
                                if (logoSnapshot.connectionState == ConnectionState.waiting ||
                                    logoSnapshot.hasError ||
                                    logoSnapshot.data == null) {
                                  return const SizedBox(
                                    width: 100,
                                    height: 100,
                                    // You can use a specific color or placeholder image here if desired,
                                    // or just leave it empty.
                                    // child: ColoredBox(color: Colors.grey[200]!), // Example: grey placeholder
                                  );
                                }
                                // Logo URL loaded successfully, display the Image.network
                                return SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Image.network(
                                    logoSnapshot.data!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      // This errorBuilder is for the Image.network itself, if the URL is bad
                                      return const Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.grey,
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      // This loadingBuilder is for the actual image bytes download
                                      // We can return 'child' immediately to hide the loading indicator for bytes too
                                      if (loadingProgress == null) return child;
                                      // Or, if you want a subtle loading indicator for the bytes:
                                      // return Center(
                                      //   child: CircularProgressIndicator(
                                      //     value: loadingProgress.expectedTotalBytes != null
                                      //         ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      //         : null,
                                      //     strokeWidth: 2,
                                      //   ),
                                      // );
                                      return child; // Directly return the image child without a loading indicator
                                    },
                                  ),
                                );
                              },
                            )
                          : const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        partner.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Address
                      Text(
                        partner.address,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class Partner {
  final String title;
  final String address;
  final int? logoId;

  Partner({
    required this.title,
    required this.address,
    this.logoId,
  });
}
