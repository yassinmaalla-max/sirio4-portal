import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_page.dart';
import 'main.dart'; // Pour themeNotifier
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

const String kSecret = 'K7xP2mQ9vL4wR8nT';

class PortalPage extends StatefulWidget {
  final bool isPreview;
  const PortalPage({super.key, this.isPreview = false});
  @override
  State<PortalPage> createState() => _PortalPageState();
}

class _PortalPageState extends State<PortalPage> {
  bool _fbConnected = false;
  Map<String, dynamic>? _profile;
  List<String> _gateNames = []; 
  Map<String, bool> _sendingStates = {}; 
  Map<String, Map<String, dynamic>?> _espStates = {};
  List<StreamSubscription> _subscriptions = [];

  bool _isEspOnline(Map<String, dynamic>? esp) {
    if (esp == null || esp['lastSeen'] == null) return false;
    final last = esp['lastSeen'] as int;
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000) - last < 120;
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }
  Future<void> _shareInvitationCode() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. On récupère toute la configuration actuelle
    Map<String, dynamic> config = {
      'fb_apiKey': prefs.getString('fb_apiKey'),
      'fb_appId': prefs.getString('fb_appId'),
      'fb_messagingSenderId': prefs.getString('fb_messagingSenderId'),
      'fb_projectId': prefs.getString('fb_projectId'),
      'fb_databaseURL': prefs.getString('fb_databaseURL'),
      'gate_count': prefs.getInt('gate_count'),
      'gate_names': prefs.getStringList('gate_names'),
    };

    // 2. On transforme ça en texte, puis en code Base64 (pour faire un code secret illisible)
    String jsonString = jsonEncode(config);
    String code = base64Encode(utf8.encode(jsonString));

    // 3. On ouvre le menu de partage
    await Share.share(
      "Rejoins mon portail intelligent !\n\n"
      "1. Installe l'application Portail Auto.\n"
      "2. Clique sur 'Rejoindre avec un code'.\n"
      "3. Colle ce code :\n\n$code",
      subject: 'Invitation Portail Auto',
    );
  }
  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> names = prefs.getStringList('gate_names') ?? ['AVANT', 'ARRIERE'];
    setState(() {
      _gateNames = names;
      for (var name in names) { _sendingStates[name] = false; _espStates[name] = null; }
    });

    if (widget.isPreview) {
      setState(() { _fbConnected = true; _profile = {'role': 'admin', 'enabled': true}; });
      return; 
    }

    _subscriptions.add(FirebaseDatabase.instance.ref('.info/connected').onValue.listen((e) {
      if (mounted) setState(() => _fbConnected = e.snapshot.value == true);
    }));

    final uid = FirebaseAuth.instance.currentUser!.uid;
    _subscriptions.add(FirebaseDatabase.instance.ref('users/$uid').onValue.listen((e) async {
      if (!mounted) return;
      if (e.snapshot.value == null) {
        final u = FirebaseAuth.instance.currentUser!;
        await FirebaseDatabase.instance.ref('users/$uid').set({'email': u.email, 'role': 'user', 'enabled': false, 'createdAt': ServerValue.timestamp});
      } else {
        setState(() => _profile = Map<String, dynamic>.from(e.snapshot.value as Map));
      }
    }));

    for (String gate in _gateNames) {
      String gateId = gate.toLowerCase().replaceAll(' ', '_');
      _subscriptions.add(FirebaseDatabase.instance.ref('portal/$kSecret/$gateId/esp').onValue.listen((e) {
        if (mounted) setState(() => _espStates[gate] = e.snapshot.value == null ? null : Map<String, dynamic>.from(e.snapshot.value as Map));
      }));
    }
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) { sub.cancel(); }
    super.dispose();
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (themeNotifier.value == ThemeMode.dark) { themeNotifier.value = ThemeMode.light; await prefs.setBool('is_dark_mode', false); }
    else { themeNotifier.value = ThemeMode.dark; await prefs.setBool('is_dark_mode', true); }
  }

  Future<void> _sendCommand(String gateName) async {
    if (_sendingStates[gateName] == true) return;
    HapticFeedback.mediumImpact();

    if (widget.isPreview) {
      setState(() => _sendingStates[gateName] = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _sendingStates[gateName] = false);
      return;
    }

    if (!_fbConnected) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('Pas de connexion internet.')));
      return;
    }

    String gateId = gateName.toLowerCase().replaceAll(' ', '_');
    setState(() => _sendingStates[gateName] = true);

    try {
      await FirebaseDatabase.instance.ref('portal/$kSecret/$gateId/command').set(true).timeout(const Duration(seconds: 4));
      await Future.delayed(const Duration(milliseconds: 500));
      await FirebaseDatabase.instance.ref('portal/$kSecret/$gateId/command').set(false).timeout(const Duration(seconds: 4));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.redAccent, content: Text('La carte ESP ne répond pas.')));
    } finally {
      if (mounted) setState(() => _sendingStates[gateName] = false);
    }
  }

  Widget _buildPortalButton(String name, bool isSending, bool online) {
    const green = Color(0xFF39FF14);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _sendCommand(name),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200), width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle, border: Border.all(color: online ? green : Colors.grey, width: 3),
              gradient: RadialGradient(colors: isSending ? (isDark ? [const Color(0xFF1E7A1E), const Color(0xFF0C3B0C)] : [green.withValues(alpha: 0.4), green.withValues(alpha: 0.1)]) : (isDark ? [const Color(0xFF123312), const Color(0xFF0A1F0A)] : [Colors.grey.shade200, Colors.grey.shade100])),
              boxShadow: isSending ? [BoxShadow(color: green.withValues(alpha: isDark ? .6 : .3), blurRadius: 30)] : [],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(isSending ? 'ON' : 'OFF', style: TextStyle(color: online ? (isDark ? green : Colors.black87) : Colors.grey, fontSize: 28, fontWeight: FontWeight.bold)),
              Text(name, style: TextStyle(color: online ? (isDark ? green : Colors.black54) : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('ESP', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10)),
            const SizedBox(width: 4),
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? green : Colors.redAccent)),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    if (!widget.isPreview) {
      if (_profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: green)));
      if (_profile!['enabled'] != true) {
        return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_clock, color: Colors.orange, size: 60),
          const SizedBox(height: 16),
          Text('Compte en attente', style: TextStyle(color: subTextColor)),
          TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Se déconnecter', style: TextStyle(color: green))),
        ])));
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            const Text('Portail Auto', style: TextStyle(color: green, fontSize: 22, fontWeight: FontWeight.bold)),
            Text('INTERFACE DE CONTRÔLE', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10, letterSpacing: 2)),
          ]
        ),
        actions: [
          if (widget.isPreview) const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: Text('MODE TEST', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)))),
          IconButton(icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? green : Colors.black54), onPressed: _toggleTheme),
          IconButton(icon: Icon(Icons.settings, color: subTextColor), onPressed: () {
            if (_profile?['role'] == 'admin' && !widget.isPreview) { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage())); }
          }),
                    IconButton(
            icon: const Icon(Icons.person_add, color: Colors.blueAccent),
            tooltip: 'Inviter un membre',
            onPressed: _shareInvitationCode,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. On utilise Expanded pour prendre tout l'espace au centre
            Expanded(
              child: Center(
                // 2. On ajoute un SingleChildScrollView au cas où il y a beaucoup de portails
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity, // Force la largeur maximale pour bien centrer
                    child: Wrap(
                      spacing: 30, 
                      runSpacing: 30,
                      alignment: WrapAlignment.center, // Centre horizontalement
                      runAlignment: WrapAlignment.center, // Centre verticalement
                      children: _gateNames.map((name) {
                        return _buildPortalButton(
                          name, 
                          _sendingStates[name] ?? false, 
                          widget.isPreview ? true : _isEspOnline(_espStates[name])
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            
            // 3. Les boutons du bas restent fixés en bas
            if (widget.isPreview) 
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('Quitter le mode test', style: TextStyle(color: Colors.orange))
              ),
            if (!widget.isPreview) 
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(), 
                child: const Text('Back to Login', style: TextStyle(color: green))
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}