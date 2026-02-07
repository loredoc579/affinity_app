// swipe_event.dart
import 'package:equatable/equatable.dart';

abstract class SwipeEvent extends Equatable {
  const SwipeEvent();
  @override List<Object?> get props => [];
}

/// Event per caricare la “pagina” di profili:
/// - uiFilters: mappa di filtri lato UI (es. gender, ageFrom…)
/// - cursor: cursore per paginazione (l’ultimo uid restituito)
/// - pageSize: quanti profili richiedere per volta
class LoadProfiles extends SwipeEvent {
  final Map<String, dynamic>? uiFilters;
  final String? cursor;
  final int pageSize;

  const LoadProfiles({
    this.uiFilters,
    this.cursor,
    this.pageSize = 30,
  });
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
