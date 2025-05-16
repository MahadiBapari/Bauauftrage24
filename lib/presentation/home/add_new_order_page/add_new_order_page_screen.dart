import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:multi_select_flutter/multi_select_flutter.dart'; // Import the multi-select package
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:async/async.dart';
import 'dart:convert';

class AddNewOrderPageScreen extends StatefulWidget {
  const AddNewOrderPageScreen({super.key});

  @override
  _AddNewOrderPageScreenState createState() => _AddNewOrderPageScreenState();
}

class _AddNewOrderPageScreenState extends State<AddNewOrderPageScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _selectedCategories = []; // To store selected categories
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // List of categories (should ideally come from your API)
    final List<Map<String, dynamic>> _categories = [
    {"id": "bodenleger", "name": "Bodenleger"},
    {"id": "dachdecker", "name": "Dachdecker / Zimmermann"},
    {"id": "elektriker", "name": "Elektriker"},
    {"id": "flachdach", "name": "Flachdach"},
    {"id": "gartner", "name": "Gärtner"},
    {"id": "gipser", "name": "Gipser"},
    {"id": "glaser", "name": "Glaser"},
    {"id": "isoleur", "name": "Isoleur"},
    {"id": "kaminbauer", "name": "Kaminbauer"},
    {"id": "luftungsbauer", "name": "Lüftungsbauer"},
    {"id": "maler", "name": "Maler"},
    {"id": "maurer", "name": "Maurer"},
    {"id": "reinigung", "name": "Reinigung"},
    {"id": "sanitar", "name": "Sanitär / Heizung"},
    {"id": "spengler", "name": "Spengler"},
    {"id": "umzug", "name": "Umzug / Transport"},
  ];

  // Function to handle image picking
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

    void _showError(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Function to handle form submission (connect to your API)
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Prepare data for API submission
      var postData = {
        'title': _titleController.text,
        'categories': _selectedCategories.join(','), // Convert list to string
        'street': _streetController.text,
        'postal_code': _postalCodeController.text,
        'city': _cityController.text,
        'description': _descriptionController.text,
        //'image': _selectedImage, // we'll handle this differently
      };

      // Construct the URL (replace with your actual API endpoint)
      var url = Uri.parse('https://your-api-endpoint.com/add-order'); // Replace this

      try {
        //use the postJson function
        var response = await postJson(url, postData, _selectedImage);

        if (response.statusCode == 200) {
          // **Read the response body from the StreamedResponse:**
          var responseBody = await response.stream.bytesToString();
          var responseData = json.decode(responseBody); // Parse the JSON

          if (responseData['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order submitted successfully!')),
            );
            // Clear the form
            _titleController.clear();
            _streetController.clear();
            _postalCodeController.clear();
            _cityController.clear();
            _descriptionController.clear();
            setState(() {
              _selectedCategories.clear();
              _selectedImage = null;
            });
          } else {
            _showError(responseData['message'] ?? 'Failed to update profile.');
          }
        } else {
          _showError('Failed to update profile. Status code: ${response.statusCode}');
        }
      } catch (e) {
        _showError('Error updating profile: $e');
      }
    }
  }


  //helper function to handle the post request with image.
  Future<http.StreamedResponse> postJson(Uri url, Map<String, String> fields, File? imageFile) async {
  var request = http.MultipartRequest('POST', url);
  request.fields.addAll(fields);
  if (imageFile != null) {
    var stream = http.ByteStream(DelegatingStream.typed(imageFile.openRead()));
    var length = await imageFile.length();
    var multipartFile = http.MultipartFile(
      'image', // the name of the field  for the file in your API
      stream,
      length,
      filename: path.basename(imageFile.path),
    );
    request.files.add(multipartFile);
  }
  return await request.send();
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

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Auftragstitel
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Auftragstitel *'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the title of the order';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Kategorien (using multi-select)
                 MultiSelectDialogField(
                  items: _categories.map((category) => MultiSelectItem(category['id'], category['name'])).toList(),
                  title: const Text("Kategorien"),
                  selectedColor: Theme.of(context).primaryColor,
                  cancelText: const Text("Cancel"),
                  confirmText: const Text("OK"),
                  onConfirm: (values) {
                    _selectedCategories.clear(); // Clear first to avoid duplicates
                    _selectedCategories.addAll(values.cast<String>());
                  },
                  chipDisplay: MultiSelectChipDisplay.none(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select at least one category';
                    }
                    return null;
                  },
                ),
                if (_selectedCategories.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedCategories.map((category) {
                      final catName = _categories.firstWhere((e) => e['id'] == category)['name'];
                      return Chip(
                        label: Text(catName),
                        onDeleted: () {
                          setState(() {
                            _selectedCategories.remove(category);
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 20),

                // Image Upload
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('Choose Files'),
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
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 10),
                  Image.file(
                    _selectedImage!,
                    height: 100,
                  ),
                ],
                const SizedBox(height: 20),

                // Strasse & Hausnummer
                TextFormField(
                  controller: _streetController,
                  decoration:
                      const InputDecoration(labelText: 'Strasse & Hausnummer'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter street and house number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Postleitzahl
                TextFormField(
                  controller: _postalCodeController,
                  decoration: const InputDecoration(labelText: 'Postleitzahl'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter postal code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Stadt
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'Stadt'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter city';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Auftragsbeschreibung
                TextFormField(
                  controller: _descriptionController,
                  decoration:
                      const InputDecoration(labelText: 'Auftragsbeschreibung *'),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the order description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text('Submit Order'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
