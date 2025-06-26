import 'package:flutter/material.dart';
import 'package:shadowfitdemo/models/shadow_soldier.dart';
import 'package:shadowfitdemo/widgets/shadow_soldier_card.dart';
import 'package:shadowfitdemo/services/firebase_service.dart';
import 'package:shadowfitdemo/pages/shadow_soldier_detail_page.dart';
import '../main.dart';

class ShadowSoldiersPage extends StatefulWidget {
  final int setsCompleted;
  final int currentXP;
  final Function(int) onXPSpent;

  const ShadowSoldiersPage({super.key, 
    required this.setsCompleted,
    required this.currentXP,
    required this.onXPSpent,
  });

  @override
  _ShadowSoldiersPageState createState() => _ShadowSoldiersPageState();
}

class _ShadowSoldiersPageState extends State<ShadowSoldiersPage> {
  late List<ShadowSoldier> shadowSoldiers;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    shadowSoldiers = [
      ShadowSoldier(name: 'Igris', requiredSets: 20),
      ShadowSoldier(name: 'Tank', requiredSets: 40),
      ShadowSoldier(name: 'Iron', requiredSets: 65),
      ShadowSoldier(name: 'Tusk', requiredSets: 90),
      ShadowSoldier(name: 'Kaisel', requiredSets: 120),
      ShadowSoldier(name: 'Beru', requiredSets: 150),
      ShadowSoldier(name: 'Greed', requiredSets: 185),
      ShadowSoldier(name: 'Bellion', requiredSets: 220),
    ];
    _loadShadowSoldiers();
  }

  Future<void> _loadShadowSoldiers() async {
    try {
      final user = FirebaseService.currentUser;
      if (user != null) {
        final userData = await FirebaseService.getUserData(user.uid);
        if (userData.exists) {
          final data = userData.data() as Map<String, dynamic>;
          if (data.containsKey('shadowSoldiers')) {
            final List<dynamic> soldiersData = data['shadowSoldiers'];
            setState(() {
              shadowSoldiers = soldiersData
                  .map((soldierData) => ShadowSoldier.fromMap(soldierData))
                  .toList();
              isLoading = false;
            });
          } else {
            // If no saved data exists, save the initial state
            await _saveShadowSoldiers();
            setState(() {
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error loading shadow soldiers: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveShadowSoldiers() async {
    try {
      final user = FirebaseService.currentUser;
      if (user != null) {
        final soldiersData = shadowSoldiers.map((soldier) => soldier.toMap()).toList();
        await FirebaseService.addUserData(user.uid, {
          'shadowSoldiers': soldiersData,
        });
      }
    } catch (e) {
      print("Error saving shadow soldiers: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 0, 1, 71),
        body: Center(child: Text('Not logged in', style: TextStyle(color: Colors.white))),
      );
    }
    return StreamBuilder(
      stream: FirebaseService.userDocStream(user.uid),
      builder: (context, AsyncSnapshot snapshot) {
        if (!snapshot.hasData || snapshot.data == null || !snapshot.data.exists) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 0, 1, 71),
            body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
          );
        }
        final data = snapshot.data.data() as Map<String, dynamic>;
        List<ShadowSoldier> shadowSoldiers = [];
        if (data.containsKey('shadowSoldiers')) {
          final List<dynamic> soldiersData = data['shadowSoldiers'];
          shadowSoldiers = soldiersData.map((soldierData) => ShadowSoldier.fromMap(soldierData)).toList();
        } else {
          shadowSoldiers = [
            ShadowSoldier(name: 'Igris', requiredSets: 20),
            ShadowSoldier(name: 'Tank', requiredSets: 40),
            ShadowSoldier(name: 'Iron', requiredSets: 65),
            ShadowSoldier(name: 'Tusk', requiredSets: 90),
            ShadowSoldier(name: 'Kaisel', requiredSets: 120),
            ShadowSoldier(name: 'Beru', requiredSets: 150),
            ShadowSoldier(name: 'Greed', requiredSets: 185),
            ShadowSoldier(name: 'Bellion', requiredSets: 220),
          ];
        }
        int availableXP = data['currentXP'] ?? 0;
        int setsCompleted = data['setsCompleted'] ?? 0;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 0, 1, 71),
            title: Text('Shadow Army'),
            actions: [
              AudioControlButton(),
            ],
          ),
          body: GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: shadowSoldiers.length,
            itemBuilder: (context, index) {
              shadowSoldiers[index].isUnlocked = setsCompleted >= shadowSoldiers[index].requiredSets;
              return ShadowSoldierCard(
                shadowSoldier: shadowSoldiers[index],
                currentXP: availableXP,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShadowSoldierDetailPage(
                      shadowSoldier: shadowSoldiers[index],
                      currentXP: availableXP,
                      onXPSpent: (spentXP) {
                        widget.onXPSpent(spentXP);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
} 