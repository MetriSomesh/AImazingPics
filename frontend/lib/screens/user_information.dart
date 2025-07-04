import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:frontend/screens/otp_verification.dart';

class UserInfoScreen extends StatefulWidget {
  final String imagePath;

  const UserInfoScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _UserInfoScreenState createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  var _uploadImageResponse;

  bool _isLoading = false;
   bool _isUploading = false;
  //bool _otpSent = false;

  final String _baseUrl = dotenv.env['BASE_URL']!;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

    Future<void> _uploadImage(String userId, bool isInputImage) async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
     
      XFile imageFile = XFile(widget.imagePath);

      
      List<int> imageBytes = await imageFile.readAsBytes();
     
      String base64Image = base64Encode(imageBytes);

      
      String contentType = imageFile.mimeType ?? _getMimeType(imageFile.path);
      String fileExtension = imageFile.name.split('.').last;

     
      Map<String, dynamic> requestBody = {
        "user_id": userId,
        "file_content": base64Image,
        "content_type": contentType,
        "file_extension": fileExtension,
      };

      String endpoint = isInputImage ? '/upload/input_image' : '/upload/output_image';
      Uri url = Uri.parse('$_baseUrl$endpoint');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200) {
        
        _uploadImageResponse = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: Colors.green),
        );

      } else {
      
        String errorMessage = 'Failed to upload image.';
        try {
          Map<String, dynamic> errorData = json.decode(response.body);
          if (errorData.containsKey('detail')) {
            if (errorData['detail'] is String) {
              errorMessage = errorData['detail'];
            } else if (errorData['detail'] is List && errorData['detail'].isNotEmpty && errorData['detail'][0].containsKey('msg')) {
              errorMessage = errorData['detail'][0]['msg'];
            }
          }
        } catch (_) {
        
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMessage'), backgroundColor: Colors.red),
        );
      }
    } on SocketException catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: ${e.message}'), backgroundColor: Colors.red),
      );
      print('Network error during image upload: $e');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e'), backgroundColor: Colors.red),
      );
      
    }
  }

  
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
        return 'application/octet-stream';
    }
  }


 Future<void> _sendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/users/create'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({   
            'name': _nameController.text,
            'mobile': _mobileController.text,
            'diaplay_name': _displayNameController.text,
          
          }),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
    
          final user_id = responseData['user_id'];
         
          final phone_number = responseData['phone_number'];

           await _uploadImage(user_id, true);

        try {
           final otpResponse = await http.post(
           Uri.parse('$_baseUrl/auth/send-otp'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({   
           "phone":phone_number
          }),
           );

           if(otpResponse.statusCode==200){
          
             Navigator.push(context,
                      
                      MaterialPageRoute(builder: (context)=> OTPVerificationScreen(mobileNumber: _mobileController.text, publicInputUrl: _uploadImageResponse['public_url'], userId: user_id,))
                      );
           }else{
              ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Response is ${otpResponse.body}'),
              backgroundColor: Colors.red,
            ),
          );
           }
        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error is ${e}'),
              backgroundColor: Colors.red,
            ),
          );
        }

        } else {
         
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send OTP: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
       
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), 
          onPressed: () => Navigator.pop(context),
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
                            const Icon(Icons.person, color: Colors.white, size: 60), 
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
               
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
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
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

               
                Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      _isLoading? null:_sendOTP();
                      
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
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