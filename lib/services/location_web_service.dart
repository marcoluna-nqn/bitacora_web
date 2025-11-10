// lib/services/location_web_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationFix {
  final double lat;
  final double lng;
  final double? accuracyM;
  final DateTime ts;
  const LocationFix({required this.lat, required this.lng, this.accuracyM, required this.ts});
}

class LocationWebService {
  LocationWebService._();
  static final LocationWebService I = LocationWebService._();

  Future<void> _ensurePerms() async {
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) {
      throw 'Activá el servicio de ubicación del dispositivo.';
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied) throw 'Permiso de ubicación denegado.';
    if (p == LocationPermission.deniedForever) {
      throw 'Permiso denegado permanentemente. Habilitalo en Ajustes.';
    }
  }

  Future<LocationFix> getCurrent({Duration timeout = const Duration(seconds: 10)}) async {
    await _ensurePerms();
    final pos = await Geolocator.getCurrentPosition(
      timeLimit: timeout,
      desiredAccuracy: LocationAccuracy.high,
    );
    if (!_valid(pos.latitude, pos.longitude)) {
      throw 'Fix inválido (0,0).';
    }
    return LocationFix(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy.isFinite ? pos.accuracy : null,
      ts: pos.timestamp ?? DateTime.now(),
    );
  }

  Future<bool> openInMaps(double lat, double lng) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lng'});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String mapsUrl(double lat, double lng) =>
      Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lng'}).toString();

  String shareText(LocationFix f) =>
      'Ubicación: ${f.lat.toStringAsFixed(6)}, ${f.lng.toStringAsFixed(6)}'
          '\n${mapsUrl(f.lat, f.lng)}';

  bool _valid(double lat, double lng) =>
      lat.isFinite && lng.isFinite && (lat.abs() > 1e-6 || lng.abs() > 1e-6) && lat.abs() <= 90 && lng.abs() <= 180;
}
