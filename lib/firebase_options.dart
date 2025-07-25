import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATPZhrsNYQ7tW1WfQXTPTptsXN1_VU-ds',
    appId: '1:130002456581:android:cc6b3470c4ca3396a44c6c',
    messagingSenderId: '130002456581',
    projectId: 'shadowfit-538aa',
    storageBucket: 'shadowfit-538aa.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAW9aRH1_PvW7-WJdGzxbeYbWM2kpiSuqE',
    appId: '1:130002456581:ios:649b6f0ce1d2d1daa44c6c',
    messagingSenderId: '130002456581',
    projectId: 'shadowfit-538aa',
    storageBucket: 'shadowfit-538aa.firebasestorage.app',
    iosBundleId: 'com.example.shadowfitdemo',
  );
}
