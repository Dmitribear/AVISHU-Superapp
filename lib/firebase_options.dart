import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCSWI7N-yF0COyjab4tQ-1SVsZ97-u4NMM',
    appId: '1:784342026466:web:9d3c2dd48dbd5d1bb436bb',
    messagingSenderId: '784342026466',
    projectId: 'avishu',
    authDomain: 'avishu.firebaseapp.com',
    storageBucket: 'avishu.firebasestorage.app',
    measurementId: 'G-6H2T2SMYY5',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDCNn3H4ccXelRE9LsKYJVs7Dl0Z8Cxrig',
    appId: '1:784342026466:ios:afc2e6da093033a0b436bb',
    messagingSenderId: '784342026466',
    projectId: 'avishu',
    storageBucket: 'avishu.firebasestorage.app',
    iosBundleId: 'com.avishu.avishu',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDCNn3H4ccXelRE9LsKYJVs7Dl0Z8Cxrig',
    appId: '1:784342026466:ios:afc2e6da093033a0b436bb',
    messagingSenderId: '784342026466',
    projectId: 'avishu',
    storageBucket: 'avishu.firebasestorage.app',
    iosBundleId: 'com.avishu.avishu',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAlZ4ZG0jXuac8CnDZuPXEjJtUqljhYasg',
    appId: '1:784342026466:android:4750acc606d52054b436bb',
    messagingSenderId: '784342026466',
    projectId: 'avishu',
    storageBucket: 'avishu.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCSWI7N-yF0COyjab4tQ-1SVsZ97-u4NMM',
    appId: '1:784342026466:web:76ef851013f0d349b436bb',
    messagingSenderId: '784342026466',
    projectId: 'avishu',
    authDomain: 'avishu.firebaseapp.com',
    storageBucket: 'avishu.firebasestorage.app',
    measurementId: 'G-Y5PBHKQ285',
  );
}
