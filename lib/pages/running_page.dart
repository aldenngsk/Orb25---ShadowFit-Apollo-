import 'package:flutter/material.dart';
import 'package:shadowfitdemo/services/strava_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadowfitdemo/pages/home_page.dart';
import '../main.dart';

class RunningPage extends StatefulWidget {
  final Function onComplete;

  const RunningPage({super.key, required this.onComplete});

  @override
  _RunningPageState createState() => _RunningPageState();
}

class _RunningPageState extends State<RunningPage> {
  bool isLoading = false;
  bool isConnected = false;
  List<StravaActivity> recentActivities = [];
  String statusMessage = '';
  bool hasQualifyingRunToday = false;

  @override
  void initState() {
    super.initState();
    _checkStravaConnection();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkStravaConnection();
  }

  Future<void> _checkStravaConnection() async {
    setState(() {
      isLoading = true;
    });

    final connected = StravaService.isAuthenticated;
    setState(() {
      isConnected = connected;
      isLoading = false;
    });

    if (connected) {
      await _loadRecentActivities();
      await _checkTodayRun();
    }
  }

  Future<void> _loadRecentActivities() async {
    setState(() {
      isLoading = true;
    });

    try {
      final activities = await StravaService.getRecentActivities(perPage: 10);
      setState(() {
        recentActivities = activities;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error loading activities: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _checkTodayRun() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Checking today\'s runs...';
    });

    try {
      final hasRun = await StravaService.hasCompletedRunToday();
      hasQualifyingRunToday = hasRun;
      if (hasRun) {
        widget.onComplete();
      }

      setState(() {
        if (hasRun) {
          statusMessage = '✅ You have completed your run for today! Complete push-ups and sit-ups to earn 3 XP.';
        } else {
          statusMessage = 'No qualifying run found for today. Please complete a 2.4km run and sync with Strava.';
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error checking runs: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _refreshActivities() async {
    await _loadRecentActivities();
    await _checkTodayRun();
  }

  Future<void> _connectStrava() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Connecting to Strava...';
    });

    try {
      final success = await StravaService.authenticate();
      if (success) {
        setState(() {
          statusMessage = 'Please complete authentication in your browser';
        });
      } else {
        setState(() {
          statusMessage = 'Failed to connect to Strava';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error connecting to Strava: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _disconnectStrava() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Disconnecting from Strava...';
    });

    try {
      await StravaService.logout();
      setState(() {
        isConnected = false;
        recentActivities = [];
        statusMessage = 'Disconnected from Strava';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error disconnecting from Strava: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 1, 71),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 1, 71),
        title: Text('Run'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          AudioControlButton(),
          if (isConnected)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _refreshActivities,
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Card(
                color: Colors.black,
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.error,
                        color: isConnected ? Colors.green : Colors.red,
                        size: 30,
                      ),
                      SizedBox(width: 10),
                      Text(
                        isConnected ? 'Connected to Strava' : 'Not Connected to Strava',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              if (statusMessage.isNotEmpty && isConnected)
                Card(
                  color: Colors.black,
                  child: Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text(
                      statusMessage,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              SizedBox(height: 20),
              if (isLoading)
                Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              if (isConnected && recentActivities.isNotEmpty) ...[
                Text(
                  'Recent Runs:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: recentActivities.length,
                    itemBuilder: (context, index) {
                      final activity = recentActivities[index];
                      final isToday = activity.startDate.day == DateTime.now().day &&
                                     activity.startDate.month == DateTime.now().month &&
                                     activity.startDate.year == DateTime.now().year;
                      final isQualifying = activity.type == 'Run' && activity.distanceInKm >= 2.4;
                      return Card(
                        color: isToday && isQualifying
                            ? Colors.green.withOpacity(0.3)
                            : Colors.black,
                        child: ListTile(
                          title: Text(
                            activity.name,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${activity.type} • ${activity.distanceInKm.toStringAsFixed(2)}km • ${activity.movingTimeInMinutes.toStringAsFixed(0)}min\n${activity.startDate.toLocal().toString().split(".")[0].replaceFirst('T', ' ')}',
                            style: TextStyle(color: Colors.white70),
                          ),
                          trailing: isToday && isQualifying
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (isConnected)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Open Strava login page in browser
                        final url = Uri.parse('https://www.strava.com/login');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                        setState(() {
                          statusMessage = 'After logging in or out of Strava in your browser, return here and tap Connect to Strava to sign in with a different account.';
                          isConnected = false;
                        });
                        await _disconnectStrava();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text('Switch Strava Account'),
                    ),
                  ),
                ),
              if (!isConnected)
                Column(
                  children: [
                    if (statusMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Text(
                          statusMessage,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _connectStrava,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text('Connect to Strava'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          widget.onComplete();
          Navigator.pop(context);
        },
        tooltip: 'Test: Register Run as Done',
        child: Icon(Icons.check),
      ),
    );
  }
} 