import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../repository/swipe_repository.dart';
import 'network_cubit.dart';
import 'swipe_event.dart';
import 'swipe_state.dart';
import '../services/swipe_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Bloc che gestisce caricamento e swipe (like/nope/superlike)
class SwipeBloc extends Bloc<SwipeEvent, SwipeState> {
  final SwipeRepository _repo;
  final SwipeService _service;
  final FirebaseAuth _auth;
  bool _isLoading  = false;
  final NetworkCubit _networkCubit;

  SwipeBloc(this._repo, this._auth, this._service, this._networkCubit) : super(SwipeInitial()) {
    // 1) caricamento iniziale o filtrato
    on<LoadProfiles>(_onLoadProfiles);

    // 2) Handle like
    on<SwipeLike>((e, emit) async {
      try {
        await _onSwipeLike(e.userId, isSuper: false, emit: emit);
      } catch (err) {
        emit(ProfilesError('Errore durante lo swipe like: $err'));
      }
    });

    // 3) Handle superlike
    on<SwipeSuperlike>((e, emit) async {
      try {
        await _onSwipeLike(e.userId, isSuper: true, emit: emit);
      } catch (err) {
        emit(ProfilesError('Errore durante lo swipe superlike: $err'));
      }
    });

    // 4) Handle nope
    on<SwipeNope>((e, emit) async {
      try {
        await _service.sendNope(e.userId);
      } catch (err) {
        emit(ProfilesError('Errore durante lo swipe nope: $err'));
      }
    });
  }

  Future<void> _onLoadProfiles(
    LoadProfiles event,
    Emitter<SwipeState> emit,
  ) async {
    if (_isLoading) return;
    _isLoading = true;

    // ① Se non c'è connessione, emetto subito offline
    if (_networkCubit.state == NetworkStatus.offline) {
      debugPrint('⛔ Skip LoadProfiles: offline');
      emit(ProfilesOffline());
      _isLoading = false;
      return;
    }

    // ② Emissione loading o refreshing a seconda dello stato corrente
    if (state is SwipeInitial) {
      emit(ProfilesLoading());
    } else {
      emit(ProfilesRefreshing());
    }

    try {
      final me = _auth.currentUser!.uid;
      final profiles = await _repo.fetchProfiles(
        uid: me,
        uiFilters: event.uiFilters,
        cursor: event.cursor,
        pageSize: event.pageSize,
      );
      emit(ProfilesLoaded(profiles));
    } on FirebaseFunctionsException catch (e) {
      // ③ Se il server risponde unavailable, consideralo offline
      if (e.code == 'unavailable') {
        emit(ProfilesOffline());
      } else {
        debugPrint('⚠️ Functions error: ${e.code} – ${e.message}');
        emit(ProfilesError('Errore nel caricamento: ${e.message ?? e.code}'));
      }
    } catch (e) {
      debugPrint('❌ Errore generico fetchProfiles: $e');
      emit(ProfilesError('Errore imprevisto: $e'));
    } finally {
      _isLoading = false;
    }
  }

  /// Tagga i token di un utente con un tag
  Future<void> _tagTokensForUser(String uid, String tag) async {
    final tokensRef = FirebaseFirestore.instance.collection('tokens');
    debugPrint('Tag tokens di $uid con tag $tag');

    final snap = await tokensRef.where('uid', isEqualTo: uid).get();
    for (final doc in snap.docs) {
      await doc.reference.set({
        'tags': FieldValue.arrayUnion([tag]),
        'uid': uid,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _onSwipeLike(
      String otherUid,
      {required bool isSuper,
      required Emitter<SwipeState> emit}) async {
    final me = _auth.currentUser!.uid;
    final swipesCol = FirebaseFirestore.instance.collection('swipes');

    // Salvo lo swipe
    await swipesCol.add({
      'from': me,
      'to': otherUid,
      'type': isSuper ? 'superlike' : 'like',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Verifico match
    final query = await swipesCol
        .where('from', isEqualTo: otherUid)
        .where('to', isEqualTo: me)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      debugPrint('Match trovato con $otherUid');
      // Tag tokens chat
      await Future.wait([
        _tagTokensForUser(me, 'chat'),
        _tagTokensForUser(otherUid, 'chat'),
      ]);

      // Crea chat se non esiste
      final uids = [me, otherUid]..sort();
      final chatId = '${uids[0]}_${uids[1]}';
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);
      if (!(await chatRef.get()).exists) {
        await chatRef.set({
          'participants': uids,
          'lastMessage': '',
          'lastUpdated': FieldValue.serverTimestamp(),
          'deleted': false,
        });
      }

      emit(SwipeMatched(otherUid));
    }
  }
}
