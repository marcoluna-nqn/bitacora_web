// lib/services/google_auth.dart
// google_sign_in ^7.2.0 — Null-safe. Sin context a través de async gaps.
import 'dart:async';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService I = GoogleAuthService._();

  final GoogleSignIn _gsi = GoogleSignIn.instance;

  final ValueNotifier<GoogleSignInAccount?> user =
  ValueNotifier<GoogleSignInAccount?>(null);
  final ValueNotifier<String> lastError = ValueNotifier<String>('');

  bool _inited = false;
  bool _isAuthorized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;

  bool get isAuthorized => _isAuthorized;
  GoogleSignInAccount? get currentUser => user.value;

  Future<void> init({
    required String clientId,          // en Web debe terminar en .apps.googleusercontent.com
    String? serverClientId,            // opcional si hacés backend auth
    List<String> bootstrapScopes = const ['email', 'profile', 'openid'],
  }) async {
    if (_inited) return;

    await _gsi.initialize(clientId: clientId, serverClientId: serverClientId);

    await _sub?.cancel();
    _sub = _gsi.authenticationEvents.listen((ev) async {
      switch (ev) {
        case GoogleSignInAuthenticationEventSignIn():
          user.value = ev.user;
          lastError.value = '';
          try {
            final ok = await _ensureScopes(bootstrapScopes);
            _isAuthorized = ok;
          } catch (_) {
            _isAuthorized = false;
          }
        case GoogleSignInAuthenticationEventSignOut():
          user.value = null;
          _isAuthorized = false;
          lastError.value = '';
      }
    }, onError: (Object e) {
      user.value = null;
      _isAuthorized = false;
      lastError.value = e is GoogleSignInException
          ? 'GoogleSignInException: ${e.code.name}'
          : 'Error de autenticación: $e';
    });

    // Sesión silenciosa si existe.
    // ignore: discarded_futures
    _gsi.attemptLightweightAuthentication();

    _inited = true;
  }

  bool get supportsAuthenticate => _gsi.supportsAuthenticate();

  Future<void> signIn() async {
    if (!_inited) {
      throw StateError('Llamá antes a GoogleAuthService.I.init(...)');
    }
    if (!supportsAuthenticate) {
      lastError.value = 'authenticate() no soportado en esta plataforma.';
      return;
    }
    try {
      await _gsi.authenticate(); // El estado llega por authenticationEvents.
    } on GoogleSignInException catch (e) {
      lastError.value = 'GoogleSignInException: ${e.code.name}';
    } catch (e) {
      lastError.value = 'Error al iniciar sesión: $e';
    }
  }

  Future<void> signOut() async {
    if (!_inited) return;
    try {
      await _gsi.signOut();
    } catch (_) {}
  }

  Future<void> disconnect() async {
    if (!_inited) return;
    try {
      await _gsi.disconnect();
    } catch (_) {}
  }

  Future<bool> requestScopes(List<String> scopes) async {
    final u = user.value;
    if (u == null) return false;
    try {
      final auth = await u.authorizationClient.authorizeScopes(scopes);
      final ok = auth != null;
      _isAuthorized = ok || _isAuthorized;
      return ok;
    } on GoogleSignInException catch (e) {
      lastError.value = 'GoogleSignInException: ${e.code.name}';
      return false;
    } catch (e) {
      lastError.value = 'Error pidiendo permisos: $e';
      return false;
    }
  }

  Future<Map<String, String>?> authorizationHeaders(List<String> scopes) async {
    final u = user.value;
    if (u == null) return null;
    try {
      final auth = await u.authorizationClient.authorizationForScopes(scopes);
      if (auth == null) return null;
      return {'Authorization': 'Bearer ${auth.accessToken}'};
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureScopes(List<String> scopes) async {
    final u = user.value;
    if (u == null) return false;
    final auth = await u.authorizationClient.authorizationForScopes(scopes);
    return auth != null;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    user.dispose();
    lastError.dispose();
  }
}
