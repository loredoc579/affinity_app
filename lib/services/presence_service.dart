import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages presence by tracking a persistent connection ID per device.
class PresenceService {
  String? _uid;
  String? _connId;
  DatabaseReference? _baseRef;

  /// Aggiorna lo stato online/offline, mantenendo traccia del timestamp
  Future<void> updatePresence({ required bool online }) async {
    if (_uid == null || _connId == null) return;

    final connRef = _baseRef!
      .child('connections')
      .child(_connId!);

    // 1) Configura onDisconnect: se perdi la connessione, imposta subito offline
    //    (invece di rimuovere il nodo, così non cancello connessioni “ripristinate”)
    await connRef.onDisconnect().set({
      'online': false,
      'last_changed': ServerValue.timestamp,
    });

    // 2) Imposta lo stato attuale
    await connRef.set({
      'online': online,
      'last_changed': ServerValue.timestamp,
    });

    // 3) Aggiorna il timestamp globale sotto /status/{uid}/last_changed
    await _baseRef!
      .child('last_changed')
      .set(ServerValue.timestamp);
  }

  /// Call once after the user is authenticated
  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid = user.uid;

    // Reference to /status/{uid}
    _baseRef ??= FirebaseDatabase.instance.ref('status/$_uid');
    final connectionsRef = _baseRef!.child('connections');

    // Retrieve or generate a persistent connection ID for this device
    final prefs = await SharedPreferences.getInstance();
    _connId = prefs.getString('presence_conn_id');
    if (_connId == null) {
      _connId = connectionsRef.push().key;
      if (_connId == null) return;
      await prefs.setString('presence_conn_id', _connId!);
    }

    final connRef = connectionsRef.child(_connId!);
    // Ensure removal of this device node on disconnect
    connRef.onDisconnect().remove();
    // Mark this client as online
    await connRef.set(true);

    // Update last_changed timestamp
    await _baseRef!.child('last_changed').set(ServerValue.timestamp);
  }

  /// Call this in dispose() or when app goes to background
  Future<void> goOffline() async {
    if (_uid == null || _connId == null) return;
    final connectionsRef = _baseRef!.child('connections');
    // Remove only this device's connection
    await connectionsRef.child(_connId!).remove();
    // Update last_changed timestamp
    await _baseRef!.child('last_changed').set(ServerValue.timestamp);
  }

  /// Clears the stored connection ID (e.g., on full logout) so a new one is generated next login
  static Future<void> resetConnId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('presence_conn_id');
  }
}
