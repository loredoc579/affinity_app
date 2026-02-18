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

/// Mostra il BottomSheet con i filtri, salva le impostazioni e ricarica il bloc SOLO su Apply.
  static Future<void> showFilterSheet({
    required BuildContext context,
    required User user,
    required VoidCallback onResetSwiper,
  }) async {
    final filter = Provider.of<FilterModel>(context, listen: false);

    // 1. Recupera impostazioni utente da Firestore
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

    // 2. CREIAMO LE VARIABILI TEMPORANEE copiandole dal filtro attuale
    RangeValues tempAgeRange = filter.ageRange;
    double tempDistance = filter.maxDistance;
    String tempGender = filter.gender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        // 3. Usiamo StatefulBuilder per far muovere i cursori localmente senza chiamare Firebase
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return FilterSheet(
              // Passiamo i valori TEMPORANEI alla UI
              ageRange: tempAgeRange,
              maxDistance: tempDistance,
              genderFilter: tempGender,
              
              // Quando muovi il cursore, aggiorniamo SOLO la variabile temporanea!
              onAgeChanged: (range) {
                setModalState(() => tempAgeRange = range);
              },
              onDistanceChanged: (distance) {
                setModalState(() => tempDistance = distance);
              },
              onGenderChanged: (gender) {
                setModalState(() => tempGender = gender);
              },
              
              // 4. IL MOMENTO DELLA VERITÀ: L'utente preme APPLICA
              onApply: () async {
                // A. Aggiorniamo finalmente il Provider Globale
                filter.updateAge(tempAgeRange);
                filter.updateDistance(tempDistance);
                filter.updateGender(tempGender);

                // B. Salviamo su Firestore le nuove variabili
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('filters')
                    .doc('settings')
                    .set({
                  'minAge': tempAgeRange.start.toInt(),
                  'maxAge': tempAgeRange.end.toInt(),
                  'maxDistance': tempDistance,
                  'gender': tempGender,
                }, SetOptions(merge: true));

                // C. Reset dello swiper
                onResetSwiper();

                // D. Spara la chiamata a Firebase (UNA SOLA VOLTA!)
                _dispatchLoad(context);

                // E. Chiude il bottom sheet
                Navigator.of(sheetCtx).pop();
              },
            );
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
    debugPrint('👉 [1. MANAGER] Invio filtri: $uiFilters');
    context.read<SwipeBloc>().add(LoadProfiles(uiFilters: uiFilters));
  }
}
