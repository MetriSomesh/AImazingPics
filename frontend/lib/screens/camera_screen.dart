
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:frontend/screens/user_information.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  
  late FaceDetector _faceDetector;
  
  List<Face> _faces = [];
  bool _isFaceDetected = false;
  bool _isFaceInFrame = false;
  bool _isProcessing = false;
  
  
  int _frameCounter = 0;
  int _frameSkip = 2;
  DateTime _lastProcessed = DateTime.now();
  bool _captureTriggered = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      
      CameraDescription frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low, 
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, 
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });

      
        _controller!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
   
    if (_isProcessing || _capturedImage != null || _captureTriggered) return;
    
    
    _frameCounter++;
    if (_frameCounter % _frameSkip != 0) return;
    
    
    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < 125) return;
    
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
            
            if (_isFaceDetected && faces.isNotEmpty) {
                _captureTriggered = true;
                _capturePhotoAutomatically();
            } else {
              _isFaceInFrame = false;
            }
          });
        }
      }
    } catch (e) {
      //print('Error processing image: $e');
      
     
      if (_frameSkip < 5) _frameSkip++;
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage cameraImage) {
    try {
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
      }
      
    } catch (e) {
      //print('Error converting camera image: $e');
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

  bool _checkFaceInFrame(Face face) {
    
    final faceRect = face.boundingBox;
    final centerX = faceRect.left + faceRect.width / 2;
    final centerY = faceRect.top + faceRect.height / 2;
    
   
    final isCentered = centerX > 0.4 && centerX < 0.6 && 
                      centerY > 0.4 && centerY < 0.6;    
    final faceSize = faceRect.width * faceRect.height;
    final goodSize = faceSize > 0.1 && faceSize < 0.3;
    
    return isCentered && goodSize;
  }

  Future<void> _capturePhotoAutomatically() async {
   
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }

   
    await Future.delayed(Duration(seconds: 3));
    
    if (!_controller!.value.isInitialized) return;
    
    try {
      final XFile image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      //print('Error capturing photo: $e');
     
      _captureTriggered = false;
      
     
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.startImageStream(_processCameraImage);
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (!_controller!.value.isInitialized) return;

    try {
      await _controller!.stopImageStream();
      final XFile image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      print('Error capturing photo: $e');
    }
  }

  void _retakePhoto() async {
    setState(() {
      _capturedImage = null;
      _faces = [];
      _isFaceDetected = false;
      _isFaceInFrame = false;
      _captureTriggered = false;
      _frameSkip = 2; 
    });
    
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.startImageStream(_processCameraImage);
    }
  }

  @override
  void dispose() {
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
        title: Text('AImazing'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
          
            Padding(
              padding: const EdgeInsets.all(20.0),
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
                    : _isFaceInFrame 
                        ? 'Face detected! Capturing photo...'
                        : 'Position your face within the outline',
                style: TextStyle(
                  color: _isFaceInFrame ? Colors.green : Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            SizedBox(height: 20),
            
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusIndicator('Face Detected', _isFaceDetected),
                
              ],
            ),
            
            SizedBox(height: 20),
            
            
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
                            child: Center(
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
            
            SizedBox(height: 30),
            
           
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
                    style: TextStyle(
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
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            
            SizedBox(height: 30),
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
        SizedBox(width: 8),
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
    const dashWidth = 8.0;
    const dashSpace = 4.0;
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
