import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart'; 

class AddNewOrderPageScreen extends StatefulWidget {
  const AddNewOrderPageScreen({super.key});

  @override
  _AddNewOrderPageScreenState createState() => _AddNewOrderPageScreenState();
}

class _AddNewOrderPageScreenState extends State<AddNewOrderPageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _streetController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _picker = ImagePicker();
  final String _apiKey = '1234567890abcdef';
  String? _authToken;
  File? _selectedImage;
  List<String> _selectedCategories = [];
  bool _isSubmitting = false;

  
  late Future<List<Map<String, dynamic>>> _categoriesFuture; 

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    _categoriesFuture = _fetchOrderCategories(); // Fetch categories in initState
  }

  // Function to fetch order categories from the API
  Future<List<Map<String, dynamic>>> _fetchOrderCategories() async {
    final response = await http.get(
      Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/order-categories?per_page=100'),
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((item) => {
        'id': item['id'],
        'name': item['name'],
      }).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('auth_token');
    });
    print("Retrieved Token in AddNewOrderPage: $_authToken");
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text("Gallery"),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera),
            title: const Text("Camera"),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source != null) {
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    }
  }

    Future<int?> uploadImage(File imageFile) async {
      final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/media');
      final request = http.MultipartRequest('POST', url)
      ..headers.addAll({
      'Authorization': 'Bearer $_authToken',
      'X-API-Key': _apiKey,
      'Content-Disposition': 'attachment; filename="${path.basename(imageFile.path)}"',
      })
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
      final data = jsonDecode(responseBody);
      return data['id']; 
      } else {
      print('Image upload failed: $responseBody');
      return null;
      }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;
  if (_authToken == null) {
    _showError("Authentication required. Please log in.");
    return;
  }

  setState(() => _isSubmitting = true);

      int? imageId;
      if (_selectedImage != null) {
        imageId = await uploadImage(_selectedImage!);
          if (imageId == null) {
          _showError("Image upload failed.");
          setState(() => _isSubmitting = false);
          return;
          }
      }

  final Map<String, dynamic> postData = {
    "title": _titleController.text,
    "content": _descriptionController.text,
    "status": "publish",
    "meta": {
      "address_1": _streetController.text,
      "address_2": _postalCodeController.text,
      "address_3": _cityController.text,
      if (imageId != null) "order_gallery": [imageId],
    },
    "order-categories": _selectedCategories,
  };

  final url = Uri.parse('https://xn--bauauftrge24-ncb.ch/wp-json/wp/v2/client-order');

  try {
    var request = http.MultipartRequest('POST', url);
    request.headers['X-API-Key'] = _apiKey;
    request.headers['Authorization'] = 'Bearer $_authToken';

    request.fields['title'] = postData['title'];
    request.fields['content'] = postData['content'];
    request.fields['status'] = postData['status'];
    request.fields['meta[address_1]'] = (postData['meta'] as Map)['address_1'];
    request.fields['meta[address_2]'] = (postData['meta'] as Map)['address_2'];
    request.fields['meta[address_3]'] = (postData['meta'] as Map)['address_3'];

    // ✅ Correct way: Add multiple order-categories[] fields
    if (_selectedCategories.isNotEmpty) {
      for (var i = 0; i < _selectedCategories.length; i++) {
          request.fields['order-categories[$i]'] = _selectedCategories[i];
        }
    }

    // if (_selectedImage != null) {
    //   var stream = http.ByteStream(DelegatingStream.typed(_selectedImage!.openRead()));
    //   var length = await _selectedImage!.length();
    //   var multipartFile = http.MultipartFile(
    //     'order_gallery_',
    //     stream,
    //     length,
    //     filename: path.basename(_selectedImage!.path),
    //   );
    //   request.files.add(multipartFile);
    // }

    print("Request Headers: ${request.headers}");
    print("Request Fields: ${request.fields}");

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order submitted and published successfully!')),
      );
      _formKey.currentState!.reset();
      setState(() {
        _selectedCategories.clear();
        _selectedImage = null;
      });
    } else {
      final data = jsonDecode(response.body);
      _showError(data['message'] ?? 'Submission failed. Status Code: ${response.statusCode}');
    }
  } catch (e) {
    _showError('Error: $e');
  } finally {
    if (!mounted) return;
    setState(() => _isSubmitting = false);
  }
}

  @override
  void dispose() {
    _titleController.dispose();
    _streetController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildTextField(_titleController, 'Order Title *', true),
                const SizedBox(height: 20),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator(); // Show loading indicator
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}'); // Show error
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('No categories found'); //no data
                    } else {
                      // Build the MultiSelectDialogField with fetched categories
                      final categories = snapshot.data!;
                      return MultiSelectDialogField(
                        items: categories
                            .map((category) => MultiSelectItem(
                                category['id'].toString(), category['name']))
                            .toList(),
                        title: const Text("Categories"),
                        selectedColor: Theme.of(context).primaryColor,
                        cancelText: const Text("Cancel"),
                        confirmText: const Text("OK"),
                        onConfirm: (values) {
                          setState(() => _selectedCategories = values.cast<String>());
                        },
                        chipDisplay: MultiSelectChipDisplay.none(),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please select at least one category'
                            : null,
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (_selectedCategories.isNotEmpty) _buildSelectedChips(),
                const SizedBox(height: 20),
                _buildImagePicker(),
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Image.file(_selectedImage!, height: 100),
                  ),
                const SizedBox(height: 20),
                _buildTextField(_streetController, 'Street & House Number', true),
                const SizedBox(height: 20),
                _buildTextField(_postalCodeController, 'Postal Code', true),
                const SizedBox(height: 20),
                _buildTextField(_cityController, 'City', true),
                const SizedBox(height: 20),
                _buildTextField(_descriptionController, 'Order Description *', true, maxLines: 5),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Order'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, bool required,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          required && (value == null || value.trim().isEmpty) ? 'Required field' : null,
    );
  }

  Widget _buildSelectedChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedCategories.map((categoryId) {
        // Find the category name based on the ID.
        final categoryName = _categoriesFuture.then((categoryList) =>
            categoryList.firstWhere((category) => category['id'].toString() == categoryId)['name'] as String); // Add 'as String' here

        return FutureBuilder<String>(
            future: categoryName,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Chip(label: Text('Loading...'));
              } else if (snapshot.hasError) {
                return Chip(label: Text('Error'));
              } else {
                return Chip(
                  label: Text(snapshot.data ?? "NA"),
                  onDeleted: () {
                    setState(() => _selectedCategories.remove(categoryId));
                  },
                );
              }
            });
      }).toList(),
    );
  }

  Widget _buildImagePicker() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: _pickImage,
          child: const Text('Choose Image'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _selectedImage == null
                ? 'No file chosen'
                : path.basename(_selectedImage!.path),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

