import 'package:flutter/material.dart';
import 'package:shadowfitdemo/models/shadow_soldier.dart';
import 'package:shadowfitdemo/services/firebase_service.dart';
import '../main.dart';

class ShadowSoldierDetailPage extends StatefulWidget {
  final ShadowSoldier shadowSoldier;
  final int currentXP;
  final Function(int) onXPSpent;

  const ShadowSoldierDetailPage({super.key, 
    required this.shadowSoldier,
    required this.currentXP,
    required this.onXPSpent,
  });

  @override
  _ShadowSoldierDetailPageState createState() => _ShadowSoldierDetailPageState();
}

class _ShadowSoldierDetailPageState extends State<ShadowSoldierDetailPage> {
  String _getImagePath() {
    return 'assets/images/${widget.shadowSoldier.name.toLowerCase()}.png';
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveShadowSoldier() async {
    try {
      final user = FirebaseService.currentUser;
      if (user != null) {
        final userData = await FirebaseService.getUserData(user.uid);
        if (userData.exists) {
          final data = userData.data() as Map<String, dynamic>;
          List<dynamic> soldiersData = data['shadowSoldiers'] ?? [];
          
          // Update the specific soldier in the list
          final index = soldiersData.indexWhere(
            (s) => s['name'] == widget.shadowSoldier.name
          );
          if (index != -1) {
            soldiersData[index] = widget.shadowSoldier.toMap();
          }

          await FirebaseService.addUserData(user.uid, {
            'shadowSoldiers': soldiersData,
          });
        }
      }
    } catch (e) {
      print("Error saving shadow soldier: $e");
    }
  }

  void upgradeGrade(int availableXP) {
    final user = FirebaseService.currentUser;
    if (user == null) return;
    int requiredXP = widget.shadowSoldier.getRequiredXPForNextGrade();
    if (availableXP >= requiredXP) {
      setState(() {
        widget.shadowSoldier.xp += requiredXP;
        widget.shadowSoldier.updateGrade();
      });
      widget.onXPSpent(requiredXP);
      _saveShadowSoldier(); // Save after upgrading
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
        List<dynamic> soldiersData = data['shadowSoldiers'] ?? [];
        final shadowData = soldiersData.firstWhere(
          (s) => s['name'] == widget.shadowSoldier.name,
          orElse: () => null,
        );
        ShadowSoldier shadowSoldier = widget.shadowSoldier;
        if (shadowData != null) {
          shadowSoldier = ShadowSoldier.fromMap(shadowData);
        }
        int availableXP = data['currentXP'] ?? 0;
        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 0, 1, 71),
          appBar: AppBar(
            title: Text(widget.shadowSoldier.name),
            actions: [
              AudioControlButton(),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          _getImagePath(),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      widget.shadowSoldier.name,
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Current Grade: ${widget.shadowSoldier.grade}',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Current XP: ${widget.shadowSoldier.xp}',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Available XP: $availableXP',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 20),
                    if (widget.shadowSoldier.getNextGrade() != 'Max Level')
                      ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith<Color>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.disabled)) {
                                return Colors.grey[700]!;
                              }
                              return Colors.black;
                            },
                          ),
                          foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                          padding: WidgetStateProperty.all<EdgeInsets>(
                            EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                          textStyle: WidgetStateProperty.all<TextStyle>(
                            TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                          ),
                        ),
                        onPressed: availableXP >= widget.shadowSoldier.getRequiredXPForNextGrade() 
                          ? () => upgradeGrade(availableXP)
                          : null,
                        child: Text(
                          'Upgrade to ${widget.shadowSoldier.getNextGrade()}\n'
                          'Required XP: ${widget.shadowSoldier.getRequiredXPForNextGrade()}',
                        ),
                      ),
                    SizedBox(height: 20), // Add bottom padding
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 