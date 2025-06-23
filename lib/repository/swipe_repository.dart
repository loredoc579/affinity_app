// lib/repository/swipe_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SwipeRepository {
  final FirebaseFirestore _firestore;
  SwipeRepository(this._firestore);

  /// Restituisce l’insieme di tutti gli userId da escludere:
  /// • match non cancellati (permanenti)  
  /// • cancellazioni avvenute oggi  
  /// • swipe già fatti oggi (in uscita e in entrata)
  Future<Set<String>> _computeExcludedIds(String me) async {
    // 1) Chats → matched & cancellazioni odierne
    final chatSnap = await _firestore
        .collection('chats')
        .where('participants', arrayContains: me)
        .get();

    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final blackList  = <String>{};
    final matched    = <String>{};

    for (var doc in chatSnap.docs) {
      final data = doc.data();
      final parts = List<String>.from(data['participants'] as List);
      final other = parts.firstWhere((id) => id != me);

      final isDeleted  = data['deleted'] == true;
      final delTS      = data['deletedDate'] as Timestamp?;
      if (isDeleted && delTS != null) {
        if (!delTS.toDate().isBefore(startOfDay)) {
          blackList.add(other);
        }
      } else {
        matched.add(other);
      }
    }

    // 2) Swipe di oggi → out + in
    final tsStart = Timestamp.fromDate(startOfDay);
    final outSnap = await _firestore
        .collection('swipes')
        .where('from', isEqualTo: me)
        .where('timestamp', isGreaterThanOrEqualTo: tsStart)
        .get();
    // final inSnap  = await _firestore
    //     .collection('swipes')
    //     .where('to', isEqualTo: me)
    //     .where('timestamp', isGreaterThanOrEqualTo: tsStart)
    //     .get();

    final todaySwiped = <String>{
      for (var d in outSnap.docs) d['to']   as String,
      //for (var d in inSnap.docs)  d['from'] as String,
    };

    return { me, ...blackList, ...matched, ...todaySwiped };
  }

  /// Carica tutti gli utenti da /users, includendo l'uid in ogni Map
  Future<List<Map<String, dynamic>>> _fetchAllUsers() async {
    debugPrint('Fetching all users from Firestore');
    final snap = await _firestore.collection('users').get();
    return snap.docs
      .map((d) => {
        ...d.data(),
        'uid': d.id,
      })
      .toList();
  }

  /// Ritorna la lista di profili finale, applicando:
  /// 1) (opzionale) filtri UI se fornisci `uiList`  
  /// 2) esclusioni logiche di match/swipe/cancellazioni  
  /// Esempi:
  /// • fetchProfiles(uid: me)              → restituisce tutti gli users filtrati solo dalla logica
  /// • fetchProfiles(uid: me, uiList: [...]) → applica prima i filtri UI, poi la logica
  Future<List<Map<String, dynamic>>> fetchProfiles({
    required String uid,
    List<Map<String, dynamic>>? uiList,
  }) async {

    // 1) calcolo gli ID da escludere
    final excluded = await _computeExcludedIds(uid);

    // 2) lista di partenza: tutta (se uiList null) o quella filtrata in UI
    final baseList = uiList ?? await _fetchAllUsers();

    debugPrint('Base list size: ${baseList.length}, Excluded count: ${excluded.length}');

    // 3) ritorno solo gli utenti non esclusi
    var finalList = baseList.where((user) {
      final otherId = user['uid'] as String;
      return !excluded.contains(otherId);
    }).toList();

    debugPrint('Final list size after exclusions: ${finalList.length}');

    return finalList;
  }
}
