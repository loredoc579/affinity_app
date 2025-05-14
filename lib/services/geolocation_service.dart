import 'package:geolocator/geolocator.dart';

class GeolocationService {
  /// Restituisce la posizione corrente dell'utente, o null in caso di errore o permessi negati.
  static Future<Position?> determinePosition() async {
    // 1. Verifica che il servizio GPS sia attivo
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }

    // 2. Controlla/concede il permesso
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // 3. Tutto OK → ottieni la posizione
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }
}
