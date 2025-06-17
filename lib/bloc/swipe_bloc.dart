import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/swipe_repository.dart';
import 'swipe_event.dart';
import 'swipe_state.dart';
import '../services/swipe_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


/// Bloc che gestisce solo il caricamento iniziale e la registrazione dei like/nope/superlike
/// Ora abilita automaticamente la creazione di chat in caso di match.
class SwipeBloc extends Bloc<SwipeEvent, SwipeState> {
  final SwipeService _service;
  final SwipeRepository _repo;
  final FirebaseAuth _auth;

  SwipeBloc(this._repo, this._auth, this._service) : super(SwipeInitial()){
    // 1) caricamento iniziale o filtrato
    on<LoadProfiles>(_onLoadProfiles);

    // 2) Handle like con logica di match e creazione chat
    on<SwipeLike>((e, emit) async {
      try {
        await _onSwipeLike(e.userId, false, emit);
      } catch (err) {
        emit(ProfilesError('Errore durante lo swipe like: $err'));
      }
    });

    // 3) Handle superlike con logica di match e creazione chat
    on<SwipeSuperlike>((e, emit) async {
      try {
        await _onSwipeLike(e.userId, true, emit);
      } catch (err) {
        emit(ProfilesError('Errore durante lo swipe superlike: $err'));      }
    });

    // 4) Handle nope (nessuna modifica)
    on<SwipeNope>((e, emit) async {
      try {
        await _service.sendNope(e.userId);
      } catch (err) {
        emit(ProfilesError('Errore durante lo swipe nope: $err'));      }
    });
  }

  Future<void> _onLoadProfiles(LoadProfiles event, Emitter<SwipeState> emit) async {
    emit(ProfilesLoading());
    try {
      final me = _auth.currentUser!.uid;

      // 1) prendo i profili già filtrati in UI
      final baseList = event.uiFiltered;

      // 2) applico i filtri “logici” sul baseList (blacklist, swipe oggi, match)
      final filteredByLogic = await _repo.fetchProfiles(uid: me, uiList : baseList);

      emit(ProfilesLoaded(filteredByLogic));
    } catch (e) {
      emit(ProfilesError('Errore nel caricamento: $e'));
    }
  }

  /// Helper generico per aggiungere un tag a tutti i token di un utente
  Future<void> _tagTokensForUser(String uid, String tag) async {
    final tokensRef = FirebaseFirestore.instance.collection('tokens');

    debugPrint('Tagging tokens for user: $uid with tag: $tag');

    final snap = await tokensRef.where('uid', isEqualTo: uid).get();

    debugPrint('Found ${snap.docs.length} tokens for user $uid');

    // Per ogni documento token, un update merge su `tags`
    for (final doc in snap.docs) {
      await doc.reference.set({
        'tags': FieldValue.arrayUnion([tag]),
        'uid': uid,  
      }, SetOptions(merge: true));

      debugPrint('Tagged token ${doc.id} for user $uid with tag $tag');
    }
  }

  Future<void> _onSwipeLike(String otherUid, bool isSuperlike, Emitter<SwipeState> emit) async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final swipesCol = FirebaseFirestore.instance.collection('swipes');

    // 1) Salvo lo swipe nella collezione ‘swipes’
    await swipesCol.add({
      'from': me,
      'to': otherUid,
      'type': isSuperlike ? 'superlike' : 'like',
      'timestamp': FieldValue.serverTimestamp(),
    });

    debugPrint('Swipe saved: $me → $otherUid (${isSuperlike ? 'superlike' : 'like'})');

    // 2) Controllo se esiste uno swipe inverso (match)
    final query = await swipesCol
      .where('from', isEqualTo: otherUid)
      .where('to',   isEqualTo: me)
      .limit(1)
      .get();

    debugPrint('Reverse swipe query: ${query.docs.length} results');

    if (query.docs.isNotEmpty) {
      debugPrint('Match found with $otherUid!');

      // 3) Taggo i token per la chat (senza Cloud Function)
      await Future.wait([
        _tagTokensForUser(me, 'chat'),
        _tagTokensForUser(otherUid, 'chat'),
      ]);

      debugPrint('Tokens tagged for chat: $me, $otherUid');

      // 4) Creo la chat esattamente come prima
      final uids = [me, otherUid]..sort();
      final chatId = '${uids[0]}_${uids[1]}';
      final chatRef = FirebaseFirestore.instance
          .collection('chats').doc(chatId);

      debugPrint('Chat ID: $chatId');

      if (!(await chatRef.get()).exists) {
        await chatRef.set({
          'participants': uids,
          'lastMessage': '',
          'lastUpdated': FieldValue.serverTimestamp(),
          'deleted': false
        });
      }

      debugPrint('Chat created or already exists: $chatId');

      emit(SwipeMatched(otherUid));
      
      debugPrint('SwipeMatched emitted for $otherUid');
    }
  }

}
