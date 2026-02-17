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

      // 2. Estrazione e Conversione CORRETTA E SICURA
      // Usiamo Map.from anche per la risposta principale per sicurezza totale
      final data = Map<String, dynamic>.from(response.data as Map);
      
      // Prendiamo la lista grezza SENZA usare .cast()
      final rawList = data['profiles'] as List;

      // Convertiamo ogni elemento in modo sicuro
      final List<UserModel> profiles = rawList.map((elemento) {
        // Creiamo una mappa pulita per ogni utente
        final mappaSicura = Map<String, dynamic>.from(elemento as Map);
        return UserModel.fromMap(mappaSicura);
      }).toList();

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