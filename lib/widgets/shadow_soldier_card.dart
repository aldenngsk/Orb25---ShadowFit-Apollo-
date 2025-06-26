import 'package:flutter/material.dart';
import 'package:shadowfitdemo/models/shadow_soldier.dart';

class ShadowSoldierCard extends StatelessWidget {
  final ShadowSoldier shadowSoldier;
  final VoidCallback onTap;
  final int currentXP;

  const ShadowSoldierCard({super.key, 
    required this.shadowSoldier,
    required this.onTap,
    required this.currentXP,
  });

  String _getImagePath() {
    return 'assets/images/${shadowSoldier.name.toLowerCase()}.png';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: shadowSoldier.isUnlocked ? onTap : null,
      child: Card(
        color: shadowSoldier.isUnlocked ? Colors.black : Colors.grey[700],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  _getImagePath(),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              shadowSoldier.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              shadowSoldier.grade,
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 