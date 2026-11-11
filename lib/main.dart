import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'portal_page.dart';

// Notificateur global pour le thème
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  bool isDark = prefs.getBool('is_dark_mode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  final apiKey = prefs.getString('fb_apiKey');
  if (apiKey != null && apiKey.isNotEmpty) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: prefs.getString('fb_appId') ?? '',
        messagingSenderId: prefs.getString('fb_messagingSenderId') ?? '',
        projectId: prefs.getString('fb_projectId') ?? '',
        databaseURL: prefs.getString('fb_databaseURL'),
      ),
    );
  } else {
    // ATTENTION : Remplacez par VOS clés par défaut (celles de votre propre projet Firebase de test)
    // Cela évite un crash au tout premier lancement avant la configuration du créateur.
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "VOTRE_API_KEY_PAR_DEFAUT",
        appId: "VOTRE_APP_ID_PAR_DEFAUT",
        messagingSenderId: "VOTRE_SENDER_ID_PAR_DEFAUT",
        projectId: "VOTRE_PROJET_ID_PAR_DEFAUT",
        databaseURL: "VOTRE_DATABASE_URL_PAR_DEFAUT",
      )
    );
  }

  runApp(const Sirio4App());
}

class Sirio4App extends StatelessWidget {
  const Sirio4App({super.key});
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'SIRIO4 Portail',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(backgroundColor: Colors.white, elevation: 0),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0A0A0A),
            cardColor: const Color(0xFF161616),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
          ),
          themeMode: currentMode,
          home: const AuthGate(),
        );
      }
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF39FF14))));
        }
        return snap.hasData ? const PortalPage() : const LoginPage();
      },
    );
  }
}