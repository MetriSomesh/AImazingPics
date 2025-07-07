
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/screens/output_screen.dart';

// Screen for verifying OTP sent to user's mobile number
class OTPVerificationScreen extends StatefulWidget {
  final String mobileNumber; // User's phone number
  final String publicInputUrl; // URL of the image to process
  final String userId; // Unique ID for the user

  const OTPVerificationScreen({
    Key? key,
    required this.mobileNumber,
    required this.publicInputUrl,
    required this.userId
  }) : super(key: key);

  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  // Base URL from environment variables
  final String _baseUrl = dotenv.env['BASE_URL']!;

  // Controller and focus node for OTP input field
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  // State variables
  bool _isVerifying = false; // True when verifying OTP
  bool _isVerified = false; // True when OTP is successfully verified
  int _resendTimer = 120; // Countdown timer for resend OTP (2 minutes)
  Timer? _timer; // Timer object for the countdown

  @override
  void initState() {
    super.initState();
    _startResendTimer(); // Start the countdown timer immediately

    // Set focus to OTP field after the screen builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_otpFocusNode);
    });
  }

  @override
  void dispose() {
    // Clean up resources when screen is disposed
    _timer?.cancel(); // Stop the timer
    _otpController.dispose(); // Dispose the controller
    _otpFocusNode.dispose(); // Dispose the focus node
    super.dispose();
  }

  // Starts a 2-minute countdown timer for OTP resend
  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        if (mounted) {
          setState(() => _resendTimer--); // Decrement timer each second
        }
      } else {
        timer.cancel(); // Stop timer when it reaches 0
      }
    });
  }

  // Verifies the OTP entered by user
  Future<void> _verifyOTP() async {
    final otp = _otpController.text;

    // Basic validation - must be 6 digits
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
      setState(() => _isVerifying = true); // Show verifying state
    }

    try {
      // Call OTP verification API
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "phone": widget.mobileNumber,
          "otp": int.parse(_otpController.text)
        }),
      );

      if (mounted) {
        setState(() => _isVerifying = false); // Hide verifying state
      }

      if (response.statusCode == 200) {
        // OTP verification successful
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP verified successfully! Redirecting to image generation...'),
            backgroundColor: Colors.green,
          ),
        );

        if (mounted) {
          setState(() {
            _isVerified = true; // Update verified state
          });
        }

        // Navigate to ImageSelectionScreen after successful OTP verification
        // Pass publicInputUrl and userId, ImageSelectionScreen will call the generate API
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageSelectionScreen(
              publicInputUrl: widget.publicInputUrl,
              userId: widget.userId,
            ),
          ),
        );
      } else {
        // OTP verification failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP verification failed: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle verification errors
      if (mounted) {
        setState(() => _isVerifying = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error occurred during OTP verification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Resends OTP to user's mobile number
  void _resendOTP() {
    if (mounted) {
      setState(() {
        _resendTimer = 120; // Reset timer to 2 minutes
        _otpController.clear(); // Clear OTP field
        _isVerified = false; // Reset verified state
      });
    }

    _startResendTimer(); // Restart countdown
    FocusScope.of(context).requestFocus(_otpFocusNode); // Refocus OTP field

    // Show resend confirmation
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
                      // Screen title
                      const Text(
                        'Verify OTP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Instruction text
                      const Text(
                        'Enter the 6-digit code sent to',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Display user's mobile number
                      Text(
                        '+91 ${widget.mobileNumber}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 100),

                      // OTP input field
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
                              FilteringTextInputFormatter.digitsOnly, // Only allow numbers
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Resend OTP section
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
                          // Show countdown if timer is active
                            Text(
                              'Resend in $_resendTimer',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                          // Show resend button when timer expires
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

              // Verify OTP button
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (_isVerifying || _isVerified)
                        ? null // Disable if already processing or verified
                        : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isVerified ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isVerifying
                        ? const Row( // Show loading indicator when processing
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          'Verifying OTP...',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                        : Text( // Show appropriate button text
                      _isVerified ? 'OTP Verified' : 'Verify OTP',
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