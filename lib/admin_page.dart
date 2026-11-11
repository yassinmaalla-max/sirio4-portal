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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des utilisateurs', style: TextStyle(color: green)), iconTheme: const IconThemeData(color: green)),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users').onValue,
        builder: (context, snap) {
          if (!snap.hasData || snap.data!.snapshot.value == null) return const Center(child: CircularProgressIndicator(color: green));
          final map = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: cardColor,
                child: Column(children: [
                  ListTile(leading: const Icon(Icons.wifi_tethering, color: green), title: Text('WiFi Carte AVANT', style: TextStyle(color: textColor)), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiPage(gate: 'avant')))),
                  const Divider(height: 1),
                  ListTile(leading: const Icon(Icons.wifi_tethering, color: green), title: Text('WiFi Carte ARRIÈRE', style: TextStyle(color: textColor)), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiPage(gate: 'arriere')))),
                ]),
              ),
              const SizedBox(height: 10),
              ...map.entries.map((e) {
                final uid = e.key;
                final p = Map<String, dynamic>.from(e.value as Map);
                final isMe = uid == myUid;
                return Card(
                  color: cardColor,
                  child: ListTile(
                    title: Text(p['email'] ?? '?', style: TextStyle(color: textColor)),
                    subtitle: Text(p['role'] == 'admin' ? 'ADMIN' : (p['enabled'] == true ? 'ACTIF' : 'EN ATTENTE'), style: TextStyle(color: p['role'] == 'admin' ? green : (p['enabled'] == true ? Colors.grey : Colors.orange), fontSize: 11)),
                    trailing: isMe ? const Text('moi', style: TextStyle(color: Colors.grey)) : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.manage_accounts, color: Colors.blueAccent), onPressed: () => _showRoleDialog(context, uid, p['role'] ?? 'user')),
                        Switch(value: p['enabled'] == true, activeThumbColor: green, onChanged: (v) => FirebaseDatabase.instance.ref('users/$uid').update({'enabled': v})),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _confirmDelete(context, uid, p['email'] ?? '')),
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

  void _showRoleDialog(BuildContext context, String uid, String currentRole) {
    const green = Color(0xFF39FF14);
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: const Text('Modifier le rôle'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.admin_panel_settings, color: green), title: const Text('Administrateur'), trailing: currentRole == 'admin' ? const Icon(Icons.check, color: green) : null, onTap: () { FirebaseDatabase.instance.ref('users/$uid').update({'role': 'admin', 'enabled': true}); Navigator.pop(context); }),
        ListTile(leading: const Icon(Icons.person, color: Colors.grey), title: const Text('Utilisateur'), trailing: currentRole == 'user' ? const Icon(Icons.check, color: green) : null, onTap: () { FirebaseDatabase.instance.ref('users/$uid').update({'role': 'user'}); Navigator.pop(context); }),
      ]),
    ));
  }

  void _confirmDelete(BuildContext context, String uid, String email) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: const Text('Supprimer l\'accès ?'),
      content: Text('$email ne pourra plus ouvrir le portail.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(onPressed: () { FirebaseDatabase.instance.ref('users/$uid').remove(); Navigator.pop(context); }, child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent))),
      ],
    ));
  }
}