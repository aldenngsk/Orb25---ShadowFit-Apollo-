import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:shadowfitdemo/widgets/pose_overlay.dart';
import '../main.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:shadowfitdemo/services/firebase_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

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
        if (!mounted) return;
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
          if (!mounted) return;
          setState(() {
            _currentPose = poses.first;
          });
          _checkPlankPose(_currentPose!);
        } else {
          if (!mounted) return;
          setState(() {
            _currentPose = null;
            _isPlank = false;
            _formWarning = 'No person detected';
          });
          _pauseTimer();
        }
        _isDetecting = false;
      }).catchError((e) {
        if (!mounted) return;
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

  // Helper to calculate angle at joint B given points A, B, C
  double _calculateAngle(Offset a, Offset b, Offset c) {
    final ab = Offset(a.dx - b.dx, a.dy - b.dy);
    final cb = Offset(c.dx - b.dx, c.dy - b.dy);
    final dotProduct = ab.dx * cb.dx + ab.dy * cb.dy;
    final abLength = ab.distance;
    final cbLength = cb.distance;
    if (abLength == 0 || cbLength == 0) return 0;
    final angleRad = math.acos((dotProduct / (abLength * cbLength)).clamp(-1.0, 1.0));
    return angleRad * 180 / math.pi;
  }

  void _checkPlankPose(Pose pose) {
    // Angle-based plank logic: check hip angle (shoulder-hip-ankle) for both sides
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    double? leftAngle, rightAngle;
    if (leftShoulder != null && leftHip != null && leftAnkle != null) {
      leftAngle = _calculateAngle(
        Offset(leftShoulder.x, leftShoulder.y),
        Offset(leftHip.x, leftHip.y),
        Offset(leftAnkle.x, leftAnkle.y),
      );
    }
    if (rightShoulder != null && rightHip != null && rightAnkle != null) {
      rightAngle = _calculateAngle(
        Offset(rightShoulder.x, rightShoulder.y),
        Offset(rightHip.x, rightHip.y),
        Offset(rightAnkle.x, rightAnkle.y),
      );
    }

    // Use the side with the more visible landmarks (prefer left, fallback to right)
    double? angle = leftAngle ?? rightAngle;
    if (leftAngle != null && rightAngle != null) {
      angle = (leftAngle + rightAngle) / 2;
    }

    String? feedback;
    bool isPlank = false;
    if (angle != null) {
      if (angle >= 160 && angle <= 200) {
        isPlank = true;
        feedback = null;
      } else if (angle < 160) {
        feedback = 'Raise your hips a bit.';
      } else if (angle > 200) {
        feedback = 'Lower your hips a bit.';
      }
    } else {
      feedback = 'Could not detect your body position.';
    }

    setState(() {
      _isPlank = isPlank;
      _formWarning = feedback;
    });
    if (isPlank) {
      _startTimer();
    } else {
      _pauseTimer();
    }
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
                // Add user instruction for side view
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tip: Place your device so the camera sees you from the side. Use the front camera and turn your body sideways to the camera for best results.',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
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
                      'Good plank form!',
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