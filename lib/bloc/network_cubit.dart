import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

enum NetworkStatus { unknown, online, offline }

/// Cubit che emette `true`/`false` in base alla reachability di Internet
class NetworkCubit extends Cubit<NetworkStatus> {
  final InternetConnectionChecker _checker;
  late final StreamSubscription<InternetConnectionStatus> _sub;

  NetworkCubit({InternetConnectionChecker? checker})
      : _checker = checker ?? InternetConnectionChecker.createInstance(),
        super(NetworkStatus.unknown) {
    _init();
  }

  Future<void> _init() async {
    // 1️⃣ Test iniziale
    //final has = await _checker.hasConnection;
    final has = true; // Simulazione per test

    debugPrint(' NetworkCubit: hasConnection = $has');

    //emit(has ? NetworkStatus.online : NetworkStatus.offline);
    emit(NetworkStatus.online);

    // 2️⃣ Ascolto i cambiamenti
    _sub = _checker.onStatusChange.listen((status) {
      final st = status == InternetConnectionStatus.connected
        ? NetworkStatus.online
        : NetworkStatus.offline;
      //emit(st);
      emit(NetworkStatus.online);
    });
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
