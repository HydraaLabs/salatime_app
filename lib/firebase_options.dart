// Public client identifiers from the registered SalaTime Firebase SDK configs.
// iOS uses explicit options; its plist is deliberately not an Xcode resource.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return android;
        case TargetPlatform.iOS:
          return ios;
        default:
          break;
      }
    }
    throw UnsupportedError('SalaTime Analytics is configured for Android/iOS.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyCoJ9I6mS67nN6HkVxV9wvwqDafRPcwkFQ",
    appId: "1:436624512066:android:21645179f0c31400be49db",
    messagingSenderId: "436624512066",
    projectId: "salatime-e3ed1",
    storageBucket: "salatime-e3ed1.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyATvrUcGhisIdXjNZh91NvEcd5Ef_JFLGI",
    appId: "1:436624512066:ios:fcb19652b76b26c4be49db",
    messagingSenderId: "436624512066",
    projectId: "salatime-e3ed1",
    storageBucket: "salatime-e3ed1.firebasestorage.app",
    iosBundleId: "net.salatime.app",
  );
}
