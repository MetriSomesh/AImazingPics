
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:frontend/screens/otp_verification.dart';

// Screen where users enter their profile information after taking a selfie
class UserInfoScreen extends StatefulWidget {
  final String imagePath; // Path to the captured selfie image

  const UserInfoScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _UserInfoScreenState createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  // Form and field controllers
  final _formKey = GlobalKey<FormState>(); // Key for form validation
  final TextEditingController _nameController = TextEditingController(); // For full name
  final TextEditingController _mobileController = TextEditingController(); // For mobile number
  final TextEditingController _displayNameController = TextEditingController(); // For optional display name

  var _uploadImageResponse; // Stores the response from image upload
  bool _isLoading = false; // Shows loading state during OTP request
  bool _isUploading = false; // Shows loading state during image upload

  // Get our base API URL from environment variables
final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://65.2.70.73:8000';

  @override
  void dispose() {
    // Clean up controllers when screen is disposed
    _nameController.dispose();
    _mobileController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  // Uploads the captured image to our server
  Future<void> _uploadImage(String userId) async {
    if (_isUploading) return; // Prevent multiple uploads

    setState(() {
      _isUploading = true; // Show loading state
    });

    try {
      // Prepare the image file
      XFile imageFile = XFile(widget.imagePath);
      
      // Read image as bytes
      List<int> imageBytes = await imageFile.readAsBytes();
      
      // Convert to base64 for API
      String base64Image = base64Encode(imageBytes);
      
      // Determine file type information
      String contentType = imageFile.mimeType ?? _getMimeType(imageFile.path);
      String fileExtension = imageFile.name.split('.').last;

      // Prepare the request body
      Map<String, dynamic> requestBody = {
        "user_id": userId,
        "file_content": base64Image,
        "content_type": contentType,
        "file_extension": fileExtension,
        "image_type":'input'
      };

      // Determine the correct API endpoint
      // String imageTypeParam = 'input';
      Uri url = Uri.parse('$baseUrl/upload/image');

      // Make the upload request
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      // Check if widget is still mounted before updating state
      if (!mounted) return;

      setState(() {
        _isUploading = false; // Hide loading state
      });

      // Handle the response
      if (response.statusCode == 200) {
        // Success case - store response and show confirmation
        _uploadImageResponse = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: Colors.green),
        );
      } else {
        // Handle API errors
        String errorMessage = 'Failed to upload image.';
        try {
          // Try to get detailed error message
          Map<String, dynamic> errorData = json.decode(response.body);
          if (errorData.containsKey('detail')) {
            if (errorData['detail'] is String) {
              errorMessage = errorData['detail'];
            } else if (errorData['detail'] is List && errorData['detail'].isNotEmpty && errorData['detail'][0].containsKey('msg')) {
              errorMessage = errorData['detail'][0]['msg'];
            }
          }
        } catch (_) {
          // If we can't parse the error details, use default message
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMessage'), backgroundColor: Colors.red),
        );
        throw Exception('Image upload failed: $errorMessage'); // Throw an error to stop further execution
      }
    } on SocketException catch (e) {
      // Handle network errors
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: ${e.message}'), backgroundColor: Colors.red),
      );
      throw Exception('Network error during image upload: ${e.message}'); // Throw an error
    } catch (e) {
      // Handle all other errors
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred during image upload: $e'), backgroundColor: Colors.red),
      );
      throw Exception('An unexpected error occurred during image upload: $e'); // Throw an error
    }
  }

  // Helper to determine MIME type from file extension
  String _getMimeType(String path) {
    String ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream'; // Default for unknown types
    }
  }

  // Sends OTP to the user's mobile number
  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) {
      return; // Stop if form is not valid
    }

    setState(() {
      _isLoading = true; // Show loading state
    });

    try {
      // Step 1: Create the user account
      final userCreateResponse = await http.post(
        Uri.parse('$baseUrl/users/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({ 
          'name': _nameController.text,
          'mobile': _mobileController.text,
          'diaplay_name': _displayNameController.text,
        }),
      );

      if (userCreateResponse.statusCode == 200) {
        final Map<String, dynamic> userData = json.decode(userCreateResponse.body);
        final String userId = userData['user_id'];
        final String phoneNumber = userData['phone_number'];

        // Step 2: Upload the selfie image using the obtained user_id
        await _uploadImage(userId); // This will throw an exception if upload fails

        // Step 3: Send OTP to the user's phone
        final otpResponse = await http.post(
          Uri.parse('$baseUrl/auth/send-otp'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({ 
            "phone": phoneNumber
          }),
        );

        if (otpResponse.statusCode == 200) {
          // OTP sent successfully - navigate to verification screen
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationScreen(
                  mobileNumber: _mobileController.text, 
                  publicInputUrl: _uploadImageResponse['public_url'], 
                  userId: userId,
                ),
              ),
            );
          }
        } else {
          // OTP sending failed
          String errorMessage = 'Failed to send OTP.';
          try {
            Map<String, dynamic> errorData = json.decode(otpResponse.body);
            if (errorData.containsKey('detail')) {
              errorMessage = errorData['detail'].toString();
            }
          } catch (_) {
            // Fallback
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error sending OTP: $errorMessage'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // User creation failed
        String errorMessage = 'Failed to create user.';
        try {
          Map<String, dynamic> errorData = json.decode(userCreateResponse.body);
          if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'].toString();
          }
        } catch (_) {
          // Fallback
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating user: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on Exception catch (e) {
      // Catch any exceptions thrown by _uploadImage or other http calls
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operation failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always hide loading state when done
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark theme
      appBar: AppBar(
        title: const Text('AImazing'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), 
          onPressed: () => Navigator.pop(context), // Back navigation
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Screen title
                const Padding( 
                  padding: EdgeInsets.only(bottom: 20.0),
                  child: Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // User's selfie preview
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, color: Colors.white, size: 60), // Fallback if image fails to load
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                
                // Full name field
                const Text( 
                  'Full Name',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8), 
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.person, color: Colors.blue), 
                    hintText: 'Enter your full name',
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20), 

                // Mobile number field
                const Text( 
                  'Mobile Number',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8), 
                TextFormField(
                  controller: _mobileController,
                  style: const TextStyle(color: Colors.white), 
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // Only numbers
                    LengthLimitingTextInputFormatter(10), // Exactly 10 digits
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.phone, color: Colors.blue), 
                    hintText: 'Enter 10-digit mobile number',
                    hintStyle: const TextStyle(color: Colors.grey), 
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter mobile number';
                    }
                    if (value.length != 10) {
                      return 'Enter valid 10-digit number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20), 

                // Optional display name field
                const Text( 
                  'Display Name (Optional)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _displayNameController,
                  style: const TextStyle(color: Colors.white), 
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.badge, color: Colors.blue), 
                    hintText: 'Enter a display name',
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 40), 

                // Get OTP button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendOTP, // Disable if loading
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Get OTP',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}