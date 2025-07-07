

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io'; // Import for SocketException

// Screen where users select their favorite AI-generated image
class ImageSelectionScreen extends StatefulWidget {
  final String publicInputUrl; // URL of the image to process
  final String userId; // Unique identifier for the current user

  const ImageSelectionScreen({
    Key? key,
    required this.publicInputUrl,
    required this.userId
  }) : super(key: key);

  @override
  _ImageSelectionScreenState createState() => _ImageSelectionScreenState();
}

class _ImageSelectionScreenState extends State<ImageSelectionScreen> {
  int _selectedIndex = -1; // Tracks which image is currently selected (-1 means none)
  bool _isUploading = false; // Flag for when we're uploading to server
  bool _isGeneratingImages = false; // True when generating AI images
  List<Map<String, dynamic>> _generatedImages = []; // List to store generated images

  // Get our base API URL from environment variables
  final String _baseUrl = dotenv.env['BASE_URL']!;

  @override
  void initState() {
    super.initState();
    // Start generating images automatically when the screen initializes
    _generateImages();
  }

  // Calls the API to generate AI images based on prompts
  Future<void> _generateImages() async {
    if (_isGeneratingImages) return; // Prevent multiple calls

    setState(() {
      _isGeneratingImages = true; // Show loading state
      _generatedImages = []; // Clear previous images
      _selectedIndex = -1; // Reset selection
    });

    try {
      // Define prompts for image generation
      List<String> imagePrompts = [
        "convert given image to a man playing archery, in a front shot He is dressed like robin hood in 1600 ad face should be visible and concentrating on the target",
        "convert given image to a man playing bowling in mid stride about to release the ball Face should be visible and happy",
        "convert given image to a man playing a cover drive in a test match Camera should be in front Face should have a look of determination"
      ];

      // Convert prompts list to comma-separated string
      String promptsString = imagePrompts.join(',');

      // Prepare request body
      Map<String, String> body = {
        'prompts': promptsString,
        'image_url': widget.publicInputUrl,
      };

      // Make API call to generate images
      final response = await http.post(
        Uri.parse('$_baseUrl/ai/generate-multiple-images'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (!mounted) return; // Check if widget is still in tree

      setState(() {
        _isGeneratingImages = false; // Hide loading state
      });

      if (response.statusCode == 200) {
        // Success case - parse response
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('generated_images') &&
            responseData['generated_images'] is List) {
          setState(() {
            _generatedImages = List<Map<String, dynamic>>.from(responseData['generated_images']);
            if (_generatedImages.isNotEmpty) {
              _selectedIndex = 0; // Select the first image by default
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Images generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Handle malformed response
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API response missing "generated_images" or malformed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Handle API error response
        String errorMessage = 'Failed to generate images. Status: ${response.statusCode}';
        try {
          // Try to get detailed error message
          Map<String, dynamic> errorData = json.decode(response.body);
          if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          }
        } catch (_) {
          // If we can't parse error details, use default message
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating images: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on SocketException catch (e) {
      // Handle network errors
      if (!mounted) return;
      setState(() {
        _isGeneratingImages = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error during image generation: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
      print('Network error during image generation: $e');
    } catch (e) {
      // Handle all other errors
      if (!mounted) return;
      setState(() {
        _isGeneratingImages = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred during image generation: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('General error during image generation: $e');
    }
  }

  // Helper to extract file extension from image URL
  String _getImageExtension(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      if (lastSegment.contains('.')) {
        return lastSegment.split('.').last;
      }
    }
    return 'jpeg'; // Default extension if we can't determine
  }

  // Convert file extension to proper content type for upload
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
        return 'application/octet-stream'; // Fallback content type
    }
  }

  // Uploads the currently selected image to our server
  Future<void> _uploadSelectedImage() async {
    // Don't proceed if no image is selected or available
    if (_selectedIndex == -1 || _generatedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image selected or available!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true; // Show loading state
    });

    // Get info about the selected image
    final selectedImageInfo = _generatedImages[_selectedIndex];
    final String? selectedImageUrl = selectedImageInfo['image_url'];

    // Safety check for null image URL
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
      // First download the image from its URL
      final http.Response response = await http.get(Uri.parse(selectedImageUrl));

      // Check if download succeeded
      if (response.statusCode != 200) {
        throw Exception('Failed to download image from URL: ${response.statusCode}');
      }

      // Get the raw image bytes
      final bytes = response.bodyBytes;

      // Convert to base64 for our API
      final String base64Image = base64Encode(bytes);

      // Determine file type info
      final String fileExtension = _getImageExtension(selectedImageUrl);
      final String contentType = _getContentType(fileExtension);

      // Prepare the data we'll send to our server
      final Map<String, dynamic> requestBody = {
        "user_id": widget.userId, // Include user ID for reference
        "file_content": base64Image, // The actual image data
        "file_extension": ".$fileExtension", // Like ".jpg"
        "content_type": contentType, // Like "image/jpeg"
      };

    String imageTypeParam = 'output';
      Uri url = Uri.parse('$_baseUrl/upload/image?image_type=$imageTypeParam');
      // Send the upload request to our API
      final uploadResponse = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Check if widget is still mounted before updating state
      if (!mounted) return;

      setState(() {
        _isUploading = false; // Hide loading state
      });

      // Handle the API response
      if (uploadResponse.statusCode == 200) {
        // Success case - show confirmation
        final Map<String, dynamic> responseData = json.decode(uploadResponse.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Could navigate to next screen here if needed
      } else {
        // Handle API errors
        String errorMessage = 'Failed to upload image. Status: ${uploadResponse.statusCode}';
        try {
          // Try to get detailed error message
          Map<String, dynamic> errorData = json.decode(uploadResponse.body);
          if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'].toString();
          }
        } catch (_) {
          // If we can't parse the error details, fall back to generic message
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle any unexpected errors during the process
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
          // Screen title
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
            child: _isGeneratingImages
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue),
                  SizedBox(height: 20),
                  Text(
                    'Generating AI Images...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            )
                : _generatedImages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No images generated.',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _generateImages, // Allow retrying generation
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GridView.count(
                crossAxisCount: 2, // Two images per row
                crossAxisSpacing: 20, // Space between columns
                mainAxisSpacing: 20, // Space between rows
                childAspectRatio: 1, // Square items
                children: List.generate(_generatedImages.length, (index) {
                  // Get info about this particular image
                  final imageInfo = _generatedImages[index];
                  final String? imageUrl = imageInfo['image_url'];
                  final String prompt = imageInfo['prompt'];
                  final String? error = imageInfo['error'];

                  // Show error state if image failed to generate
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

                  // Build a selectable image card
                  return GestureDetector(
                    onTap: () {
                      // Update selection when tapped
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedIndex == index
                              ? Colors.red // Highlight selected
                              : Colors.grey[800]!, // Normal border
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
                            // The actual image with loading/error states
                            Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.blue,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, color: Colors.red, size: 50),
                            ),

                            // Selection indicator (checkmark)
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

          // Finalize button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // Disable while uploading or generating
                onPressed: (_isUploading || _isGeneratingImages || _generatedImages.isEmpty)
                    ? null
                    : _uploadSelectedImage,
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