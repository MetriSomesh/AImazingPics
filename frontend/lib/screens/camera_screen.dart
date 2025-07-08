
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:frontend/screens/user_information.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:async'; // Import for Timer
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:permission_handler/permission_handler.dart';

// Main screen for capturing selfies with face detection
class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  bool _isHighQualityMode = false; // Track if we're in high quality mode

  // Face detection variables
  late FaceDetector _faceDetector;
  List<Face> _faces = [];
  bool _isFaceDetected = false;
  bool _isFaceInFrame = false;
  bool _isProcessing = false;

  // Capture timer variables
  Timer? _captureTimer;
  int _countdownSeconds = 2; // 2-second delay
  bool _captureTriggered = false; // Indicates if capture sequence has started

  // Frame processing optimization
  int _frameCounter = 0;
  int _frameSkip = 3; // Increased to reduce processing load
  DateTime _lastProcessed = DateTime.now();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeFaceDetector();
    _initializeCamera();
  }

  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableLandmarks: false,
        enableClassification: false,
        enableTracking: true,
        minFaceSize: 0.25,
      ),
    );
  }

  Future<void> _requestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.camera,
    Permission.photos, // For Android 13+
    Permission.storage, // For older Android versions
  ].request();

  if (statuses[Permission.camera]?.isGranted == false ||
      (statuses[Permission.photos]?.isGranted == false &&
       statuses[Permission.storage]?.isGranted == false)) {
    // Handle the case where permissions are not granted
    //print("Permissions not granted");
  }
}


  Future<void> _initializeCamera({ResolutionPreset resolution = ResolutionPreset.low}) async {
    try {
      _cameras = await availableCameras();

      CameraDescription frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      final newController = CameraController(
        frontCamera,
        resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg, // Use JPEG for better quality
      );

      await newController.initialize();

      if (mounted) {
        setState(() {
          _controller = newController;
          _isCameraInitialized = true;
        });

        // Ensure we only start streaming if a capture isn't already pending
        if (_capturedImage == null && !_captureTriggered) {
          _controller!.startImageStream(_processCameraImage);
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
      // Fallback to low resolution if medium fails
      if (resolution != ResolutionPreset.low) {
        await _initializeCamera(resolution: ResolutionPreset.low);
      }
    }
  }

  Future<void> _switchToHighQuality() async {
  if (_isHighQualityMode || _controller == null) return;

  try {
    // Store current streaming state
    final wasStreaming = _controller!.value.isStreamingImages;
    
    // Stop current stream if active
    if (wasStreaming) {
      await _controller!.stopImageStream();
    }

    // Dispose the old controller before creating a new one
    await _controller!.dispose();

    // Reinitialize with high resolution
    await _initializeCamera(resolution: ResolutionPreset.high);

    setState(() {
      _isHighQualityMode = true;
    });

    // Restart processing only if we were streaming before
    if (wasStreaming && _capturedImage == null && !_captureTriggered) {
      await _controller!.startImageStream(_processCameraImage);
    }
  } catch (e) {
    print("Failed to switch to high quality: $e");
    // Fallback to medium resolution if high fails
    await _initializeCamera(resolution: ResolutionPreset.low);
  }
}

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    // Only process if no capture is pending or completed, and not already processing a frame
    if (_isProcessing || _capturedImage != null || _captureTriggered) return;

    _frameCounter++;
    if (_frameCounter % _frameSkip != 0) return;

    final now = DateTime.now();
    // Throttle processing to once every 200ms
    if (now.difference(_lastProcessed).inMilliseconds < 200) return;

    _isProcessing = true;
    _lastProcessed = now;

    try {
      final inputImage = _convertCameraImage(cameraImage);
      if (inputImage != null) {
        final faces = await _faceDetector.processImage(inputImage);

        if (mounted) {
          setState(() {
            _faces = faces;
            _isFaceDetected = faces.isNotEmpty;

            // Update _isFaceInFrame state
            if (_isFaceDetected && _isHighQualityMode && !_captureTriggered) {
              // If face is in frame, in HQ mode, and capture hasn't been triggered yet
              _startCaptureTimer();
            } else if ( _captureTimer != null && _captureTimer!.isActive) {
              // If face moves out of frame while timer is active, cancel it
              _cancelCaptureTimer();
              _captureTriggered = false; // Reset trigger state
              _countdownSeconds = 2; // Reset countdown for next time
            } else if ( _isFaceDetected &&!_isHighQualityMode) {
              // If face is in frame but not yet in HQ mode, switch to HQ
              _switchToHighQuality();
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing camera image: $e');
      }
      if (_frameSkip < 6) _frameSkip++; // Increase frame skip more if needed
    } finally {
      _isProcessing = false;
    }
  }

  void _startCaptureTimer() {
    // If a timer is already active, don't start a new one
    if (_captureTimer != null && _captureTimer!.isActive) {
      return;
    }

    setState(() {
      _captureTriggered = true; // Indicate that capture sequence has started
      _countdownSeconds = 2; // Reset countdown for a fresh start
    });

    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          timer.cancel(); // Stop the countdown
          _capturePhotoAutomatically(); // Trigger the photo capture
        }
      });
    });
  }

  void _cancelCaptureTimer() {
    if (_captureTimer != null) {
      _captureTimer!.cancel();
      _captureTimer = null;
    }
    // Only reset these if we haven't already captured an image
    if (_capturedImage == null) {
      setState(() {
        _countdownSeconds = 2;
        _captureTriggered = false;
      });
    }
  }

  InputImage? _convertCameraImage(CameraImage cameraImage) {
    try {
      if (_cameras == null || _cameras!.isEmpty) return null;
      final camera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      final rotation = InputImageRotationValue.fromRawValue(
        camera.sensorOrientation,
      ) ?? InputImageRotation.rotation0deg;

      if (Platform.isAndroid) {
        return InputImage.fromBytes(
          bytes: _concatenatePlanes(cameraImage.planes),
          metadata: InputImageMetadata(
            size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: cameraImage.planes[0].bytesPerRow,
          ),
        );
      } else if (Platform.isIOS) {
         return InputImage.fromBytes(
          bytes: _concatenatePlanes(cameraImage.planes),
          metadata: InputImageMetadata(
            size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
            rotation: rotation, // Should be correct for iOS too
            format: InputImageFormat.bgra8888, // iOS uses BGRA8888 for most common image streams
            bytesPerRow: cameraImage.planes[0].bytesPerRow,
          ),
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error converting CameraImage: $e');
      }
      return null;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

 

  Future<void> _capturePhotoAutomatically() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // Stop the image stream to prevent further processing while capturing
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
    _cancelCaptureTimer(); // Ensure timer is cancelled if it's still running

    try {
      final XFile image = await _controller!.takePicture();

      if (mounted) {
        setState(() {
          _capturedImage = image;
          _captureTriggered = false; // Reset trigger after capture
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auto capture failed: $e');
      }
      // If auto capture fails, allow retrying and restart stream
      _captureTriggered = false;
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.startImageStream(_processCameraImage);
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _cancelCaptureTimer(); // Cancel any automatic capture in progress

    try {
      // First switch to high quality if not already
      if (!_isHighQualityMode) {
        await _switchToHighQuality();
        await Future.delayed(const Duration(milliseconds: 500)); // Let camera adjust
      }

      // Stop the image stream before manual capture to ensure clean capture
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      final XFile image = await _controller!.takePicture();
      if (mounted) {
        setState(() {
          _capturedImage = image;
          _captureTriggered = false; // Reset trigger state
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Manual capture failed: $e');
      }
      // Restart stream if manual capture fails, unless already captured
      if (_capturedImage == null && _controller != null && _controller!.value.isInitialized) {
        _controller!.startImageStream(_processCameraImage);
      }
    }
  }

  void _retakePhoto() async {
    _cancelCaptureTimer(); // Ensure any running timer is cancelled
    setState(() {
      _capturedImage = null;
      _faces = [];
      _isFaceDetected = false;
      _isFaceInFrame = false;
      _captureTriggered = false;
      _frameSkip = 3; // Reset frame skip
      _isHighQualityMode = false; // Go back to medium quality for detection
      _countdownSeconds = 2; // Reset countdown
    });

    // Switch back to medium quality for face detection and restart stream
    await _initializeCamera(resolution: ResolutionPreset.low);
  }

  @override
  void dispose() {
    _cancelCaptureTimer(); // Ensure timer is disposed
    _controller?.dispose();
    _faceDetector.close();
    _isProcessing = false;
    super.dispose();
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
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'Take a Selfie',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                _capturedImage != null
                    ? 'Photo captured successfully!'
                    : _captureTriggered
                        ? 'Please stay still... ($_countdownSeconds)' // Show countdown
                        : !_isHighQualityMode
                            ? 'Face detected! Switching to high quality...' // New text while switching to HQ
                            : _isFaceDetected
                                ? 'Face detected! Align for capture.' // Initial prompt when face detected and stable in frame
                                : 'Position your face within the outline',
                style: TextStyle(
                  color:  _capturedImage != null ? Colors.green : Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusIndicator('Face Detected', _isFaceDetected),
                const SizedBox(width: 20),
                _buildStatusIndicator('HQ Mode', _isHighQualityMode),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Expanded(
              child: Center(
                child: Container(
                  width: 280,
                  height: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Stack(
                      children: [
                        if (_capturedImage != null)
                          Image.file(
                            File(_capturedImage!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        else if (_isCameraInitialized)
                          SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: CameraPreview(_controller!),
                          )
                        else
                          Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        
                        if (_capturedImage == null)
                          CustomPaint(
                            painter: FaceOutlinePainter(
                              isFaceInFrame: _isFaceInFrame,
                            ),
                            child: Container(),
                          ),
                      ],
                    ),
                  ),
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
                  onPressed: _isCameraInitialized
                      ? (_capturedImage != null ? _retakePhoto : _capturePhoto)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    _capturedImage != null ? 'Retake Photo' : 'Capture Manually',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            
            if (_capturedImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_capturedImage != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserInfoScreen(imagePath: _capturedImage!.path),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Continue',
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
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.green : Colors.grey,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class FaceOutlinePainter extends CustomPainter {
  final bool isFaceInFrame;

  FaceOutlinePainter({required this.isFaceInFrame});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isFaceInFrame ? Colors.green : Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = isFaceInFrame ? Colors.green : Colors.white70
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final faceRect = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.15,
      size.width * 0.7,
      size.height * 0.5,
    );

    _drawDashedOval(canvas, faceRect, dashPaint);

    final shoulderPath = Path();
    shoulderPath.moveTo(size.width * 0.1, size.height * 0.85);
    shoulderPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.75,
      size.width * 0.9,
      size.height * 0.85,
    );
    shoulderPath.lineTo(size.width * 0.9, size.height * 0.95);
    shoulderPath.lineTo(size.width * 0.1, size.height * 0.95);
    shoulderPath.close();

    _drawDashedPath(canvas, shoulderPath, dashPaint);

    final guidelinePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.1),
      Offset(size.width * 0.5, size.height * 0.9),
      guidelinePaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.3),
      guidelinePaint,
    );
  }

  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addOval(rect);
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    
    final pathMetrics = path.computeMetrics();
    for (final pathMetric in pathMetrics) {
      double distance = 0.0;
      bool draw = true;
      
      while (distance < pathMetric.length) {
        final length = draw ? dashWidth : dashSpace;
        final endDistance = (distance + length).clamp(0.0, pathMetric.length);
        
        if (draw) {
          final extractPath = pathMetric.extractPath(distance, endDistance);
          canvas.drawPath(extractPath, paint);
        }
        
        distance = endDistance;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}