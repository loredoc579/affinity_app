import 'dart:convert';
import 'package:http/http.dart' as http;

/// Torna il nome della città (o area) dalla lat/lng, o null.
Future<String?> getCityFromCoordinates(double lat, double lon) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
    'format': 'json',
    'lat': lat.toString(),
    'lon': lon.toString(),
    'zoom': '10',          // livello di dettaglio (10→ città/regione)
    'addressdetails': '1',
  });
  final resp = await http.get(uri, headers: {
    'User-Agent': 'AffinityApp/1.0 (your.email@domain.com)',
  });
  if (resp.statusCode != 200) return null;

  final data = json.decode(resp.body) as Map<String, dynamic>;
  final addr = data['address'] as Map<String, dynamic>?;

  // Proviamo a estrarre city→town→village→state
  return addr?['city']
      as String? ??
      addr?['town']
      as String? ??
      addr?['village']
      as String? ??
      addr?['state']
      as String?;
}
