import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'portal_page.dart' show kSecret;

class WifiPage extends StatefulWidget {
  final String gate;
  const WifiPage({super.key, required this.gate});
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
    FirebaseDatabase.instance.ref('portal/$kSecret/${widget.gate}/esp').onValue.listen((e) {
      if (mounted) setState(() => _esp = e.snapshot.value == null ? null : Map<String, dynamic>.from(e.snapshot.value as Map));
    });
  }

  Future<void> _joinCardAp() async {
    String ssid = widget.gate == 'avant' ? "Portail-AVANT" : "Portail-ARRIERE";
    final ok = await WiFiForIoTPlugin.connect(ssid, password: "config1234", joinOnce: false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? "Connecté à $ssid" : "Échec auto : rejoignez '$ssid' manuellement")));
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);
    String ssid = widget.gate == 'avant' ? "Portail-SIRIO4-AVANT" : "Portail-SIRIO4-ARRIERE";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('WiFi Porte ${widget.gate.toUpperCase()}', style: const TextStyle(color: green)), iconTheme: const IconThemeData(color: green)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.circle, color: _online ? green : Colors.redAccent, size: 14),
            const SizedBox(width: 10),
            Text(_online ? 'CARTE EN LIGNE' : 'CARTE HORS LIGNE', style: TextStyle(color: _online ? green : Colors.redAccent, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 24),
        if (!_online) ...[
          Text('PROCÉDURE DE RECONFIGURATION', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 12),
          Text('1. La carte émet le réseau « $ssid ».', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(onPressed: _joinCardAp, style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.black), icon: const Icon(Icons.wifi_tethering), label: Text('2. CONNECTER À $ssid'))),
          const SizedBox(height: 6),
          Text('3. Ouvrez le configurateur :', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _PortalWebView())), style: OutlinedButton.styleFrom(side: const BorderSide(color: green), foregroundColor: green), icon: const Icon(Icons.settings_ethernet), label: const Text('OUVRIR (192.168.4.1)'))),
        ] else
          const Text('La carte est connectée.', style: TextStyle(color: Colors.grey)),
      ]),
    );
  }
}

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
    _ctrl = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadRequest(Uri.parse('http://192.168.4.1'));
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Config WiFi')), body: WebViewWidget(controller: _ctrl));
}