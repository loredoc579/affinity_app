import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:affinity_app/models/user_model.dart'; 

class SwipeRepository {
  final FirebaseFunctions _functions;

  SwipeRepository({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  // MODIFICA QUI: Ora restituisce Future<List<UserModel>> invece di Map
  Future<List<UserModel>> fetchProfiles({
    required String uid,
    Map<String, dynamic>? uiFilters,
    String? cursor,
    int pageSize = 30,
  }) async {
    debugPrint('👉 [3. REPO] Sto per chiamare Firebase. Filtri in mano: $uiFilters');
    final callable = _functions.httpsCallable('getProfiles');
    
    try {
      // 1. Controllo connessione
      final conn = await Connectivity().checkConnectivity();
      if (conn.contains(ConnectivityResult.none)) {
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Nessuna connessione di rete',
        );
      }

      debugPrint("🟡 CHIAMO getProfiles con: uid=$uid, filters=$uiFilters");
      
      final response = await callable.call(<String, dynamic>{
        'uid': uid,
        'uiFilters': uiFilters ?? {},
        'cursor': cursor,
        'pageSize': pageSize,
      });

      if (response.data == null) {
        debugPrint("⚠️ [REPO] Firebase ha risposto NULL");
        return [];
      }

      debugPrint("📦 [REPO] Risposta RAW da Firebase: ${response.data}");

      // 2. Estrazione e Conversione CORRETTA E SICURA
      // Usiamo Map.from anche per la risposta principale per sicurezza totale
      final data = Map<String, dynamic>.from(response.data as Map);
      
      // Prendiamo la lista grezza SENZA usare .cast()
      final rawList = data['profiles'] as List;

      debugPrint("👥 [REPO] Numero profili grezzi trovati: ${rawList.length}");

      // Convertiamo ogni elemento in modo sicuro
      final List<UserModel> profiles = rawList.map((elemento) {
        // Creiamo una mappa pulita per ogni utente
        final mappaSicura = Map<String, dynamic>.from(elemento as Map);
        return UserModel.fromMap(mappaSicura);
      }).toList();

      debugPrint("🎯 [REPO] Conversione completata. Modelli creati: ${profiles.length}");

      return profiles;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ FirebaseFunctionsException: ${e.message}');
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Errore generico fetchProfiles: $e\n$st');
      rethrow;
    }
  }
}