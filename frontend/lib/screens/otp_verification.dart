import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/screens/output_screen.dart';



class OTPVerificationScreen extends StatefulWidget {
  final String mobileNumber;
  final String publicInputUrl;
  final String userId;

  const OTPVerificationScreen({Key? key, required this.mobileNumber, required this.publicInputUrl, required this.userId})
      : super(key: key);

  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final String _baseUrl = dotenv.env['BASE_URL']!;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isVerifying = false;
  bool _isVerified = false;
  bool _isGeneratingImages = false;
  int _resendTimer = 120;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_otpFocusNode);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        if (mounted) {
          setState(() => _resendTimer--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _generateImages(String imageUrl, List<String> prompts) async {
    if (_isGeneratingImages) return;

    setState(() {
      _isGeneratingImages = true;
    });

    try {
     
      String promptsString = prompts.join(',');

      
      Map<String, String> body = {
        'prompts': promptsString,
        'image_url': imageUrl,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/ai/generate-multiple-images'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded', 
        },
        body: body, 
      );

      if (!mounted) return;

      setState(() {
        _isGeneratingImages = false;
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Images generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        if (responseData.containsKey('generated_images') && responseData['generated_images'] is List) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageSelectionScreen(
               
                generatedImages: List<Map<String, dynamic>>.from(responseData['generated_images']),
                userId: widget.userId,
                
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API response missing "generated_images" or malformed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        String errorMessage = 'Failed to generate images. Status: ${response.statusCode}';
        try {
          Map<String, dynamic> errorData = json.decode(response.body);
          if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          }
        } catch (_) {
        
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating images: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on SocketException catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingImages = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error during image generation: ${e.message}'), backgroundColor: Colors.red),
      );
      print('Network error during image generation: $e');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingImages = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred during image generation: $e'), backgroundColor: Colors.red),
      );
      print('General error during image generation: $e');
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text;

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 6-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isVerifying = true);
    }


    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "phone": widget.mobileNumber,
          "otp": int.parse(_otpController.text)
        }),
      );
      if (mounted) {
        setState(() => _isVerifying = false);
      }
      if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP verified successfully please wait'),
            backgroundColor: Colors.green,
          ),
        );
        if (mounted) {
          setState(() {
            _isVerified = true;
          });
        }
        List<String> imagePrompts = [
          "convert given image to a man playing archery, in a front shot He is dressed like robin hood in 1600 ad face should be visible and concentrating on the target",
          "convert given image to a man playing bowling in mid stride about to release the ball Face should be visible and happy",
          "convert given image to a man playing a cover drive in a test match Camera should be in front Face should have a look of determination"
        ];
        _generateImages(widget.publicInputUrl, imagePrompts);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Response is ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error occurred ${e}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resendOTP() {
    if (mounted) {
      setState(() {
        _resendTimer = 120;
        _otpController.clear();
        _isVerified = false;
      });
    }

    _startResendTimer();
    FocusScope.of(context).requestFocus(_otpFocusNode);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New OTP sent to ${widget.mobileNumber}'),
        backgroundColor: Colors.blue,
      ),
    );
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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text(
                        'Verify OTP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 15),


                      const Text(
                        'Enter the 6-digit code sent to',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 8),


                      Text(
                        '+91 ${widget.mobileNumber}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 100),


                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: TextField(
                            controller: _otpController,
                            focusNode: _otpFocusNode,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8.0,
                            ),
                            maxLength: 6,
                            decoration: InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Colors.blue,
                                  width: 3,
                                ),
                              ),
                              hintText: '• • • • • •',
                              hintStyle: TextStyle(
                                color: Colors.grey[600],
                                letterSpacing: 8.0,
                                fontSize: 32,
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],


                          ),
                        ),
                      ),

                      const SizedBox(height: 30),


                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Didn\'t receive the code? ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          if (_resendTimer > 0)
                            Text(
                              'Resend in $_resendTimer',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            TextButton(
                              onPressed: _resendTimer == 0 ? _resendOTP : null,
                              child: const Text(
                                'Resend OTP',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),


              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (_isVerifying || _isGeneratingImages || _isVerified) ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isVerified ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28), // More rounded corners
                      ),
                    ),
                    child: (_isVerifying || _isGeneratingImages)
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(width: 10),
                              Text(
                                'Please wait...',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _isVerified ? 'Verified Successfully' : 'Verify OTP',
                            style: const TextStyle(
                              fontSize: 19,
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
    );
  }
}