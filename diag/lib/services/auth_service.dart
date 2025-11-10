// Servicio mínimo de autenticación con Google (Web/Mobile).
// Requiere: flutter pub add google_sign_in
// Para Web: poné tu CLIENT_ID abajo.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthUser {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;
  const AuthUser({required this.id, this.name, this.email, this.photoUrl});
}

class AuthService {
  // TODO: reemplazar por tu client id web
  static const String _webClientId = 'REEMPLAZA_AQUI.apps.googleusercontent.com';

  static final AuthService I = AuthService._();
  AuthService._();

  GoogleSignIn? _gsi;
  final _ctrl = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  Stream<AuthUser?> get userChanges => _ctrl.stream;
  AuthUser? get currentUser => _current;

  GoogleSignIn _ensure() {
    if (_gsi != null) return _gsi!;
    _gsi = GoogleSignIn(
      // En Web es obligatorio pasar clientId:
      clientId: kIsWeb ? _webClientId : null,
      scopes: const ['email', 'profile', 'openid'],
    );
    _gsi!.onCurrentUserChanged.listen((acc) {
      _current = acc == null
          ? null
          : AuthUser(
        id: acc.id,
        name: acc.displayName,
        email: acc.email,
        photoUrl: acc.photoUrl,
      );
      _ctrl.add(_current);
    });
    return _gsi!;
  }

  Future<AuthUser?> signIn() async {
    final g = _ensure();
    // Intenta reusar sesión si existe:
    final acc = await g.signInSilently(suppressErrors: true);
    if (acc != null) return _current;

    final res = await g.signIn();
    if (res == null) return null; // usuario canceló
    return _current;
  }

  Future<void> signOut() async {
    final g = _ensure();
    await g.signOut();
    await g.disconnect(); // Web: limpia sesión de Google
    _current = null;
    _ctrl.add(null);
  }
}
