import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text);
      final uid = cred.user!.uid;
      final usersRef = FirebaseDatabase.instance.ref('users');
      final first = !(await usersRef.get()).exists; // si aucun profil : devient admin
      await usersRef.child(uid).set({
        'email': _email.text.trim(),
        'role': first ? 'admin' : 'user',
        'enabled': first,
        'createdAt': ServerValue.timestamp,
      });
      if (!first) await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(first
                ? 'Compte ADMIN créé'
                : 'Compte créé : en attente d\'approbation par l\'admin')));
        if (!first) Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : ${e.code}')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white), title: const Text('Nouveau compte')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          TextField(controller: _email, keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: green))),
          TextField(controller: _pass, obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Mot de passe (6 min)', labelStyle: TextStyle(color: green))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 46,
            child: ElevatedButton(onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.black),
              child: const Text('CRÉER LE COMPTE'))),
        ]),
      ),
    );
  }
}
