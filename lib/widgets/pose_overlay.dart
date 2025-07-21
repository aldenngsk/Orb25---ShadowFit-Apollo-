import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseOverlay extends StatelessWidget {
  final Pose? pose;
  final Size imageSize;
  final Size widgetSize;
  final bool highlightArms;
  final bool isBodyStraight;

  const PoseOverlay({
    super.key,
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
    this.highlightArms = false,
    this.isBodyStraight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widgetSize.width,
      height: widgetSize.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple, width: 2),
        color: Colors.purple.withOpacity(0.05),
      ),
      child: CustomPaint(
        painter: PosePainter(
          pose: pose,
          imageSize: imageSize,
          widgetSize: widgetSize,
          highlightArms: highlightArms,
          isBodyStraight: isBodyStraight,
        ),
        size: widgetSize,
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final Pose? pose;
  final Size imageSize;
  final Size widgetSize;
  final bool highlightArms;
  final bool isBodyStraight;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
    this.highlightArms = false,
    this.isBodyStraight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null) return;

    final skeletonPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = Color(0xFFAE8B2D) // gold colour
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final landmarkPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4.0
      ..style = PaintingStyle.fill;

    // Skeleton connections
    _drawSkeleton(canvas, skeletonPaint, highlightPaint);

    // Body landmarks
    for (final entry in pose!.landmarks.entries) {
      final landmark = entry.value;
      final point = _transformPoint(landmark.x, landmark.y);
      canvas.drawCircle(point, 3.0, landmarkPaint);
    }
  }

  void _drawSkeleton(Canvas canvas, Paint skeletonPaint, Paint highlightPaint) {
    
    final connections = [
      // Face
      [PoseLandmarkType.nose, PoseLandmarkType.leftEyeInner],
      [PoseLandmarkType.nose, PoseLandmarkType.leftEye],
      [PoseLandmarkType.nose, PoseLandmarkType.leftEyeOuter],
      [PoseLandmarkType.nose, PoseLandmarkType.rightEyeInner],
      [PoseLandmarkType.nose, PoseLandmarkType.rightEye],
      [PoseLandmarkType.nose, PoseLandmarkType.rightEyeOuter],
      [PoseLandmarkType.leftEyeInner, PoseLandmarkType.leftEye],
      [PoseLandmarkType.leftEye, PoseLandmarkType.leftEyeOuter],
      [PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye],
      [PoseLandmarkType.rightEye, PoseLandmarkType.rightEyeOuter],
      [PoseLandmarkType.leftEye, PoseLandmarkType.leftEar],
      [PoseLandmarkType.rightEye, PoseLandmarkType.rightEar],
      // Torso
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      // Arms
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      // Legs
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      // Hands
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex],
      [PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex],
      [PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb],
    ];
    for (final connection in connections) {
      final startLandmark = pose!.landmarks[connection[0]];
      final endLandmark = pose!.landmarks[connection[1]];
      if (startLandmark != null && endLandmark != null) {
        final startPoint = _transformPoint(startLandmark.x, startLandmark.y);
        final endPoint = _transformPoint(endLandmark.x, endLandmark.y);
        // Highlight arms and legs with gold and rest with white
        final isArmOrLeg = _isArmOrLegConnection(connection[0], connection[1]);
        final paint = isArmOrLeg ? highlightPaint : skeletonPaint;
        canvas.drawLine(startPoint, endPoint, paint);
      }
    }
  }

  bool _isArmOrLegConnection(PoseLandmarkType a, PoseLandmarkType b) {
    // Arms
    const arm = [
      PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist
    ];
    // Legs
    const leg = [
      PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle
    ];
    return (arm.contains(a) && arm.contains(b)) || (leg.contains(a) && leg.contains(b));
  }

  Offset _transformPoint(double x, double y) {
    // Transform from image coordinates to widget coordinates
    final scaleX = widgetSize.width / imageSize.width;
    final scaleY = widgetSize.height / imageSize.height;
    
    return Offset(x * scaleX, y * scaleY);
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.pose != pose ||
           oldDelegate.imageSize != imageSize ||
           oldDelegate.widgetSize != widgetSize ||
           oldDelegate.highlightArms != highlightArms ||
           oldDelegate.isBodyStraight != isBodyStraight;
  }
} 