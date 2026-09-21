import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'admin_page.dart';
import 'wifi_page.dart';

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
  Map<String, dynamic>? _esp;
  final List<String> _logs = ['> Waiting for command...'];
  StreamSubscription? _connSub;
  StreamSubscription? _profileSub;
  StreamSubscription? _espSub;

  bool get _espOnline {
    if (_esp == null || _esp!['lastSeen'] == null) return false;
    final last = _esp!['lastSeen'] as int;
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000) - last < 120;
  }

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
    _espSub = FirebaseDatabase.instance.ref('portal/$kSecret/esp').onValue.listen((e) {
      if (mounted) {
        setState(() => _esp = e.snapshot.value == null
            ? null
            : Map<String, dynamic>.from(e.snapshot.value as Map));
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _profileSub?.cancel();
    _espSub?.cancel();
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
    await Future.delayed(const Duration(milliseconds: 500));
    await FirebaseDatabase.instance.ref('portal/$kSecret/command').set(false);
    if (mounted) setState(() => _sending = false);
  }

  void _openWifiIfAdmin() {
    if (_profile?['role'] == 'admin') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diagnostic réservé à l\'administrateur')));
    }
  }
int _wifiLevel() {
    if (!_espOnline || _esp == null || _esp!['rssi'] == null) return 0;
    final rssi = (_esp!['rssi'] as num).toInt();
    if (rssi >= -50) return 5;
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  Widget _wifiBars() {
    const green = Color(0xFF39FF14);
    final level = _wifiLevel();
    final color = level == 0
        ? Colors.white24
        : (level >= 4
            ? green
            : (level == 3
                ? Colors.lime
                : (level == 2 ? Colors.orange : Colors.redAccent)));
    return Row(mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Container(
            width: 4,
            height: 4.0 + i * 3.5,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: i <= level ? color : Colors.white12,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
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
                  GestureDetector(
                    onTap: _openWifiIfAdmin,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _wifiBars(),
                        const SizedBox(width: 6),
                        Text(
                          _esp?['rssi'] != null ? '${_esp!['rssi']} dBm' : '-- dBm',
                          style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                        ),
                      ]),
                    ),
                  ),
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

            // ---- Bandeau d'alerte si carte hors ligne ----
            if (!_espOnline)
              GestureDetector(
                onTap: _openWifiIfAdmin,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(.6)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text('CARTE HORS LIGNE — toucher pour diagnostiquer',
                        style: TextStyle(color: Colors.orange, fontSize: 11, letterSpacing: 1)),
                  ]),
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
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _openWifiIfAdmin,
              child: _statusLine('CARTE ESP', _espOnline),
            ),
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
                    Row(children: [
                      const Icon(Icons.terminal, color: green, size: 14),
                      const SizedBox(width: 6),
                      const Text('CONSOLE OUTPUT', style: TextStyle(color: green, fontSize: 11, letterSpacing: 1)),
                      const Spacer(),
                      if (_esp != null && _esp!['rssi'] != null)
                        Text('${_esp!['rssi']} dBm',
                            style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
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
