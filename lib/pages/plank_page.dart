import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:shadowfitdemo/widgets/pose_overlay.dart';
import '../main.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:shadowfitdemo/services/firebase_service.dart';
import 'package:flutter/foundation.dart';

class PlankPage extends StatefulWidget {
  final Function onPlankSuccess;
  final int duration;

  const PlankPage({super.key, required this.onPlankSuccess, required this.duration});

  @override
  _PlankPageState createState() => _PlankPageState();
}

class _PlankPageState extends State<PlankPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  late Future<void> _initializeControllerFuture;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isDetecting = false;
  Pose? _currentPose;
  bool _isPlank = false;
  String? _formWarning;

  // Timer variables
  late int _secondsLeft;
  Timer? _timer;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.duration;
    _initializeControllerFuture = _initializeCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final CameraDescription frontCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );
        _controller = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _controller!.initialize();
        _startImageStream();
        setState(() {});
      } else {
        print('No cameras found');
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _startImageStream() {
    _controller!.startImageStream((CameraImage cameraImage) {
      if (_isDetecting) return;
      _isDetecting = true;
      final InputImage? inputImage = _inputImageFromCameraImage(cameraImage);
      if (inputImage == null) {
        setState(() {
          _currentPose = null;
          _isPlank = false;
          _formWarning = 'Camera image format or rotation not supported.';
        });
        _isDetecting = false;
        _pauseTimer();
        return;
      }
      _poseDetector.processImage(inputImage).then((poses) {
        if (poses.isNotEmpty) {
          setState(() {
            _currentPose = poses.first;
          });
          _checkPlankPose(_currentPose!);
        } else {
          setState(() {
            _currentPose = null;
            _isPlank = false;
            _formWarning = 'No person detected';
          });
          _pauseTimer();
        }
        _isDetecting = false;
      }).catchError((e) {
        setState(() {
          _formWarning = 'Pose detection error: $e';
        });
        _isDetecting = false;
      });
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final InputImageRotation? rotation = _rotationIntToImageRotation(
      _controller!.description.sensorOrientation,
    );
    if (rotation == null) return null;

    final InputImageFormat? format = _formatIntToInputImageFormat(
      image.format.raw,
    );
    if (format == null) return null;

    // Only use YUV420 (no WriteBuffer)
    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  InputImageRotation? _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0: return InputImageRotation.rotation0deg;
      case 90: return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default: return null;
    }
  }

  InputImageFormat? _formatIntToInputImageFormat(int format) {
    switch (format) {
      case 17: return InputImageFormat.yuv420;
      case 35: return InputImageFormat.yuv420;
      case 1111970369: return InputImageFormat.bgra8888;
      default: return null;
    }
  }

  void _checkPlankPose(Pose pose) {
    // Simple plank logic: body is straight and parallel to the ground
    // We'll check if shoulders, hips, and ankles are roughly aligned horizontally (y values similar)
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder != null && rightShoulder != null && leftHip != null && rightHip != null && leftAnkle != null && rightAnkle != null) {
      // Calculate average y for shoulders, hips, ankles
      final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
      final avgHipY = (leftHip.y + rightHip.y) / 2;
      final avgAnkleY = (leftAnkle.y + rightAnkle.y) / 2;
      // All y values should be within a threshold (body is straight)
      final isStraight = (avgShoulderY - avgHipY).abs() < 0.08 && (avgHipY - avgAnkleY).abs() < 0.08;
      // Shoulders should be above hips, hips above ankles (plank is horizontal)
      final isHorizontal = avgShoulderY < avgHipY && avgHipY < avgAnkleY;
      if (isStraight && isHorizontal) {
        setState(() {
          _isPlank = true;
          _formWarning = null;
        });
        _startTimer();
        return;
      }
    }
    setState(() {
      _isPlank = false;
      _formWarning = 'Hold a straight plank position!';
    });
    _pauseTimer();
  }

  void _startTimer() {
    if (_timerRunning || _secondsLeft == 0) return;
    _timerRunning = true;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isPlank) {
        _pauseTimer();
        return;
      }
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _completePlank();
      }
    });
  }

  void _pauseTimer() {
    if (_timerRunning) {
      _timer?.cancel();
      _timerRunning = false;
    }
  }

  void _completePlank() {
    _timer?.cancel();
    _timerRunning = false;

    widget.onPlankSuccess();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 1, 71),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 1, 71),
        title: Text('Plank'),
        leading: BackButton(),
        actions: [
          AudioControlButton(),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Timer at the top
                Text(
                  'Time Left: ${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                SizedBox(height: 10),
                // No counter for plank
                SizedBox(height: 10),
                if (_formWarning != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formWarning!,
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_isPlank && _formWarning == null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Good Form!',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 20),
                // Centered camera preview with pose overlay
                _controller != null && _controller!.value.isInitialized
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 360,
                            height: 480,
                            child: Stack(
                              children: [
                                CameraPreview(_controller!),
                                if (_currentPose != null)
                                  PoseOverlay(
                                    pose: _currentPose!,
                                    imageSize: Size(_controller!.value.previewSize!.width, _controller!.value.previewSize!.height),
                                    widgetSize: Size(360, 480),
                                    highlightArms: false,
                                    isBodyStraight: _isPlank,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 360,
                            height: 480,
                            color: Colors.black,
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                SizedBox(height: 20),
                SizedBox(height: 100), // Add bottom padding
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: kDebugMode
          ? FloatingActionButton(
              onPressed: _completePlank,
              child: const Icon(Icons.done),
            )
          : null,
    );
  }
} 