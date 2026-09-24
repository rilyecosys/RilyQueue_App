// File generated for RileyQueue's Firebase Web integration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwjuI1ZrVDaCt0HlRmXZvhKizcMLz5UjQ',
    appId: '1:155286452431:android:e99770f0a5d41400055fba',
    messagingSenderId: '155286452431',
    projectId: 'rilygov2-941ee',
    storageBucket: 'rilygov2-941ee.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAwjuI1ZrVDaCt0HlRmXZvhKizcMLz5UjQ',
    authDomain: 'rilygov2-941ee.firebaseapp.com',
    projectId: 'rilygov2-941ee',
    storageBucket: 'rilygov2-941ee.firebasestorage.app',
    messagingSenderId: '155286452431',
    appId: '1:155286452431:android:e99770f0a5d41400055fba',
  );
}
