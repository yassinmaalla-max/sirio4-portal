import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'admin_page.dart';

const String kSecret = 'K7xP2mQ9vL4wR8nT';

class PortalPage extends StatefulWidget {
  const PortalPage({super.key});
  @override
  State<PortalPage> createState() => _PortalPageState();
}

class _PortalPageState extends State<PortalPage> {
  bool _sending = false;
  bool _fbConnected = false;
  Map<String, dynamic>? _profile;
  final List<String> _logs = ['> Waiting for command...'];
  StreamSubscription? _connSub;
  StreamSubscription? _profileSub;

  @override
  void initState() {
    super.initState();
    _connSub = FirebaseDatabase.instance.ref('.info/connected').onValue.listen((e) {
      if (mounted) setState(() => _fbConnected = e.snapshot.value == true);
    });
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _profileSub = FirebaseDatabase.instance.ref('users/$uid').onValue.listen((e) async {
      if (!mounted) return;
      if (e.snapshot.value == null) {
        final u = FirebaseAuth.instance.currentUser!;
        await FirebaseDatabase.instance.ref('users/$uid').set({
          'email': u.email,
          'role': 'user',
          'enabled': false,
          'createdAt': ServerValue.timestamp,
        });
      } else {
        setState(() => _profile = Map<String, dynamic>.from(e.snapshot.value as Map));
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _sendCommand() async {
    if (_sending) return;
    final now = DateTime.now();
    setState(() {
      _sending = true;
      _logs.insert(0,
          '> Command ON @ ${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}');
    });
    await FirebaseDatabase.instance.ref('portal/$kSecret/command').set(true);
    await Future.delayed(const Duration(milliseconds: 1000));
    await FirebaseDatabase.instance.ref('portal/$kSecret/command').set(false);
    if (mounted) setState(() => _sending = false);
  }

  Widget _statusLine(String label, bool ok) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: Colors.white70, letterSpacing: 2, fontSize: 12)),
      const SizedBox(width: 8),
      Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: ok ? const Color(0xFF39FF14) : Colors.redAccent)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);

    if (_profile == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: green)));
    }

    if (_profile!['enabled'] != true) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_clock, color: Colors.orange, size: 60),
            const SizedBox(height: 16),
            const Text('Compte en attente\nd\'approbation admin',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Se déconnecter', style: TextStyle(color: green))),
          ]),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SIRIO4', style: TextStyle(color: green, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('PORTAIL INTERFACE', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2)),
                  ]),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white54),
                    onPressed: () {
                      if (_profile?['role'] == 'admin') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage()));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Accès réservé à l\'administrateur')));
                      }
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _sendCommand,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 250, height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: green, width: 3),
                  gradient: RadialGradient(colors: _sending
                      ? [const Color(0xFF1E7A1E), const Color(0xFF0C3B0C)]
                      : [const Color(0xFF123312), const Color(0xFF0A1F0A)]),
                  boxShadow: _sending ? [BoxShadow(color: green.withOpacity(.6), blurRadius: 40)] : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_sending ? 'ON' : 'OFF',
                        style: const TextStyle(color: green, fontSize: 44, fontWeight: FontWeight.bold)),
                    Text(_sending ? 'ACTIVE' : 'STANDBY',
                        style: TextStyle(color: green, fontSize: 13, letterSpacing: 2)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _statusLine('SYSTEM READY', true),
            const SizedBox(height: 6),
            _statusLine('FIREBASE SYNCED', _fbConnected),
            const SizedBox(height: 10),
            const Text('TAP TO DEPLOY PORTAL',
                style: TextStyle(color: Colors.white60, letterSpacing: 2, fontSize: 12)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.terminal, color: green, size: 14),
                      SizedBox(width: 6),
                      Text('CONSOLE OUTPUT', style: TextStyle(color: green, fontSize: 11, letterSpacing: 1)),
                    ]),
                    const SizedBox(height: 8),
                    ..._logs.take(3).map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(l, style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')))),
                    const Text('> Path: /portal/command',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
            TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Back to Login', style: TextStyle(color: green))),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
