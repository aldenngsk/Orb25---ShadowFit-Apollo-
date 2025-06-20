import 'package:flutter/material.dart';
import 'package:shadowfitdemo/pages/exercise_page.dart';

class PushupPage extends StatelessWidget {
  final Function onComplete;

  const PushupPage({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return ExercisePage(
      exerciseType: 'Push-up',
      onComplete: onComplete,
    );
  }
} 