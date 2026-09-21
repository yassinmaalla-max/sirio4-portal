import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'wifi_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Gestion des utilisateurs', style: TextStyle(color: green)),
        iconTheme: const IconThemeData(color: green),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users').onValue,
        builder: (context, snap) {
          if (!snap.hasData || snap.data!.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator(color: green));
          }
          final map = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: const Color(0xFF161616),
                child: ListTile(
                  leading: const Icon(Icons.wifi_tethering, color: Color(0xFF39FF14)),
                  title: const Text('WiFi de la carte ESP', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Reconfigurer si la carte est hors ligne',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const WifiPage())),
                ),
              ),
              ...map.entries.map((e) {
                final uid = e.key;
                final p = Map<String, dynamic>.from(e.value as Map);
                final isMe = uid == myUid;
                return Card(
                  color: const Color(0xFF161616),
                  child: ListTile(
                    title: Text(p['email'] ?? '?', style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      p['role'] == 'admin' ? 'ADMIN' : (p['enabled'] == true ? 'ACTIF' : 'EN ATTENTE'),
                      style: TextStyle(
                        color: p['role'] == 'admin'
                            ? green
                            : (p['enabled'] == true ? Colors.white54 : Colors.orange),
                        fontSize: 11,
                      ),
                    ),
                    trailing: isMe
                        ? const Text('moi', style: TextStyle(color: Colors.white24))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: p['enabled'] == true,
                                activeColor: green,
                                onChanged: (v) => FirebaseDatabase.instance
                                    .ref('users/$uid')
                                    .update({'enabled': v}),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () =>
                                    _confirmDelete(context, uid, p['email'] ?? ''),
                              ),
                            ],
                          ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String uid, String email) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Supprimer l\'accès ?', style: TextStyle(color: Colors.white)),
        content: Text('$email ne pourra plus ouvrir le portail.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              FirebaseDatabase.instance.ref('users/$uid').remove();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
