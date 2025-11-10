// lib/services/auth_service.dart
// Auth mínimo sin google_sign_in.
// Persiste sesión con shared_preferences (Web y Mobile).
// Expone userChanges/currentUser para tu AuthGate basado en StreamBuilder.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;

  const AuthUser({
    required this.id,
    this.name,
    this.email,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'photoUrl': photoUrl,
  };

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as String,
    name: j['name'] as String?,
    email: j['email'] as String?,
    photoUrl: j['photoUrl'] as String?,
  );
}

class AuthService {
  static final AuthService I = AuthService._();
  AuthService._() {
    // Propaga cambios del ValueNotifier al Stream.
    user.addListener(() => _userCtrl.add(user.value));
    _restore(); // arranca restauración async de sesión
  }

  static const String _kKey = 'bitacora.auth_user.v1';

  // Estado actual y errores
  final ValueNotifier<AuthUser?> user = ValueNotifier<AuthUser?>(null);
  final ValueNotifier<String> lastError = ValueNotifier<String>('');

  // Stream + snapshot para AuthGate con StreamBuilder
  final StreamController<AuthUser?> _userCtrl =
  StreamController<AuthUser?>.broadcast();
  Stream<AuthUser?> get userChanges => _userCtrl.stream;
  AuthUser? get currentUser => user.value;

  Future<void> _restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      user.value = AuthUser.fromJson(map);
    } catch (_) {
      // silencioso
    }
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final u = user.value;
      if (u == null) {
        await sp.remove(_kKey);
      } else {
        await sp.setString(_kKey, jsonEncode(u.toJson()));
      }
    } catch (_) {
      // silencioso
    }
  }

  // Hoy entra como invitado. Más adelante integramos Google/Firebase si querés.
  Future<void> signIn() async {
    lastError.value = '';
    await signInAsGuest();
  }

  Future<void> signInAsGuest() async {
    user.value = const AuthUser(id: 'guest', name: 'Invitado');
    await _persist();
  }

  Future<void> signOut() async {
    user.value = null;
    await _persist();
  }
}
