import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class FilterModel extends ChangeNotifier {
  RangeValues ageRange = const RangeValues(18, 40);
  double maxDistance = 50;
  String gender = 'all';

  FilterModel();

  /// Crea un modello a partire da una mappa (documento Firestore)
  factory FilterModel.fromMap(Map<String, dynamic> data) {
    return FilterModel()
      ..ageRange = RangeValues(
        (data['minAge'] as num?)?.toDouble() ?? 18,
        (data['maxAge'] as num?)?.toDouble() ?? 40,
      )
      ..maxDistance = (data['maxDistance'] as num?)?.toDouble() ?? 50
      ..gender = (data['gender'] as String?) ?? 'all';
  }

  /// Carica i filtri per l'utente [uid] e notifica i listener
  Future<void> loadFromFirestore(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('filters')
        .doc('settings')
        .get();
    if (doc.exists && doc.data() != null) {
      final fm = FilterModel.fromMap(doc.data()!);
      ageRange = fm.ageRange;
      maxDistance = fm.maxDistance;
      gender = fm.gender;
      notifyListeners();
    }
  }

  /// Restituisce true se [profile] e [userPos] soddisfano i filtri
  bool apply(Map<String, dynamic> profile, Position userPos) {
    // 1) Estrai l'età in modo robusto
    double age;
    final rawAge = profile['age'];
    if (rawAge is num) {
      age = rawAge.toDouble();
    } else if (rawAge is String) {
      age = double.tryParse(rawAge) ?? 0;
    } else {
      age = 0;
    }

    // 2) Filtro per età
    if (age < ageRange.start || age > ageRange.end) {
      return false;
    }

    // 3) Filtro per genere
    final rawGender = profile['gender'];
    if (gender != 'all' && rawGender is String && rawGender != gender) {
      return false;
    }

    // 4) Filtro per distanza
    //    Assumo che profile['position'] sia un GeoPoint
    final geo = profile['position'];
    if (geo is! GeoPoint) {
      // se non hai posizione valida, scarta il profilo
      return false;
    }
    final distKm = Geolocator.distanceBetween(
      userPos.latitude, userPos.longitude,
      geo.latitude, geo.longitude,
    ) / 1000;
    if (distKm > maxDistance) {
      return false;
    }

    return true;
  }


  void updateAge(RangeValues v) { ageRange = v; notifyListeners(); }
  void updateDistance(double d) { maxDistance = d; notifyListeners(); }
  void updateGender(String g) { gender = g; notifyListeners(); }
}
