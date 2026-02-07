import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Repository per ottenere i profili utente tramite Callable Cloud Function
class SwipeRepository {
  final FirebaseFunctions _functions; 

  /// Inietta FirebaseFunctions (utile per mock/test)
  SwipeRepository({FirebaseFunctions? functions,})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Chiama la Cloud Function getProfiles passando uid, filtri UI e cursore per paginazione.
  /// Restituisce la lista di profili già filtrata lato server.
  Future<List<Map<String, dynamic>>> fetchProfiles({
    required String uid,
    Map<String, dynamic>? uiFilters,
    String? cursor,
    int pageSize = 30,
  }) async {
    final callable = _functions.httpsCallable('getProfiles');
    try{

      // 1️⃣ Se il device non ha manco la rete locale
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) {
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Nessuna connessione di rete',
        );
      }

      debugPrint("🟡 CHIAMO getProfiles con: uid=$uid, filters=$uiFilters, cursor=$cursor");
      final response = await callable.call(<String, dynamic>{
        'uid': uid,
        'uiFilters': uiFilters ?? {},
        'cursor': cursor,
        'pageSize': pageSize,
      });

      // Estrai i dati restituiti dalla function
      final data = response.data as Map<String, dynamic>;
      final profiles = (data['profiles'] as List)
          .cast<Map<String, dynamic>>();
      return profiles;
    } on FirebaseFunctionsException catch(e) {
      debugPrint('⚠️ FirebaseFunctionsException: '
          'code=${e.code}, message=${e.message}, details=${e.details}');
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Errore generico fetchProfiles: $e\n$st');
      rethrow;
    }
  }
}
