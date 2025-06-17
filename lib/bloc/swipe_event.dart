// swipe_event.dart
import 'package:equatable/equatable.dart';

abstract class SwipeEvent extends Equatable {
  const SwipeEvent();
  @override List<Object?> get props => [];
}

class LoadProfiles extends SwipeEvent {
  final List<Map<String, dynamic>> uiFiltered;
  const LoadProfiles(this.uiFiltered);
  @override List<Object?> get props => [uiFiltered];
}

class SwipeLike extends SwipeEvent {
  final String userId;
  const SwipeLike(this.userId);
  @override List<Object?> get props => [userId];
}

class SwipeNope extends SwipeEvent {
  final String userId;
  const SwipeNope(this.userId);
  @override List<Object?> get props => [userId];
}

class SwipeSuperlike extends SwipeEvent {
  final String userId;
  const SwipeSuperlike(this.userId);
  @override List<Object?> get props => [userId];
}
