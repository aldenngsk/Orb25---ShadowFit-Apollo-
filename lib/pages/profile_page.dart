import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage('assets/icon/app_icon.png'), // Update path as needed
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Alden Ng',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
    );
  }
} 