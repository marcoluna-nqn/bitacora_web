// lib/services/location_service.dart
// Geolocator 12.x: getCurrentPosition(desiredAccuracy,timeLimit) + getPositionStream(locationSettings).

import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, debugPrint;
import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => 'LocationException: $message';
}

class LocationFix {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? altitudeMeters;
  final double? speedMps;
  final double? headingDeg;
  final DateTime timestamp;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMps,
    this.headingDeg,
    required this.timestamp,
  });

  factory LocationFix.fromPosition(Position p) => LocationFix(
    latitude: p.latitude,
    longitude: p.longitude,
    accuracyMeters: _numOrNull(p.accuracy),
    altitudeMeters: _numOrNull(p.altitude),
    speedMps: _numOrNull(p.speed),
    headingDeg: _numOrNull(p.heading),
    timestamp: p.timestamp ?? DateTime.now(),
  );

  static double? _numOrNull(double v) => (v.isNaN || v.isInfinite) ? null : v;
}

class LocationService {
  LocationService._();
  static final LocationService I = LocationService._();

  final ValueNotifier<LocationFix?> _cache = ValueNotifier<LocationFix?>(null);
  ValueListenable<LocationFix?> get lastFixListenable => _cache;

  // ---- permisos
  Future<void> _ensureServiceAndPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Activá el servicio de ubicación.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const LocationException('Permiso denegado.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationException('Permiso denegado permanentemente.');
    }
  }

  Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<bool> openSystemLocationSettings() => Geolocator.openLocationSettings();
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  // ---- lectura puntual
  Future<Position> getCurrent({
    LocationAccuracy desiredAccuracy = LocationAccuracy.best,
    Duration timeout = const Duration(seconds: 10),
    bool rejectMocked = true,
  }) async {
    await _ensureServiceAndPermission();
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: desiredAccuracy,
        timeLimit: timeout,
      );
      if (!_validPos(p, rejectMocked: rejectMocked)) {
        throw const LocationException('Fix inválido.');
      }
      return p;
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _validPos(last, rejectMocked: rejectMocked)) {
        return last;
      }
      rethrow;
    } catch (e) {
      debugPrint('getCurrent error: $e');
      rethrow;
    }
  }

  Future<LocationFix> getCurrentFix({
    LocationAccuracy desiredAccuracy = LocationAccuracy.best,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final p = await getCurrent(desiredAccuracy: desiredAccuracy, timeout: timeout);
    final fix = LocationFix.fromPosition(p);
    _cache.value = fix;
    return fix;
  }

  // ---- stream continuo
  Stream<LocationFix> watchFixes({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 2,
    double rejectAboveAccuracyMeters = 100,
  }) async* {
    await _ensureServiceAndPermission();

    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );

    final stream = Geolocator.getPositionStream(locationSettings: settings);

    await for (final p in stream) {
      if (!_validPos(p, rejectMocked: true)) continue;
      if (p.accuracy > rejectAboveAccuracyMeters) continue;
      final fix = LocationFix.fromPosition(p);
      _cache.value = fix;
      yield fix;
    }
  }

  // ---- helpers
  bool _validPos(Position p, {bool rejectMocked = true}) {
    if (!_isValidLatLng(p.latitude, p.longitude)) return false;
    if (!p.accuracy.isFinite || p.accuracy <= 0 || p.accuracy > 150) return false;
    if (rejectMocked && p.isMocked == true) return false;
    return true;
  }
}

bool _isValidLatLng(double lat, double lng) =>
    lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        (lat.abs() > 1e-6 || lng.abs() > 1e-6);
