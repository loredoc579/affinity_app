// swipe_state.dart
import 'package:equatable/equatable.dart';

abstract class SwipeState extends Equatable {
  const SwipeState();
  @override List<Object?> get props => [];
}

class SwipeInitial extends SwipeState {}

class ProfilesLoading extends SwipeState {}

/// Lista caricata (già filtrata)
class ProfilesLoaded extends SwipeState {
  final List<dynamic> profiles;
  const ProfilesLoaded(this.profiles);
}

/// Errore nel caricamento
class ProfilesError extends SwipeState {
  final String message;
  const ProfilesError(this.message);
}

class SwipeMatched extends SwipeState {
  final String otherUid;
  const SwipeMatched(this.otherUid);
}
