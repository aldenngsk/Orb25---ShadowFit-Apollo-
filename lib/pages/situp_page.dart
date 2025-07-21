import 'package:flutter/material.dart';
import 'package:shadowfitdemo/pages/exercise_page.dart';

class SitupPage extends StatelessWidget {
  final Function onComplete;

  const SitupPage({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return ExercisePage(
      exerciseType: 'Sit up',
      onComplete: onComplete,
    );
  }
} 