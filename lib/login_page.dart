import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'register_page.dart';

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

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) return;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de réinitialisation envoyé')));
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: green, width: 3),
                    boxShadow: [BoxShadow(color: green.withOpacity(.5), blurRadius: 30)],
                  ),
                  child: const Icon(Icons.hub, color: green, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('SIRIO4', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text('PORTAIL', style: TextStyle(fontSize: 16, color: green, letterSpacing: 3)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AUTHENTIFICATION', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      const Text('EMAIL', style: TextStyle(color: green, fontSize: 10, letterSpacing: 1)),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: 'operateur@sirio4.com', hintStyle: TextStyle(color: Colors.white24)),
                      ),
                      const SizedBox(height: 12),
                      const Text('MOT DE PASSE', style: TextStyle(color: green, fontSize: 10, letterSpacing: 1)),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: '••••••••', hintStyle: TextStyle(color: Colors.white24)),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity, height: 46,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: green, foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('ACCÉDER AU PORTAIL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(child: TextButton(
                          onPressed: _forgot,
                          child: const Text('Mot de passe oublié ?', style: TextStyle(color: Colors.white54, fontSize: 12)))),
                      Center(child: TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                          child: const Text('Créer un compte', style: TextStyle(color: green, fontSize: 12)))),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Déveloper par yassinmaalla-max', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_fire_department, color: Colors.orange, size: 12),
                  SizedBox(width: 4),
                  Text('REAL-TIME SYNC ACTIVE', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
