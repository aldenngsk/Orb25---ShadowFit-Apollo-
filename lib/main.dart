import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadowfitdemo/login_page.dart';
import 'package:shadowfitdemo/pages/home_page.dart';
import 'package:shadowfitdemo/pages/running_page.dart';
import 'package:shadowfitdemo/services/firebase_service.dart';
import 'package:shadowfitdemo/services/strava_service.dart';
import 'package:uni_links/uni_links.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Persistent background audio player
class BackgroundMusicPlayer {
  static final BackgroundMusicPlayer _instance = BackgroundMusicPlayer._internal();
  factory BackgroundMusicPlayer() => _instance;
  late final AudioPlayer _player;
  bool _isInitialized = false;
  double _volume = 1.0;

  BackgroundMusicPlayer._internal();

  Future<void> start() async {
    if (_isInitialized) return;
    _player = AudioPlayer();
    await _player.setAsset('assets/audio/music.mp3');
    _player.setLoopMode(LoopMode.one);
    await _loadVolume();
    _player.setVolume(_volume);
    _player.play();
    _isInitialized = true;
  }

  Future<void> _loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble('audio_volume') ?? 1.0;
  }

  Future<void> setVolume(double value) async {
    _volume = value;
    _player.setVolume(_volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('audio_volume', _volume);
  }

  void dispose() {
    _player.dispose();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock app to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  try {
    await FirebaseService.initializeFirebase();
    await StravaService.initialize();
  } catch (e) {
    print("Service initialization error (main): $e");
  }
  // Start background music
  await BackgroundMusicPlayer().start();

  // Check for persistent login
  final user = FirebaseAuth.instance.currentUser;
  final String initialRoute = user != null ? '/home' : '/';

  runApp(MyAppWithInitialRoute(initialRoute: initialRoute));
}

class MyAppWithInitialRoute extends StatelessWidget {
  final String initialRoute;
  const MyAppWithInitialRoute({required this.initialRoute, super.key});

  @override
  Widget build(BuildContext context) {
    return MyApp(initialRoute: initialRoute);
  }
}

class MyApp extends StatefulWidget {
  final String initialRoute;
  const MyApp({super.key, this.initialRoute = '/'});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleIncomingLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final player = BackgroundMusicPlayer()._player;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      player.pause();
    } else if (state == AppLifecycleState.resumed) {
      player.play();
    }
  }

  void _handleIncomingLinks() {
    uriLinkStream.listen((Uri? uri) async {
      if (uri != null && uri.scheme == 'shadowfit' && uri.host == 'oauth' && uri.path == '/callback') {
        final code = uri.queryParameters['code'];
        if (code != null) {
          await StravaService.handleCallback(code);
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => RunningPage(onComplete: () {})),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ShadowFit',
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: const Color.fromARGB(255, 0, 1, 71),
          foregroundColor: Colors.white,
        ),
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: const Color.fromARGB(255, 0, 1, 71),
        cardColor: Colors.black,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      initialRoute: widget.initialRoute,
      routes: {
        '/': (context) => LoginPage(),
        '/home': (context) => HomePage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('shadowfit://') == true) {
          final uri = Uri.parse(settings.name!);
          final code = uri.queryParameters['code'];
          if (code != null) {
            return MaterialPageRoute(
              builder: (context) => FutureBuilder<bool>(
                future: StravaService.handleCallback(code),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Scaffold(
                      backgroundColor: const Color.fromARGB(255, 0, 1, 71),
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return RunningPage(onComplete: () {});
                },
              ),
            );
          }
          return MaterialPageRoute(builder: (context) => RunningPage(onComplete: () {}));
        }
        return null;
      },
    );
  }
}

class AudioControlButton extends StatefulWidget {
  const AudioControlButton({super.key});

  @override
  State<AudioControlButton> createState() => _AudioControlButtonState();
}

class _AudioControlButtonState extends State<AudioControlButton> {
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _volume = BackgroundMusicPlayer()._volume;
  }

  void _showVolumeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.only(top: 0),
              height: 56.0,
              width: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            child: Center(
                child: StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color.fromARGB(255, 0, 1, 71),
                        thumbColor: const Color.fromARGB(255, 0, 1, 71),
                        overlayColor: const Color.fromARGB(100, 0, 1, 71),
                        inactiveTrackColor: Colors.grey[300],
                      ),
                      child: Slider(
                        value: _volume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (value) {
          setState(() {
                            _volume = value;
                          });
                          setStateDialog(() {
                            _volume = value;
                          });
                          BackgroundMusicPlayer().setVolume(_volume);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.music_note),
      onPressed: _showVolumeDialog,
      tooltip: 'Audio Controls',
    );
  }
}


