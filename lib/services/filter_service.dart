import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/filter_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FilterService {
    /// Carica da Firestore i filtri salvati per [uid]
  /// e li applica al [filterModel].
  static Future<void> loadFiltersForUser(
    FilterModel filterModel,
    String uid,
  ) async {
    final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('filters')
      .doc('settings')
      .get();

    if (!doc.exists || doc.data() == null) return;
    final data = doc.data()!;

    // Seleziono i campi nel modello
    if (data['minAge'] != null && data['maxAge'] != null) {
      filterModel.updateAge(RangeValues(
        (data['minAge'] as num).toDouble(),
        (data['maxAge'] as num).toDouble(),
      ));
    }
    if (data['maxDistance'] != null) {
      filterModel.updateDistance((data['maxDistance'] as num).toDouble());
    }
    if (data['gender'] is String) {
      filterModel.updateGender(data['gender'] as String);
    }
  }
  
  /// Restituisce la lista di profili che superano i filtri.
  static List<Map<String, dynamic>> applyFilters(
    List<Map<String, dynamic>> profiles,
    FilterModel filter,
    Position userPos,
  ) {

    return profiles.where((profile) {
      // ETÀ
      final rawAge = profile['age'];
      final age = rawAge is num
          ? rawAge.toDouble()
          : double.tryParse('$rawAge') ?? 0.0;
      if (age < filter.ageRange.start || age > filter.ageRange.end) {
        return false;
      }

      // GENERE
      final genderVal = profile['gender']?.toString() ?? '';
      if (filter.gender != 'all' && genderVal != filter.gender) {
        return false;
      }

      // POSIZIONE
      final loc = profile['location'] as Map<String, dynamic>?;

      if (loc == null || loc['position'] is! GeoPoint) return false;
      final geo = loc['position'] as GeoPoint;

      // Ora puoi usarlo in Geolocator.distanceBetween
      final distKm = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        geo.latitude,
        geo.longitude,
      ) / 1000;

      if (distKm > filter.maxDistance) {
        return false;
      }

      return true;
    }).toList();
  }
}
