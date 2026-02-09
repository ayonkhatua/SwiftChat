// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase App.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  // WEB CONFIGURATION (From your provided JS Config)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCWVpgKw9LVr34r7JvxEzycelBtrI7lkEI',
    appId: '1:772140616954:web:6b2db1a880b3d531b60d43',
    messagingSenderId: '772140616954',
    projectId: 'hyper-swift-chat',
    authDomain: 'hyper-swift-chat.firebaseapp.com',
    storageBucket: 'hyper-swift-chat.firebasestorage.app',
    measurementId: 'G-99GQY8T4Q2',
    databaseURL: 'https://hyper-swift-chat-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // ANDROID CONFIGURATION (From your provided JSON)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAG09wmw2SA_EvYHLtuNLoUisLZiyUk6K4',
    appId: '1:772140616954:android:a3c47c6933ccb2dcb60d43',
    messagingSenderId: '772140616954',
    projectId: 'hyper-swift-chat',
    storageBucket: 'hyper-swift-chat.firebasestorage.app',
    databaseURL: 'https://hyper-swift-chat-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}