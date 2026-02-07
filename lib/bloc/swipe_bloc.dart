import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../repository/swipe_repository.dart';
import '../services/swipe_service.dart';
import '../models/user_model.dart'; // <--- NUOVO IMPORT
import 'network_cubit.dart';
import 'swipe_event.dart';
import 'swipe_state.dart';

class SwipeBloc extends Bloc<SwipeEvent, SwipeState> {
  final SwipeRepository _repo;
  final SwipeService _service;
  final FirebaseAuth _auth;
  final NetworkCubit _networkCubit;
  
  bool _isLoading = false;

  SwipeBloc(this._repo, this._auth, this._service, this._networkCubit) : super(SwipeInitial()) {
    
    // 1. Caricamento Profili
    on<LoadProfiles>(_onLoadProfiles);

    // 2. Swipe a Destra (Like)
    on<SwipeLike>((event, emit) async {
      await _handleSwipe(event.userId, isLike: true, isSuper: false, emit: emit);
    });

    // 3. Superlike
    on<SwipeSuperlike>((event, emit) async {
      await _handleSwipe(event.userId, isLike: true, isSuper: true, emit: emit);
    });

    // 4. Swipe a Sinistra (Nope)
    on<SwipeNope>((event, emit) async {
      try {
        // Usiamo il service per il nope (più pulito)
        await _service.sendNope(event.userId);
      } catch (e) {
        debugPrint("Errore Nope: $e");
        // Non emettiamo errore per un nope fallito, l'utente non deve accorgersene
      }
    });
  }

  Future<void> _onLoadProfiles(LoadProfiles event, Emitter<SwipeState> emit) async {
    if (_isLoading) return;
    _isLoading = true;
    emit(SwipeLoading());

    try {
      // Controllo rete
      /* Nota: Se il NetworkCubit non è ancora inizializzato o non aggiornato, 
         potresti voler saltare questo check o gestirlo diversamente */
      // if (_networkCubit.state == NetworkStatus.offline) {
      //   emit(const SwipeError("Nessuna connessione internet"));
      //   return;
      // }

      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        emit(const SwipeError("Utente non loggato"));
        return;
      }

      // ORA REPO RESTITUISCE LIST<USERMODEL> ✅
      final List<UserModel> users = await _repo.fetchProfiles(
        uid: uid,
        uiFilters: event.uiFilters,
        cursor: event.cursor,
        pageSize: event.pageSize,
      );

      emit(SwipeLoaded(users: users));

    } on FirebaseFunctionsException catch (e) {
      emit(SwipeError("Errore Server: ${e.message}"));
    } catch (e) {
      emit(SwipeError("Errore generico: $e"));
    } finally {
      _isLoading = false;
    }
  }

  // Logica unificata per Like e Superlike
  Future<void> _handleSwipe(String targetUserId, {required bool isLike, required bool isSuper, required Emitter<SwipeState> emit}) async {
    try {
      final myUid = _auth.currentUser!.uid;
      final swipesCol = FirebaseFirestore.instance.collection('swipes');

      // 1. Scriviamo lo swipe su Firebase
      await swipesCol.add({
        'from': myUid,
        'to': targetUserId,
        'type': isSuper ? 'superlike' : 'like',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Controlliamo se c'è un MATCH (se anche l'altro mi ha messo like)
      // Cerchiamo un documento dove 'from' è LUI e 'to' sono IO
      final matchQuery = await swipesCol
          .where('from', isEqualTo: targetUserId)
          .where('to', isEqualTo: myUid)
          .where('type', whereIn: ['like', 'superlike']) // Accettiamo sia like che superlike
          .limit(1)
          .get();

      if (matchQuery.docs.isNotEmpty) {
        debugPrint("🎉 IT'S A MATCH!");
        
        // 3. Creiamo la chat room
        final chatId = _getChatId(myUid, targetUserId);
        
        await _createChatIfNeeded(chatId, myUid, targetUserId);
        
        // 4. Emettiamo lo stato di Match (la UI mostrerà il popup "It's a Match")
        emit(SwipeMatched(matchId: targetUserId, chatRoomId: chatId));
        
        // Importante: Dopo il match, ricarichiamo lo stato precedente (la lista utenti)
        // Altrimenti la UI rimarrebbe bloccata sulla schermata di match
        // Nota: In una implementazione reale, potresti voler rimuovere solo l'utente swipato dalla lista locale
      }

    } catch (e) {
      debugPrint("Errore Swipe: $e");
      emit(SwipeError("Impossibile inviare il like: $e"));
    }
  }

  // Genera un ID univoco per la chat (sempre uguale per la stessa coppia)
  String _getChatId(String userA, String userB) {
    return userA.compareTo(userB) < 0 ? '${userA}_$userB' : '${userB}_$userA';
  }

  Future<void> _createChatIfNeeded(String chatId, String uid1, String uid2) async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final doc = await chatRef.get();
    
    if (!doc.exists) {
      await chatRef.set({
        'participants': [uid1, uid2],
        'lastMessage': "Nuovo Match! Salutatevi 👋",
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [],
      });
    }
  }
}