import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      if (data['filterMinAge'] != null && data['filterMaxAge'] != null) {
        filter.updateAge(RangeValues(
          (data['filterMinAge']  as num).toDouble(),
          (data['filterMaxAge']  as num).toDouble(),
        ));
      }
      if (data['filterMaxDistance'] != null) {
        filter.updateDistance((data['filterMaxDistance'] as num).toDouble());
      }
      if (data['filterGender'] is String) {
        filter.updateGender(data['filterGender'] as String);
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
              .update({
            'filterMinAge': filter.ageRange.start.toInt(),
            'filterMaxAge': filter.ageRange.end.toInt(),
            'filterMaxDistance': filter.maxDistance,
            'filterGender': filter.gender,
          });

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

    final filter = context.read<FilterModel>();
    final filtered = allProfiles.where((p) {
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
