import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../models/filter_model.dart';
import '../widgets/filter_sheet.dart';
import '../bloc/swipe_bloc.dart';
import '../bloc/swipe_event.dart';
import '../services/filter_service.dart';

/// Gestisce apertura del FilterSheet e ricarica dei profili filtrati lato server.
class FilterManager {
  /// Carica i filtri da Firestore, aggiorna il FilterModel e dispatch iniziale LoadProfiles.
  static Future<void> loadAndDispatch(
    BuildContext context,
    String uid,
    VoidCallback onComplete,
  ) async {
    final swipeBloc = Provider.of<SwipeBloc>(context, listen: false);
    final filter = Provider.of<FilterModel>(context, listen: false);

    try {
      await FilterService.loadFiltersForUser(filter, uid);
    } catch (_) {
      // Ignora errori di caricamento dei filtri
    }

    // estrai la mappa dei filtri (metodo di esempio, adatta al tuo FilterModel)
    final Map<String, dynamic> uiFilters = filter.toMap();

    debugPrint('Dispatching LoadProfiles with filters: $uiFilters');
    
    swipeBloc.add(
      LoadProfiles(
        uiFilters: uiFilters,
        cursor: null,
      ),
    );

    onComplete();
  }

  /// Mostra il BottomSheet con i filtri, salva le impostazioni e ricarica il bloc.
  static Future<void> showFilterSheet({
    required BuildContext context,
    required User user,
    required VoidCallback onResetSwiper,
  }) async {
    final filter = Provider.of<FilterModel>(context, listen: false);

    // Recupera impostazioni utente da Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('filters')
        .doc('settings')
        .get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['minAge'] != null && data['maxAge'] != null) {
        filter.updateAge(RangeValues(
          (data['minAge'] as num).toDouble(),
          (data['maxAge'] as num).toDouble(),
        ));
      }
      if (data['maxDistance'] != null) {
        filter.updateDistance((data['maxDistance'] as num).toDouble());
      }
      if (data['gender'] is String) {
        filter.updateGender(data['gender'] as String);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return FilterSheet(
          ageRange: filter.ageRange,
          maxDistance: filter.maxDistance,
          genderFilter: filter.gender,
          onAgeChanged: (range) {
            filter.updateAge(range);
            _dispatchLoad(context);
          },
          onDistanceChanged: (distance) {
            filter.updateDistance(distance);
            _dispatchLoad(context);
          },
          onGenderChanged: (gender) {
            filter.updateGender(gender);
            _dispatchLoad(context);
          },
          onApply: () async {
            // Salva filtri su Firestore
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('filters')
                .doc('settings')
                .set({
              'minAge': filter.ageRange.start.toInt(),
              'maxAge': filter.ageRange.end.toInt(),
              'maxDistance': filter.maxDistance,
              'gender': filter.gender,
            }, SetOptions(merge: true));

            // Reset dello swiper
            onResetSwiper();

            // Dispatch con filtri UI
            _dispatchLoad(context);

            // Chiude il bottom sheet
            Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }

  /// Invia evento LoadProfiles con i filtri correnti al bloc.
  static void _dispatchLoad(BuildContext context) {
    final filter = Provider.of<FilterModel>(context, listen: false);
    final uiFilters = <String, dynamic>{
      'minAge': filter.ageRange.start.toInt(),
      'maxAge': filter.ageRange.end.toInt(),
      'maxDistance': filter.maxDistance,
      'gender': filter.gender,
    };
    debugPrint('Dispatching LoadProfiles with uiFilters: $uiFilters');
    context.read<SwipeBloc>().add(LoadProfiles(uiFilters: uiFilters));
  }
}
