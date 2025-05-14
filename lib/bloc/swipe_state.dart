// swipe_state.dart
import 'package:equatable/equatable.dart';

abstract class SwipeState extends Equatable {
  const SwipeState();
  @override List<Object?> get props => [];
}

class SwipeInitial extends SwipeState {}

// Quando caricati o aggiornati, qui dentro c’è la lista dei profili da mostrare
class SwipeLoadSuccess extends SwipeState {
  final List<Map<String, dynamic>> profiles;
  const SwipeLoadSuccess(this.profiles);
  @override List<Object?> get props => [profiles];
}

class SwipeProcessing extends SwipeState {}

class SwipeFailure extends SwipeState {
  final String error;
  const SwipeFailure(this.error);
  @override List<Object?> get props => [error];
}
