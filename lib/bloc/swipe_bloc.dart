import 'package:flutter_bloc/flutter_bloc.dart';
import 'swipe_event.dart';
import 'swipe_state.dart';
import '../services/swipe_service.dart';

/// Bloc che gestisce solo il caricamento iniziale e la registrazione dei like/nope/superlike
/// Lascia a CardSwiper il compito di rimuovere visivamente le cards una volta swippate.
class SwipeBloc extends Bloc<SwipeEvent, SwipeState> {
  final SwipeService _service;

  SwipeBloc(this._service) : super(const SwipeLoadSuccess([])) {
    // 1) caricamento iniziale o filtrato
    on<LoadProfiles>((e, emit) {
      emit(SwipeLoadSuccess(List.from(e.profiles)));
    });

    // 2) registra i like senza alterare lo stato della lista
    on<SwipeLike>((e, emit) async {
      try {
        await _service.sendLike(e.userId);
      } catch (err) {
        // opzionale: gestisci errore ma non modifica lista
      }
    });

    on<SwipeNope>((e, emit) async {
      try {
        await _service.sendNope(e.userId);
      } catch (err) {}
    });

    on<SwipeSuperlike>((e, emit) async {
      try {
        await _service.sendSuperlike(e.userId);
      } catch (err) {}
    });
  }
}