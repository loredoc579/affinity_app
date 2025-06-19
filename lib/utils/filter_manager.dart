import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../models/filter_model.dart';
import '../widgets/filter_sheet.dart';
import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_event.dart';

/// Gestisce apertura del FilterSheet e ricarica dei profili filtrati.
class FilterManager {
  /// Mostra il BottomSheet con i filtri, aggiorna Firestore, resetta lo swiper e ricarica i profili.
  static Future<void> showFilterSheet({
    required BuildContext context,
    required List<Map<String, dynamic>> allProfiles,
    required Position position,
    required User user,
    required VoidCallback onResetSwiper,
  }) async {
    final filter = context.read<FilterModel>();

    // ← RILEGGO i filtri dal DB **ogni volta** che apro il foglio
    final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('filters')    // nuova sotto‐collezione
      .doc('settings')          // documento “settings”
      .get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;

      // Età
      if (data['minAge']  != null && data['maxAge'] != null) {
        filter.updateAge(RangeValues(
          (data['minAge']  as num).toDouble(),
          (data['maxAge']  as num).toDouble(),
        ));
      }

      // Distanza
      if (data['maxDistance'] != null) {
        filter.updateDistance((data['maxDistance'] as num).toDouble());
      }

      // Genere
      if (data['gender'] is String) {
        filter.updateGender(data['gender'] as String);
      }
    }

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => FilterSheet(
        ageRange: filter.ageRange,
        maxDistance: filter.maxDistance,
        genderFilter: filter.gender,
        onAgeChanged: (r) {
          filter.updateAge(r);
          dispatchLoad(context, allProfiles, position);
        },
        onDistanceChanged: (d) {
          filter.updateDistance(d);
          dispatchLoad(context, allProfiles, position);
        },
        onGenderChanged: (g) {
          filter.updateGender(g);
          dispatchLoad(context, allProfiles, position);
        },
        onApply: () async {
          // Salva filtri su Firestore
          await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('filters')          // sotto‐collezione “filters”
            .doc('settings')                // documento “settings”
            .set({
              'minAge':       filter.ageRange.start.toInt(),
              'maxAge':       filter.ageRange.end.toInt(),
              'maxDistance':  filter.maxDistance,
              'gender':       filter.gender,
            }, SetOptions(merge: true));     // merge per non sovrascrivere altri campi

          // Reset stato swiper nel widget chiamante
          onResetSwiper();

          // Ricarica profili filtrati
          dispatchLoad(context, allProfiles, position);

          Navigator.of(sheetContext).pop(); // usa sheetContext, non quello esterno
        },
      ),
    );
  }

  /// Applica i filtri correnti e invia l'evento LoadProfiles al bloc.
  static void dispatchLoad(
    BuildContext context,
    List<Map<String, dynamic>> allProfiles,
    Position position,
  ) {

    debugPrint('Dispatching LoadProfiles with ${allProfiles.length} profiles');

    final filter = Provider.of<FilterModel>(context, listen: false);

    final filtered = allProfiles.where((p) {
      filter.apply(p, position);

      debugPrint('Current filter: '
        'AgeRange: ${filter.ageRange.start} - ${filter.ageRange.end}, '
        'MaxDistance: ${filter.maxDistance}, ');

      final age = p['age'] is num
          ? (p['age'] as num).toInt()
          : int.tryParse('${p['age']}') ?? 0;
      if (age < filter.ageRange.start || age > filter.ageRange.end) return false;
      final gender = p['gender']?.toString() ?? '';
      if (filter.gender != 'all' && gender != filter.gender) return false;
      final lat = (p['lastLat'] as num?)?.toDouble();
      final lon = (p['lastLong'] as num?)?.toDouble();
      if (lat == null || lon == null) return false;

      final distKm = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lon,
      ) / 1000;

      return distKm <= filter.maxDistance;
    }).toList();

    debugPrint('Filtered profiles count: ${filtered.length}');

    context.read<SwipeBloc>().add(LoadProfiles(filtered));
  }
}
