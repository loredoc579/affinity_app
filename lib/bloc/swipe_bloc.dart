import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../repository/swipe_repository.dart';
import '../services/swipe_service.dart';
import '../models/user_model.dart';
import 'network_cubit.dart';
import 'swipe_event.dart';
import 'swipe_state.dart';

class SwipeBloc extends Bloc<SwipeEvent, SwipeState> {
  final SwipeRepository _repo;
  final SwipeService _service;
  final FirebaseAuth _auth;
  final NetworkCubit _networkCubit;
  
  SwipeBloc(this._repo, this._auth, this._service, this._networkCubit) : super(SwipeInitial()) {
    
    // 1. Caricamento Profili
    on<LoadProfiles>(_onLoadProfiles);

    // 2. Swipe a Destra (Like)
    on<SwipeLike>((event, emit) async {
      await _handleSwipe(event.userId, isSuper: false, emit: emit);
    });

    // 3. Superlike (Da pulsante)
    on<SwipeSuperlike>((event, emit) async {
      await _handleSwipe(event.userId, isSuper: true, emit: emit);
    });

    // 4. Swipe a Sinistra (Nope)
    on<SwipeNope>((event, emit) async {
      try {
        await _service.sendNope(event.userId);
      } catch (e) {
        debugPrint("Errore Nope: $e");
      }
    });
  }

  Future<void> _onLoadProfiles(LoadProfiles event, Emitter<SwipeState> emit) async {
    emit(SwipeLoading());

    debugPrint('👉 [2. BLOC] Ricevuto evento LoadProfiles. Filtri contenuti: ${event.uiFilters}');
    
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        emit(const SwipeError("Utente non loggato"));
        return;
      }

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
    }
  }

  // Logica unificata per Like e Superlike
  Future<void> _handleSwipe(String targetUserId, {required bool isSuper, required Emitter<SwipeState> emit}) async {
    try {
      final myUid = _auth.currentUser!.uid;

      // 1. Scriviamo lo swipe su Firebase USANDO IL SERVICE CORRETTO
      if (isSuper) {
        await _service.sendSuperlike(targetUserId);
      } else {
        await _service.sendLike(targetUserId);
      }

      // 2. Controlliamo se c'è un MATCH
      final swipesCol = FirebaseFirestore.instance.collection('swipes');
      final matchQuery = await swipesCol
          .where('from', isEqualTo: targetUserId)
          .where('to', isEqualTo: myUid)
          .where('type', whereIn: ['like', 'superlike'])
          .limit(1)
          .get();

      if (matchQuery.docs.isNotEmpty) {
        debugPrint("🎉 IT'S A MATCH!");
        
        // 3. Creiamo la chat room
        final chatId = _getChatId(myUid, targetUserId);
        await _createChatIfNeeded(chatId, myUid, targetUserId);
        
        // 4. Emettiamo lo stato di Match
        emit(SwipeMatched(matchId: targetUserId, chatRoomId: chatId));
      }

    } catch (e) {
      debugPrint("Errore Gestione Swipe: $e");
      // Non emettiamo un vero errore che blocca la UI, altrimenti roviniamo l'esperienza utente
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