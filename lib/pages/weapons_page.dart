import 'package:flutter/material.dart';

class WeaponsPage extends StatelessWidget {
  const WeaponsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weapons'),
      ),
      body: const Center(
        child: Text('This is the Weapons Page'),
      ),
    );
  }
} 