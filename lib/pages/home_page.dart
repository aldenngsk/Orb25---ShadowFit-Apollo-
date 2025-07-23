import 'package:flutter/material.dart';
import 'package:shadowfitdemo/pages/shadow_soldiers_page.dart';
import 'package:shadowfitdemo/pages/pushup_page.dart';
import 'package:shadowfitdemo/pages/situp_page.dart';
import 'package:shadowfitdemo/pages/running_page.dart';
import 'package:shadowfitdemo/pages/plank_page.dart';
import 'package:shadowfitdemo/services/firebase_service.dart';
import 'package:shadowfitdemo/models/shadow_soldier.dart';
import '../main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int setsCompleted = 0;
  int currentXP = 0;
  String currentRank = 'E';
  bool pushupsDone = false;
  bool situpsDone = false;
  bool runDone = false;
  DateTime? lastSetDate;
  String? pendingBossBattleFor;
  Timer? _plankButtonTimer;
  bool _isPlankButtonBlack = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addObserver(this);
  }

  void _startPlankButtonAnimation() {
    if (_plankButtonTimer == null || !_plankButtonTimer!.isActive) {
      _plankButtonTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        setState(() {
          _isPlankButtonBlack = !_isPlankButtonBlack;
        });
      });
    }
  }

  void _stopPlankButtonAnimation() {
    _plankButtonTimer?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPlankButtonAnimation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _updateLastActiveDate();
    } else if (state == AppLifecycleState.resumed) {
      _loadUserData();
    }
  }

  Future<void> _updateLastActiveDate() async {
    final user = FirebaseService.currentUser;
    if (user != null) {
      await FirebaseService.addUserData(user.uid, {
        'lastAppActive': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = FirebaseService.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseService.currentUser;
      if (user != null) {
        final userData = await FirebaseService.getUserData(user.uid);
        if (userData.exists) {
          final data = userData.data() as Map<String, dynamic>;

          final lastAppActiveString = data['lastAppActive'] as String?;
          DateTime? lastAppActiveDate;
          if (lastAppActiveString != null) {
            lastAppActiveDate = DateTime.parse(lastAppActiveString);
          }

          final now = DateTime.now();
          final bool needsReset = lastAppActiveDate == null || !isSameDay(now, lastAppActiveDate);

          setState(() {
            setsCompleted = data['setsCompleted'] ?? 0;
            currentXP = data['currentXP'] ?? 0;
            currentRank = data['currentRank'] ?? 'E';
            lastSetDate = data['lastSetDate'] != null
                ? DateTime.parse(data['lastSetDate'])
                : null;
            pendingBossBattleFor = data['pendingBossBattleFor'];
            
            if (pendingBossBattleFor != null) {
              _startPlankButtonAnimation();
            } else {
              _stopPlankButtonAnimation();
            }

            pushupsDone = needsReset ? false : (data['pushupsDone'] ?? false);
            situpsDone = needsReset ? false : (data['situpsDone'] ?? false);
            runDone = needsReset ? false : (data['runDone'] ?? false);
          });
          
          if (needsReset) {
            _saveUserData();
          }

          updateRank();
          _triggerBossBattleIfNeeded();
        }
      }
    } catch (e) {
    }
  }

  Future<void> _triggerBossBattleIfNeeded() async {
    if (pendingBossBattleFor != null) return; 

    final user = FirebaseService.currentUser;
    if (user == null) return;
    
    final userData = await FirebaseService.getUserData(user.uid);
    if (!userData.exists) return;
    
    final data = userData.data() as Map<String, dynamic>;
    final soldiersData = data['shadowSoldiers'] as List<dynamic>? ?? [];
    
    for (var soldierData in soldiersData) {
      final soldier = ShadowSoldier.fromMap(soldierData);
      if (setsCompleted >= soldier.requiredSets && !soldier.isUnlocked) {
        setState(() {
          pendingBossBattleFor = soldier.name;
        });
        await FirebaseService.addUserData(user.uid, {'pendingBossBattleFor': soldier.name});
        _startPlankButtonAnimation();
        break; 
      }
    }
  }

  Future<void> _saveUserData() async {
    try {
      final user = FirebaseService.currentUser;
      if (user != null) {
        await FirebaseService.addUserData(user.uid, {
          'email': user.email,
          'setsCompleted': setsCompleted,
          'currentXP': currentXP,
          'currentRank': currentRank,
          'lastSetDate': lastSetDate?.toIso8601String(),
          'pushupsDone': pushupsDone,
          'situpsDone': situpsDone,
          'runDone': runDone,
          'pendingBossBattleFor': pendingBossBattleFor,
        });
      }
    } catch (e) {
    }
  }

  void checkSetCompletion() {
    if (pushupsDone && situpsDone && runDone) {
      if (lastSetDate == null || !isSameDay(DateTime.now(), lastSetDate!)) {
        setState(() {
          setsCompleted++;
          currentXP += 3;
          lastSetDate = DateTime.now();
        });
        updateRank();
        _saveUserData().then((_) => _triggerBossBattleIfNeeded());
      }
    }
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  void updateRank() {
    setState(() {
      if (setsCompleted >= 220) {
        currentRank = 'SSS+';
      } else if (setsCompleted >= 185) currentRank = 'SSS';
      else if (setsCompleted >= 150) currentRank = 'SS';
      else if (setsCompleted >= 120) currentRank = 'S';
      else if (setsCompleted >= 90) currentRank = 'A';
      else if (setsCompleted >= 65) currentRank = 'B';
      else if (setsCompleted >= 40) currentRank = 'C';
      else if (setsCompleted >= 20) currentRank = 'D';
      else currentRank = 'E';
    });
    _saveUserData(); 
  }

  void incrementSet() {
    setState(() {
      setsCompleted++;
      currentXP = (currentXP + 3).clamp(0, 1000000); 
      updateRank();
    });
    _saveUserData().then((_) => _triggerBossBattleIfNeeded());
  }

  void updateXP(int spentXP) {
    setState(() {
      currentXP = (currentXP - spentXP).clamp(0, 1000000); 
    });
    _saveUserData(); 
  }

  int _getPlankDurationForCurrentChallenge() {
    final sets = setsCompleted;
    if (sets >= 220) return 240;
    if (sets >= 185) return 210;
    if (sets >= 150) return 180;
    if (sets >= 120) return 150;
    if (sets >= 90) return 120;
    if (sets >= 65) return 90;
    if (sets >= 40) return 60;
    if (sets >= 20) return 30;
    return 30;
  }

  Future<void> _completeBossBattle() async {
    final user = FirebaseService.currentUser;
    if (user == null || pendingBossBattleFor == null) return;

    final userData = await FirebaseService.getUserData(user.uid);
    if (!userData.exists) return;
    
    final data = userData.data() as Map<String, dynamic>;
    final soldiersData = List<Map<String, dynamic>>.from(data['shadowSoldiers'] ?? []);

    final soldierIndex = soldiersData.indexWhere((s) => s['name'] == pendingBossBattleFor);

    if (soldierIndex != -1) {
      soldiersData[soldierIndex]['isUnlocked'] = true;
    }

    await FirebaseService.addUserData(user.uid, {
      'shadowSoldiers': soldiersData,
      'pendingBossBattleFor': null,
    });
    
    setState(() {
      pendingBossBattleFor = null;
    });
    
    _stopPlankButtonAnimation();
    await _loadUserData();
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

    final isBossBattleActive = pendingBossBattleFor != null;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 1, 71),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 1, 71),
        foregroundColor: Colors.white,
        title: Text('ShadowFit'),
        leading: IconButton(
          icon: Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          },
        ),
        actions: [
          AudioControlButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      child: Column(
                        children: [
                          Text(
                            'Sets Completed: $setsCompleted',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Available XP: $currentXP',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Current Rank: $currentRank',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (isBossBattleActive) {
                            return Colors.grey[700]!;
                          }
                          return Colors.black;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                      padding: WidgetStateProperty.all<EdgeInsets>(
                        const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                      ),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      textStyle: WidgetStateProperty.all<TextStyle>(
                        const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onPressed: isBossBattleActive
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ShadowSoldiersPage(
                                  setsCompleted: setsCompleted,
                                  currentXP: currentXP,
                                  onXPSpent: updateXP,
                                ),
                              ),
                            );
                          },
                    child: const Text('Shadow Army',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.normal,
                        )),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.disabled) || isBossBattleActive) {
                            return Colors.grey[700]!;
                          }
                          return Colors.black;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                      padding: WidgetStateProperty.all<EdgeInsets>(
                        EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                      ),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      textStyle: WidgetStateProperty.all<TextStyle>(
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onPressed: (pushupsDone || isBossBattleActive) ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PushupPage(
                            onComplete: () {
                              setState(() {
                                pushupsDone = true;
                              });
                              _saveUserData();
                              checkSetCompletion();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Push-up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.disabled) || isBossBattleActive) {
                            return Colors.grey[700]!;
                          }
                          return Colors.black;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                      padding: WidgetStateProperty.all<EdgeInsets>(
                        EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                      ),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      textStyle: WidgetStateProperty.all<TextStyle>(
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onPressed: (situpsDone || isBossBattleActive) ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SitupPage(
                            onComplete: () {
                              setState(() {
                                situpsDone = true;
                              });
                              _saveUserData();
                              checkSetCompletion();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Sit-up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.disabled) || isBossBattleActive) {
                            return Colors.grey[700]!;
                          }
                          return Colors.black;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                      padding: WidgetStateProperty.all<EdgeInsets>(
                        EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                      ),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      textStyle: WidgetStateProperty.all<TextStyle>(
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onPressed: (runDone || isBossBattleActive) ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RunningPage(
                            onComplete: () {
                              setState(() {
                                runDone = true;
                              });
                              _saveUserData();
                              checkSetCompletion();
                            },
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Run', style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (isBossBattleActive) {
                            return _isPlankButtonBlack ? Colors.black : Colors.grey[700]!;
                          }
                          return Colors.grey[700]!;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                      padding: WidgetStateProperty.all<EdgeInsets>(
                        const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                      ),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      textStyle: WidgetStateProperty.all<TextStyle>(
                        const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onPressed: !isBossBattleActive
                        ? null
                        : () {
                            final duration = _getPlankDurationForCurrentChallenge();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlankPage(
                                  onPlankSuccess: _completeBossBattle,
                                  duration: duration,
                                ),
                              ),
                            );
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Plank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal)),
                      ],
                    ),
                  ),
                  SizedBox(height: 100), 
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'reset',
            backgroundColor: Colors.red,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Reset Account Progress'),
                  content: Text('Are you sure you want to reset all your progress? This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Reset', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await _resetAccountProgress();
                _loadUserData();
              }
            },
            tooltip: 'Reset Account',
            child: Icon(Icons.restart_alt),
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'increment',
            onPressed: () {
              incrementSet();
              _loadUserData();
            },
            tooltip: 'Increment Set',
            child: Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAccountProgress() async {
    _stopPlankButtonAnimation();
    setState(() {
      setsCompleted = 0;
      currentXP = 0;
      currentRank = 'E';
      pushupsDone = false;
      situpsDone = false;
      runDone = false;
      lastSetDate = null;
      pendingBossBattleFor = null;
    });
    final user = FirebaseService.currentUser;
    if (user != null) {
      final List<Map<String, dynamic>> initialShadows = [
        {'name': 'Igris', 'requiredSets': 20, 'grade': 'Beast', 'xp': 0, 'isUnlocked': false},
        {'name': 'Tank', 'requiredSets': 40, 'grade': 'Beast', 'xp': 0, 'isUnlocked': false},
        {'name': 'Iron', 'requiredSets': 65, 'grade': 'Beast', 'xp': 0, 'isUnlocked': false},
        {'name': 'Tusk', 'requiredSets': 90, 'grade': 'Beast', 'xp': 0, 'isUnlocked': false},
        {'name': 'Kaisel', 'requiredSets': 120, 'grade': 'Beast', 'xp': 0, 'isUnlocked': false},
        {'name': 'Beru', 'requiredSets': 150, 'grade': 'Beast', 'xp': 0, 'isUnlocked': false},
        {'name': 'Greed', 'requiredSets': 185, 'grade': 'Beast', 'xp': 0, 'isUnlocked': false},
        {'name': 'Bellion', 'requiredSets': 220, 'grade': 'Beast', 'xp': 0, 'isUnlocked': false},
      ];
      await FirebaseService.addUserData(user.uid, {
        'setsCompleted': 0,
        'currentXP': 0,
        'currentRank': 'E',
        'lastSetDate': null,
        'pushupsDone': false,
        'situpsDone': false,
        'runDone': false,
        'shadowSoldiers': initialShadows,
        'pendingBossBattleFor': null,
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account progress has been reset.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 