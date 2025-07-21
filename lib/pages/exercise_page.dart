import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:shadowfitdemo/widgets/pose_overlay.dart';
import 'package:flutter/foundation.dart';
import '../main.dart';
import 'dart:math' as math;
import 'dart:async';

class ExercisePage extends StatefulWidget {
  final String exerciseType;
  final Function onComplete;

  const ExercisePage({super.key, required this.exerciseType, required this.onComplete});

  @override
  _ExercisePageState createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  int count = 0;
  bool isCompleted = false;
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  late Future<void> _initializeControllerFuture;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isDetecting = false;
  Pose? _currentPose; // Store current pose for visualization

  // Push-up specific state variables
  bool _isPushupDown = false;
  bool _isPushupUp = false;

  // Sit-up specific state variables
  bool _isSitupUp = false;
  bool _isSitupDown = false;

  int _noPoseFrames = 0;
  String? _poseError;

  // Form validation state variables
  bool _isBodyStraight = false;
  String? _formWarning;

  // Debug info
  double? _debugAngle;
  String _debugStatus = '';
  String _debugLandmarkInfo = '';

  // Timer variables
  static const int _totalSeconds = 300; // 5 minutes
  int _secondsLeft = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _startTimer();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      print('Available cameras:');
      if (_cameras != null) {
        for (final cam in _cameras!) {
          print('Camera: [36m[1m${cam.name}[0m, lensDirection: ${cam.lensDirection}');
        }
      }
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

        _initializeControllerFuture = _controller!.initialize();
        await _initializeControllerFuture;
        _startImageStream();
        setState(() {});
      } else {
        print('No cameras found');
      }
    } catch (e) {
      print('Error initialising camera: $e');
    }
  }

  void _startImageStream() {
    _controller!.startImageStream((CameraImage cameraImage) {
      print('CameraImage format: [33m${cameraImage.format.raw}[0m, planes: ${cameraImage.planes.length}');
      if (_isDetecting) return;
      _isDetecting = true;

      final InputImage? inputImage = _inputImageFromCameraImage(cameraImage);
      if (inputImage == null) {
        print('InputImage is null (format or rotation not supported)');
        setState(() {
          _poseError = 'Camera image format or rotation not supported on this device.';
        });
        _isDetecting = false;
        return;
      }

      _processImage(inputImage).then((_) {
        _isDetecting = false;
      }).catchError((e) {
        print('Error processing image: $e');
        setState(() {
          _poseError = 'Pose detection error: $e';
        });
        _isDetecting = false;
      });
    });
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final InputImageRotation? rotation = _rotationIntToImageRotation(
      _controller!.description.sensorOrientation,
    );
    if (rotation == null) {
      print('Unsupported rotation: [31m${_controller!.description.sensorOrientation}[0m');
      setState(() {
        _poseError = 'Unsupported camera rotation: ${_controller!.description.sensorOrientation}';
      });
      return null;
    }

    final InputImageFormat? format = _formatIntToInputImageFormat(
      image.format.raw,
    );
    if (format == null) {
      print('Unsupported image format: [31m${image.format.raw}[0m');
      setState(() {
        _poseError = 'Unsupported camera image format: ${image.format.raw}';
      });
      return null;
    }

    if (format == InputImageFormat.bgra8888) {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    // Default (YUV420)
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
      case 17: return InputImageFormat.yuv420; // iOS on Simulator, and often Android YUV_420_888
      case 35: return InputImageFormat.yuv420; // Android YUV_420_888
      case 1111970369: return InputImageFormat.bgra8888; // iOS BGRA8888
      default: return null;
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    print('DEBUG: Entered _processImage');
    final List<Pose> poses = await _poseDetector.processImage(inputImage);
    print('DEBUG: Poses detected: ${poses.length}');
    if (poses.isNotEmpty) {
      final pose = poses.first;
      setState(() {
        _currentPose = pose;
        _noPoseFrames = 0;
        _poseError = null;
      });
      if (widget.exerciseType.toLowerCase().contains('push-up')) {
        print('DEBUG: Calling _checkPushupProgress');
        _checkPushupProgress(pose);
      } else if (widget.exerciseType.toLowerCase().contains('sit-up')) {
        print('DEBUG: Calling _checkSitupProgress');
        _checkSitupProgress(pose);
      }
    } else {
      setState(() {
        _currentPose = null;
        _noPoseFrames++;
        if (_noPoseFrames > 3) {
          _poseError = 'No pose detected. Make sure your body is visible to the camera.';
        }
      });
    }
  }

  double calculateAngle(Offset a, Offset b, Offset c) {
    final radians = math.atan2(c.dy - b.dy, c.dx - b.dx) - math.atan2(a.dy - b.dy, a.dx - b.dx);
    double angle = (radians * 180.0 / math.pi).abs();
    if (angle > 180.0) angle = 360 - angle;
    return angle;
  }

  Offset? detectionBodyPart(Map<PoseLandmarkType, PoseLandmark> landmarks, PoseLandmarkType type) {
    final l = landmarks[type];
    if (l == null) return null;
    return Offset(l.x, l.y);
  }

  void _checkPushupProgress(Pose pose) {
    print('DEBUG: Entered _checkPushupProgress');
    final landmarks = pose.landmarks;
    final leftShoulder = detectionBodyPart(landmarks, PoseLandmarkType.leftShoulder);
    final leftElbow = detectionBodyPart(landmarks, PoseLandmarkType.leftElbow);
    final leftWrist = detectionBodyPart(landmarks, PoseLandmarkType.leftWrist);
    final rightShoulder = detectionBodyPart(landmarks, PoseLandmarkType.rightShoulder);
    final rightElbow = detectionBodyPart(landmarks, PoseLandmarkType.rightElbow);
    final rightWrist = detectionBodyPart(landmarks, PoseLandmarkType.rightWrist);
    // Debug printout
    print('Push-up landmarks:');
    print('  leftShoulder: $leftShoulder');
    print('  leftElbow: $leftElbow');
    print('  leftWrist: $leftWrist');
    print('  rightShoulder: $rightShoulder');
    print('  rightElbow: $rightElbow');
    print('  rightWrist: $rightWrist');
    List<String> missing = [];
    if (leftShoulder == null) missing.add('leftShoulder');
    if (leftElbow == null) missing.add('leftElbow');
    if (leftWrist == null) missing.add('leftWrist');
    if (rightShoulder == null) missing.add('rightShoulder');
    if (rightElbow == null) missing.add('rightElbow');
    if (rightWrist == null) missing.add('rightWrist');
    setState(() {
      _debugLandmarkInfo =
        'LShoulder: ${leftShoulder ?? 'null'}\nLElbow: ${leftElbow ?? 'null'}\nLWrist: ${leftWrist ?? 'null'}\nRShoulder: ${rightShoulder ?? 'null'}\nRElbow: ${rightElbow ?? 'null'}\nRWrist: ${rightWrist ?? 'null'}\nMissing: ${missing.isEmpty ? 'None' : missing.join(', ')}';
    });
    if (missing.isNotEmpty) {
      setState(() {
        _debugAngle = null;
        _debugStatus = 'No pose';
      });
      return;
    }
    final leftArmAngle = calculateAngle(leftShoulder!, leftElbow!, leftWrist!);
    final rightArmAngle = calculateAngle(rightShoulder!, rightElbow!, rightWrist!);
    final avgArmAngle = ((leftArmAngle + rightArmAngle) / 2);
    setState(() {
      _debugAngle = avgArmAngle;
      _debugStatus = _isPushupUp ? 'Up' : 'Down';
    });
    // Sports_py-master logic
    if (_isPushupUp) {
      if (avgArmAngle < 70) {
        setState(() {
          count++;
          _isPushupUp = false;
        });
      }
    } else {
      if (avgArmAngle > 160) {
        setState(() {
          _isPushupUp = true;
        });
      }
    }
    if (count >= 60) _completeExercise();
  }

  void _checkSitupProgress(Pose pose) {
    final landmarks = pose.landmarks;
    // Shoulders, hips, knees for abdomen angle
    final leftShoulder = detectionBodyPart(landmarks, PoseLandmarkType.leftShoulder);
    final rightShoulder = detectionBodyPart(landmarks, PoseLandmarkType.rightShoulder);
    final leftHip = detectionBodyPart(landmarks, PoseLandmarkType.leftHip);
    final rightHip = detectionBodyPart(landmarks, PoseLandmarkType.rightHip);
    final leftKnee = detectionBodyPart(landmarks, PoseLandmarkType.leftKnee);
    final rightKnee = detectionBodyPart(landmarks, PoseLandmarkType.rightKnee);
    if ([leftShoulder, rightShoulder, leftHip, rightHip, leftKnee, rightKnee].contains(null)) {
      setState(() {
        _debugAngle = null;
        _debugStatus = 'No pose';
      });
      return;
    }
    final shoulderAvg = Offset((leftShoulder!.dx + rightShoulder!.dx) / 2, (leftShoulder.dy + rightShoulder.dy) / 2);
    final hipAvg = Offset((leftHip!.dx + rightHip!.dx) / 2, (leftHip.dy + rightHip.dy) / 2);
    final kneeAvg = Offset((leftKnee!.dx + rightKnee!.dx) / 2, (leftKnee.dy + rightKnee!.dy) / 2);
    final abdomenAngle = calculateAngle(shoulderAvg, hipAvg, kneeAvg);
    setState(() {
      _debugAngle = abdomenAngle;
      _debugStatus = _isSitupUp ? 'Down' : 'Up';
    });
    // Sports_py-master logic
    if (_isSitupUp) {
      if (abdomenAngle < 55) {
        setState(() {
          count++;
          _isSitupUp = false;
        });
      }
    } else {
      if (abdomenAngle > 105) {
        setState(() {
          _isSitupUp = true;
        });
      }
    }
    if (count >= 60) _completeExercise();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
        // Return to homepage
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    _timer?.cancel();
    super.dispose();
  }

  void incrementCount() {
    if (count < 60) {
      setState(() {
        count++;
        if (count == 60) {
          isCompleted = true;
          widget.onComplete();
        }
      });
    }
  }

  void _completeExercise() {
    setState(() {
      isCompleted = true;
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 1, 71),
      appBar: AppBar(backgroundColor: const Color.fromARGB(255, 0, 1, 71), title: Text(widget.exerciseType),
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
                // Countdown timer display
                Text(
                  'Time Left: ${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                SizedBox(height: 10),
                Text(
                  'Count: $count/60',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 10),
                // Debug info overlay (like score_table)
                // Container(
                //   padding: EdgeInsets.all(12),
                //   margin: EdgeInsets.symmetric(vertical: 8),
                //   decoration: BoxDecoration(
                //     color: Colors.black.withOpacity(0.7),
                //     borderRadius: BorderRadius.circular(8),
                //   ),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text('Activity:  {widget.exerciseType}', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                //       Text('Counter: $count', style: TextStyle(color: Colors.white, fontSize: 16)),
                //       Text('Status: ${_debugStatus}', style: TextStyle(color: Colors.greenAccent, fontSize: 16)),
                //       Text('Angle: ${_debugAngle != null ? _debugAngle!.toStringAsFixed(1) : '--'}', style: TextStyle(color: Colors.cyanAccent, fontSize: 16)),
                //       if (_poseError != null)
                //         Text(_poseError!, style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                //       if (widget.exerciseType == 'Push-ups')
                //         Text(_debugLandmarkInfo, style: TextStyle(color: Colors.orange, fontSize: 12)),
                //     ],
                //   ),
                // ),
                if (_isPushupDown || _isPushupUp)
                  Text(
                    _isPushupDown ? 'Push-up Down Position' : 'Push-up Up Position',
                    style: TextStyle(fontSize: 18, color: Colors.yellow, fontWeight: FontWeight.bold),
                  ),
                if (_isSitupDown || _isSitupUp)
                  Text(
                    _isSitupDown ? 'Sit-up Down Position' : 'Sit-up Up Position',
                    style: TextStyle(fontSize: 18, color: Colors.yellow, fontWeight: FontWeight.bold),
                  ),
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
                if (_isBodyStraight && (_isPushupDown || _isPushupUp || _isSitupDown || _isSitupUp))
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
                if (_poseError != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _poseError!,
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
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
                                    pose: _currentPose,
                                    imageSize: Size(_controller!.value.previewSize!.width, _controller!.value.previewSize!.height),
                                    widgetSize: Size(360, 480),
                                    highlightArms: _isPushupDown || _isPushupUp,
                                    isBodyStraight: _isBodyStraight,
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
      floatingActionButton: FloatingActionButton(
        onPressed: incrementCount,
        child: Icon(Icons.add),
      ),
    );
  }
} 