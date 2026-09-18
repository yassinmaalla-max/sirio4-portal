import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCawsxNUbM_e1pzFwtqLCI3iUVhXvr0DQY',
    appId: '1:880115580049:android:0c309cc95c4a7fb95f9330',
    messagingSenderId: '880115580049',
    projectId: 'portail-sirio4',
    databaseURL: 'https://portail-sirio4-default-rtdb.europe-west1.firebasedatabase.app',
  );
}