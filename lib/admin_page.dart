import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF161616), title: const Text('Gestion des utilisateurs',
          style: TextStyle(color: green)), iconTheme: const IconThemeData(color: green)),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users').onValue,
        builder: (context, snap) {
          if (!snap.hasData || snap.data!.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator(color: green));
          }
          final map = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: map.entries.map((e) {
              final uid = e.key;
              final p = Map<String, dynamic>.from(e.value as Map);
              final isMe = uid == myUid;
              return Card(
                color: const Color(0xFF161616),
                child: ListTile(
                  title: Text(p['email'] ?? '?', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(p['role'] == 'admin' ? 'ADMIN' : (p['enabled'] == true ? 'ACTIF' : 'EN ATTENTE'),
                      style: TextStyle(color: p['role'] == 'admin' ? green : (p['enabled'] == true ? Colors.white54 : Colors.orange), fontSize: 11)),
                  trailing: isMe ? const Text('moi', style: TextStyle(color: Colors.white24)) : Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(value: p['enabled'] == true, activeColor: green,
                        onChanged: (v) => FirebaseDatabase.instance.ref('users/$uid').update({'enabled': v})),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, uid, p['email'] ?? '')),
                  ]),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
