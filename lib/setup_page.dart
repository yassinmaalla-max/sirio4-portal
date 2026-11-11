import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'portal_page.dart';
import 'login_page.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _apiKey = TextEditingController();
  final _appId = TextEditingController();
  final _messagingSenderId = TextEditingController();
  final _projectId = TextEditingController();
  final _databaseURL = TextEditingController();
  
  int _gateCount = 2;
  List<TextEditingController> _nameControllers = [];
  String _espEmail = '';
  String _espPassword = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _generateNewEspCredentials() {
    setState(() {
      _espEmail = 'esp_${_generateRandomString(6)}@sirio4.com';
      _espPassword = _generateRandomString(10);
    });
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey.text = prefs.getString('fb_apiKey') ?? '';
      _appId.text = prefs.getString('fb_appId') ?? '';
      _messagingSenderId.text = prefs.getString('fb_messagingSenderId') ?? '';
      _projectId.text = prefs.getString('fb_projectId') ?? '';
      _databaseURL.text = prefs.getString('fb_databaseURL') ?? '';
      _gateCount = prefs.getInt('gate_count') ?? 2;
      
      List<String> savedNames = prefs.getStringList('gate_names') ?? ['AVANT', 'ARRIERE', 'JARDIN', 'GARAGE'];
      _updateControllers(savedNames);

      _espEmail = prefs.getString('esp_email') ?? '';
      _espPassword = prefs.getString('esp_password') ?? '';
      if (_espEmail.isEmpty) _generateNewEspCredentials();
    });
  }

  void _updateControllers(List<String> names) {
    _nameControllers = List.generate(_gateCount, (index) {
      String initialName = index < names.length ? names[index] : 'PORTE ${index + 1}';
      return TextEditingController(text: initialName);
    });
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fb_apiKey', _apiKey.text.trim());
    await prefs.setString('fb_appId', _appId.text.trim());
    await prefs.setString('fb_messagingSenderId', _messagingSenderId.text.trim());
    await prefs.setString('fb_projectId', _projectId.text.trim());
    await prefs.setString('fb_databaseURL', _databaseURL.text.trim());
    await prefs.setInt('gate_count', _gateCount);
    await prefs.setString('esp_email', _espEmail);
    await prefs.setString('esp_password', _espPassword);

    List<String> namesToSave = _nameControllers.map((c) => c.text.trim().toUpperCase()).toList();
    await prefs.setStringList('gate_names', namesToSave);
  }

  Future<void> _importFirebaseJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        Map<String, dynamic> json = jsonDecode(await file.readAsString());

        setState(() {
          _projectId.text = json['project_info']?['project_id'] ?? '';
          _databaseURL.text = json['project_info']?['firebase_url'] ?? '';
          _messagingSenderId.text = json['project_info']?['project_number'] ?? '';
          var clientInfo = json['client']?[0];
          _appId.text = clientInfo?['client_info']?['mobilesdk_app_id'] ?? '';
          _apiKey.text = clientInfo?['api_key']?[0]?['current_key'] ?? '';
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('Config Firebase importée !')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Erreur : $e')));
    }
  }

  Future<void> _generateArduinoCode() async {
    await _saveConfig(); 
    String fullCode = "";
    
    for (int i = 0; i < _gateCount; i++) {
      String gateName = _nameControllers[i].text.trim().toUpperCase();
      String gateId = gateName.toLowerCase().replaceAll(' ', '_');
      String apSsid = "Portail-$gateName";

      fullCode += """
// =========================================================
// CODE ARDUINO POUR : $gateName (ID: $gateId)
// =========================================================
#include <ESP8266WiFi.h>
#include <WiFiManager.h>
#include <Firebase_ESP_Client.h>
#include <ArduinoOTA.h> // <-- AJOUT OTA
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

#define API_KEY "${_apiKey.text.trim()}"
#define DATABASE_URL "${_databaseURL.text.trim()}"
#define USER_EMAIL "$_espEmail" 
#define USER_PASSWORD "$_espPassword" 
#define GATE_ID "$gateId"
#define OPTO_PIN 5 // GPIO5 (D1)

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
unsigned long sendDataPrevMillis = 0;

void setup() {
  Serial.begin(115200);
  pinMode(OPTO_PIN, OUTPUT);
  digitalWrite(OPTO_PIN, LOW);

  // 1. Connexion WiFi
  WiFiManager wm;
  wm.setConfigPortalTimeout(180); // Timeout de 3 minutes pour éviter de bloquer
  bool res = wm.autoConnect("$apSsid", "config1234");
  if(!res) { ESP.restart(); }
  
  Serial.println("Connecte au WiFi !");

  // 2. Configuration OTA (Mise à jour sans fil)
  ArduinoOTA.setHostname("$apSsid"); 
  ArduinoOTA.setPassword("admin123"); // Mot de passe pour sécuriser la MAJ
  ArduinoOTA.begin();
  Serial.println("OTA pret. IP: " + WiFi.localIP().toString());

  // 3. Connexion Firebase
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
}

void loop() {
  // Écoute des demandes de mise à jour OTA
  ArduinoOTA.handle();

  if (Firebase.ready()) {
    // Écoute de la commande
    String commandPath = "/portal/$kSecret/" + String(GATE_ID) + "/command";
    if (Firebase.RTDB.getBool(&fbdo, commandPath)) {
      if (fbdo.boolData() == true) {
        Serial.println("Impulsion envoyee !");
        digitalWrite(OPTO_PIN, HIGH);
        delay(500);
        digitalWrite(OPTO_PIN, LOW);
        Firebase.RTDB.setBool(&fbdo, commandPath, false);
      }
    }

    // Mise a jour de l'etat
    if (millis() - sendDataPrevMillis > 30000 || sendDataPrevMillis == 0) {
      sendDataPrevMillis = millis();
      FirebaseJson json;
      json.set("lastSeen", (int)time(nullptr));
      json.set("rssi", WiFi.RSSI());
      json.set("ip", WiFi.localIP().toString());
      String espPath = "/portal/$kSecret/" + String(GATE_ID) + "/esp";
      Firebase.RTDB.updateNode(&fbdo, espPath, &json);
    }
  }
  delay(100);
}
// =========================================================
\n\n""";
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Code_Arduino_Portails.txt');
    await file.writeAsString(fullCode);
    await Share.shareXFiles([XFile(file.path)], text: 'Code Arduino pour les portails.');
  }

  void _showConfigGuide() {
    const green = Color(0xFF39FF14);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.85, maxChildSize: 0.95,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
               const Center(child: Text('GUIDE D\'INSTALLATION', style: TextStyle(color: green, fontSize: 18, fontWeight: FontWeight.bold))),
               const SizedBox(height: 20),
               _buildGuideStep('1', 'Console Firebase', 'Créez le projet, ajoutez une app Android et importez le JSON ici.'),
               _buildGuideStep('2', 'Auth Firebase', 'Activez E-mail/Mot de passe.\n\nEMAIL : $_espEmail\nPASS : $_espPassword'),
               _buildGuideStep('3', 'Realtime DB', 'Règles : {"rules": {".read": "auth != null",".write": "auth != null"}}'),
               _buildGuideStep('4', 'Arduino IDE', 'Installez WiFiManager, Firebase ESP Client, ArduinoJson.'),
               _buildGuideStep('5', 'Téléversement', 'Ouvrez le code généré et téléversez sur l\'ESP.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideStep(String step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 15, backgroundColor: const Color(0xFF39FF14), child: Text(step, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF39FF14);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration Créateur', style: TextStyle(color: green)), actions: [
        IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())))
      ]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _importFirebaseJson, icon: const Icon(Icons.upload_file, size: 18), label: const Text('IMPORTER JSON'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(onPressed: _showConfigGuide, icon: const Icon(Icons.help_outline, size: 18), label: const Text('GUIDE'), style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent))),
          ]),
          const SizedBox(height: 20),
          const Text('Paramètres Firebase', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          _buildField(_apiKey, 'API Key'), _buildField(_appId, 'App ID'), _buildField(_messagingSenderId, 'Sender ID'), _buildField(_projectId, 'Project ID'), _buildField(_databaseURL, 'Database URL'),
          const Divider(color: Colors.white24, height: 40),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Compte ESP', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            TextButton.icon(onPressed: _generateNewEspCredentials, icon: const Icon(Icons.refresh, size: 16, color: green), label: const Text('Régénérer', style: TextStyle(color: green, fontSize: 12)))
          ]),
          Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('EMAIL : $_espEmail', style: const TextStyle(color: green, fontSize: 13)),
              Text('PASS : $_espPassword', style: const TextStyle(color: green, fontSize: 13)),
            ]),
          ),
          const Divider(color: Colors.white24, height: 40),
          const Text('Paramètres des Portails', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Nombre :', style: TextStyle(color: Colors.white)),
            DropdownButton<int>(value: _gateCount, dropdownColor: const Color(0xFF161616), style: const TextStyle(color: green), items: [1, 2, 3, 4].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(), onChanged: (v) { setState(() { _gateCount = v!; _updateControllers(_nameControllers.map((e) => e.text).toList()); }); }),
          ]),
          ...List.generate(_gateCount, (index) => _buildField(_nameControllers[index], 'Nom du portail ${index + 1}')),
          const SizedBox(height: 30),
          Row(children: [
                          Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _saveConfig();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 10),
                              Text('Configuration sauvegardée avec succès !'),
                            ],
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('SAUVEGARDER'),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(onPressed: () async { await _saveConfig(); if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const PortalPage(isPreview: true))); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('TESTER', style: TextStyle(color: Colors.black)))),
          ]),
          const SizedBox(height: 20),
          ElevatedButton.icon(onPressed: _generateArduinoCode, icon: const Icon(Icons.code), label: const Text('GÉNÉRER LE CODE ARDUINO'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 16))),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Color(0xFF39FF14)), enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF39FF14))))));
  }
}