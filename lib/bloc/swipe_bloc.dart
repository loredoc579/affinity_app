import 'package:flutter_bloc/flutter_bloc.dart';
import 'swipe_event.dart';
import 'swipe_state.dart';
import '../services/swipe_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Bloc che gestisce solo il caricamento iniziale e la registrazione dei like/nope/superlike
/// Ora abilita automaticamente la creazione di chat in caso di match.
class SwipeBloc extends Bloc<SwipeEvent, SwipeState> {
  final SwipeService _service;

  SwipeBloc(this._service) : super(const SwipeLoadSuccess([])) {
    // 1) caricamento iniziale o filtrato
    on<LoadProfiles>((e, emit) {
      emit(SwipeLoadSuccess(List.from(e.profiles)));
    });

    // 2) Handle like con logica di match e creazione chat
    on<SwipeLike>((e, emit) async {
      try {
        await _onSwipeLike(e.userId, false, emit);
      } catch (err) {
        // opzionale: gestisci errore
      }
    });

    // 3) Handle superlike con logica di match e creazione chat
    on<SwipeSuperlike>((e, emit) async {
      try {
        await _onSwipeLike(e.userId, true, emit);
      } catch (err) {
        // opzionale: gestisci errore
      }
    });

    // 4) Handle nope (nessuna modifica)
    on<SwipeNope>((e, emit) async {
      try {
        await _service.sendNope(e.userId);
      } catch (err) {
        // opzionale: gestisci errore
      }
    });
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

    // 2) Controllo se esiste uno swipe inverso (match)
    final query = await swipesCol
      .where('from', isEqualTo: otherUid)
      .where('to',   isEqualTo: me)
      .limit(1)
      .get();

    if (query.docs.isNotEmpty) {
      // 3) Creo la chat esattamente come prima
      final uids = [me, otherUid]..sort();
      final chatId = '${uids[0]}_${uids[1]}';
      final chatRef = FirebaseFirestore.instance
          .collection('chats').doc(chatId);

      if (!(await chatRef.get()).exists) {
        await chatRef.set({
          'participants': uids,
          'lastMessage': '',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      emit(SwipeMatched(otherUid));
    }
  }

}
