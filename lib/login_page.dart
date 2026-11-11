import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'register_page.dart';
import 'setup_page.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kCreatorEmail = 'yassinmaalla@gmail.com';
const String kCreatorPass = '12369';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    if (_email.text.trim() == kCreatorEmail && _pass.text == kCreatorPass) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupPage()));
      return; 
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.code == 'user-not-found' ? 'Compte inexistant'
              : (e.code == 'wrong-password' || e.code == 'invalid-credential') ? 'Mot de passe incorrect'
              : 'Erreur : ${e.code}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
    Future<void> _joinWithCode() async {
    TextEditingController codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejoindre avec un code'),
        content: TextField(
          controller: codeController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Collez le code d\'invitation ici...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // 1. On décode le texte Base64
                String jsonString = utf8.decode(base64Decode(codeController.text.trim()));
                Map<String, dynamic> config = jsonDecode(jsonString);

                // 2. On sauvegarde la configuration dans le téléphone
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('fb_apiKey', config['fb_apiKey']);
                await prefs.setString('fb_appId', config['fb_appId']);
                await prefs.setString('fb_messagingSenderId', config['fb_messagingSenderId']);
                await prefs.setString('fb_projectId', config['fb_projectId']);
                await prefs.setString('fb_databaseURL', config['fb_databaseURL']);
                await prefs.setInt('gate_count', config['gate_count']);
                await prefs.setStringList('gate_names', List<String>.from(config['gate_names']));

                // 3. On force la fermeture de l'app pour redémarrer avec la nouvelle config
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('Code accepté ! Redémarrage de l\'application...'),
                  ));
                  await Future.delayed(const Duration(seconds: 2));
                  SystemNavigator.pop(); 
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  backgroundColor: Colors.redAccent,
                  content: Text('Code invalide. Vérifiez que vous avez tout copié.'),
                ));
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) return;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email de réinitialisation envoyé')));
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Remplacement de l'icône par le logo
                Image.asset(
                  'assets/logo.png',
                  width: 200, // Ajustez la taille selon vos préférences
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                // Textes généralisés
                Text('PORTAIL AUTO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 2)),
                const Text('SYSTÈME DE CONTRÔLE', style: TextStyle(fontSize: 12, color: green, letterSpacing: 3)),
                const SizedBox(height: 32),
                const SizedBox(height: 16),
        
                
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AUTHENTIFICATION', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      const Text('EMAIL', style: TextStyle(color: green, fontSize: 10, letterSpacing: 1)),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(hintText: 'operateur@mail.com', hintStyle: const TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(height: 12),
                      const Text('MOT DE PASSE', style: TextStyle(color: green, fontSize: 10, letterSpacing: 1)),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(hintText: '••••••••', hintStyle: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity, height: 46,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('ACCÉDER AU PORTAIL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(child: TextButton(onPressed: _forgot, child: Text('Mot de passe oublié ?', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)))),
                      Center(child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())), child: const Text('Créer un compte', style: TextStyle(color: green, fontSize: 12)))),
                      Center(
                        child: TextButton.icon(
                          onPressed: _joinWithCode,
                          icon: const Icon(Icons.group_add, size: 16, color: Colors.blueAccent),
                          label: const Text('Rejoindre avec un code', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Déveloper par yassinmaalla-max', style: TextStyle(color: isDark ? Colors.white24 : Colors.black38, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_fire_department, color: Colors.orange, size: 12),
                  SizedBox(width: 4),
                  Text('REAL-TIME SYNC ACTIVE', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}