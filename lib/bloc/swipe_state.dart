import 'package:equatable/equatable.dart';
import '../models/user_model.dart'; // Importante!

abstract class SwipeState extends Equatable {
  const SwipeState();
  @override
  List<Object?> get props => [];
}

class SwipeInitial extends SwipeState {}

class SwipeLoading extends SwipeState {}

class SwipeLoaded extends SwipeState {
  final List<UserModel> users; // Ora usiamo UserModel!

  const SwipeLoaded({required this.users});

  @override
  List<Object?> get props => [users];
}

class SwipeError extends SwipeState {
  final String message;
  const SwipeError(this.message);
  @override
  List<Object?> get props => [message];
}

class SwipeMatched extends SwipeState {
  final String matchId;     // ID dell'utente con cui hai fatto match
  final String chatRoomId;  // ID della chat creata

  const SwipeMatched({required this.matchId, required this.chatRoomId});
  
  @override
  List<Object?> get props => [matchId, chatRoomId];
}