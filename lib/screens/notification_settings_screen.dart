import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Impostazioni di default
  bool newMatches = true;
  bool newMessages = true;
  bool superLikes = true;
  bool marketing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && doc.data()!.containsKey('notificationPrefs')) {
      final prefs = doc.data()!['notificationPrefs'] as Map<String, dynamic>;
      setState(() {
        newMatches = prefs['newMatches'] ?? true;
        newMessages = prefs['newMessages'] ?? true;
        superLikes = prefs['superLikes'] ?? true;
        marketing = prefs['marketing'] ?? false;
      });
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Aggiorniamo solo il campo specifico dentro la mappa "notificationPrefs"
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'notificationPrefs': {key: value}
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifiche Push", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("INTERAZIONI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          SwitchListTile(
            activeColor: Colors.pink,
            title: const Text("Nuovi Match"),
            subtitle: const Text("Ricevi una notifica quando piaci a qualcuno che ti piace."),
            value: newMatches,
            onChanged: (val) {
              setState(() => newMatches = val);
              _saveSetting('newMatches', val);
            },
          ),
          SwitchListTile(
            activeColor: Colors.pink,
            title: const Text("Nuovi Messaggi"),
            value: newMessages,
            onChanged: (val) {
              setState(() => newMessages = val);
              _saveSetting('newMessages', val);
            },
          ),
          SwitchListTile(
            activeColor: Colors.pink,
            title: const Text("Superlike"),
            subtitle: const Text("Scopri subito chi ha un forte interesse per te."),
            value: superLikes,
            onChanged: (val) {
              setState(() => superLikes = val);
              _saveSetting('superLikes', val);
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("ALTRO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          SwitchListTile(
            activeColor: Colors.pink,
            title: const Text("Promozioni e Novità"),
            subtitle: const Text("Offerte esclusive sugli abbonamenti Premium."),
            value: marketing,
            onChanged: (val) {
              setState(() => marketing = val);
              _saveSetting('marketing', val);
            },
          ),
        ],
      ),
    );
  }
}