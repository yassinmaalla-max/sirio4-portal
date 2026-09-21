import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'portal_page.dart' show kSecret;

class WifiPage extends StatefulWidget {
  const WifiPage({super.key});
  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  Map<String, dynamic>? _esp;

  bool get _online {
    if (_esp == null || _esp!['lastSeen'] == null) return false;
    final last = (_esp!['lastSeen'] as int);
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000) - last < 120;
  }

  @override
  void initState() {
    super.initState();
    FirebaseDatabase.instance.ref('portal/$kSecret/esp').onValue.listen((e) {
      if (mounted) {
        setState(() => _esp = e.snapshot.value == null
            ? null
            : Map<String, dynamic>.from(e.snapshot.value as Map));
      }
    });
  }

  Future<void> _joinCardAp() async {
    final ok = await WiFiForIoTPlugin.connect(
      "Portail-SIRIO4",
      password: "config1234",
      joinOnce: false,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? "Connecté à la carte — ouvrez le configurateur"
              : "Échec auto : rejoignez 'Portail-SIRIO4' manuellement dans les réglages WiFi")));
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF161616),
          title: const Text('WiFi de la carte', style: TextStyle(color: green)),
          iconTheme: const IconThemeData(color: green)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // ---- État de la carte ----
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.circle, color: _online ? green : Colors.redAccent, size: 14),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_online ? 'CARTE EN LIGNE' : 'CARTE HORS LIGNE',
                  style: TextStyle(color: _online ? green : Colors.redAccent, fontWeight: FontWeight.bold)),
              if (_esp != null) ...[
                Text('RSSI : ${_esp!['rssi'] ?? '?'} dBm   IP : ${_esp!['ip'] ?? '?'}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 24),

        if (!_online) ...[
          const Text('PROCÉDURE DE RECONFIGURATION',
              style: TextStyle(color: Colors.white70, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 12),
          const Text('1. La carte émet le réseau « Portail-SIRIO4 » (sinon maintenez le bouton FLASH 5 s).',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, height: 46,
            child: ElevatedButton.icon(
              onPressed: _joinCardAp,
              style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.black),
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('2. CONNECTER LE TÉLÉPHONE À LA CARTE'))),
          const SizedBox(height: 6),
          const Text('3. Ouvrez le configurateur et choisissez votre nouveau WiFi :',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, height: 46,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _PortalWebView())),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: green), foregroundColor: green),
              icon: const Icon(Icons.settings_ethernet),
              label: const Text('OUVRIR LE CONFIGURATEUR (192.168.4.1)'))),
          const SizedBox(height: 12),
          const Text('Après enregistrement, la carte redémarre, le téléphone revient au WiFi '
              'domestique et l\'état repasse EN LIGNE ici même.',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ] else
          const Text('La carte est connectée. Aucune action nécessaire.',
              style: TextStyle(color: Colors.white54)),
      ]),
    );
  }
}

// ---- Portail captif WiFiManager DANS l'app ----
class _PortalWebView extends StatefulWidget {
  const _PortalWebView();
  @override
  State<_PortalWebView> createState() => _PortalWebViewState();
}

class _PortalWebViewState extends State<_PortalWebView> {
  late final WebViewController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('http://192.168.4.1'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xFF161616),
            title: const Text('Config WiFi carte', style: TextStyle(color: Color(0xFF39FF14))),
            iconTheme: const IconThemeData(color: Color(0xFF39FF14))),
        body: WebViewWidget(controller: _ctrl),
      );
}
