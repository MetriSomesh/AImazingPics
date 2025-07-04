import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

class ImageSelectionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> generatedImages;
  
  final String userId; 

  const ImageSelectionScreen({Key? key, required this.generatedImages, required this.userId}) : super(key: key);

  @override
  _ImageSelectionScreenState createState() => _ImageSelectionScreenState();
}

class _ImageSelectionScreenState extends State<ImageSelectionScreen> {
  int _selectedIndex = 0;
  bool _isUploading = false; 

  final String _baseUrl = dotenv.env['BASE_URL']!;


  @override
  void initState() {
    super.initState();

    if (widget.generatedImages.isEmpty) {
      _selectedIndex = -1;
    } else {
      _selectedIndex = 0;
    }
  }

  String _getImageExtension(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      if (lastSegment.contains('.')) {
        return lastSegment.split('.').last;
      }
    }
    return 'jpeg'; 
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream'; 
    }
  }

  Future<void> _uploadSelectedImage() async {
    if (_selectedIndex == -1 || widget.generatedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image selected or available!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final selectedImageInfo = widget.generatedImages[_selectedIndex];
    final String? selectedImageUrl = selectedImageInfo['image_url'];
    final String selectedPrompt = selectedImageInfo['prompt'];

    if (selectedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected image URL is null, cannot upload.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isUploading = false;
      });
      return;
    }

    try {
     
      final http.Response response = await http.get(Uri.parse(selectedImageUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download image from URL: ${response.statusCode}');
      }

      final bytes = response.bodyBytes;

  
      final String base64Image = base64Encode(bytes);

      
      final String fileExtension = _getImageExtension(selectedImageUrl);
      final String contentType = _getContentType(fileExtension);

     
      final Map<String, dynamic> requestBody = {
        "user_id": widget.userId, 
        "file_content": base64Image,
        "file_extension": ".$fileExtension", 
        "content_type": contentType,
      };

      
      final uploadResponse = await http.post(
        Uri.parse('$_baseUrl/upload/output_image'),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      if (uploadResponse.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(uploadResponse.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image "${selectedPrompt}" uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
       // print('Upload successful: ${responseData['public_url']}');
       
      } else {
        String errorMessage = 'Failed to upload image. Status: ${uploadResponse.statusCode}';
        try {
          Map<String, dynamic> errorData = json.decode(uploadResponse.body);
          if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'].toString(); 
          }
        } catch (_) {
         
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
        print('Upload failed: $errorMessage');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred during upload: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('General upload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AImazing'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'Finalize selected one',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1,
                children: List.generate(widget.generatedImages.length, (index) {
                  final imageInfo = widget.generatedImages[index];
                  final String? imageUrl = imageInfo['image_url'];
                  final String prompt = imageInfo['prompt'];
                  final String? error = imageInfo['error'];

                  if (imageUrl == null || error != null) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[800],
                        border: Border.all(
                          color: _selectedIndex == index ? Colors.red : Colors.grey[800]!,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error ?? 'Image not available',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              prompt,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedIndex == index
                              ? Colors.red 
                              : Colors.grey[800]!, 
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                          
                            Image.network(
                              imageUrl,
                              fit: BoxFit.cover, 
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.blue,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, color: Colors.red, size: 50),
                            ),

                          
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    prompt,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14, 
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                           
                            if (_selectedIndex == index)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 30),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
              
                onPressed: _isUploading ? null : _uploadSelectedImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Finalize selected one',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}