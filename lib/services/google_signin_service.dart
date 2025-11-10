// lib/services/google_signin_service.dart
// google_sign_in ^7.2.0 — Web usa --dart-define=GSI_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSigninService {
  GoogleSigninService._();
  static final GoogleSigninService I = GoogleSigninService._();

  final GoogleSignIn _gsi = GoogleSignIn.instance;
  bool _inited = false;

  final ValueNotifier<GoogleSignInAccount?> user =
  ValueNotifier<GoogleSignInAccount?>(null);
  final ValueNotifier<String> lastError = ValueNotifier<String>('');

  static const String _kWebClientId =
  String.fromEnvironment('GSI_WEB_CLIENT_ID', defaultValue: '');

  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;

  Future<void> initOnce({String? serverClientId}) async {
    if (_inited) return;
    await _gsi.initialize(
      clientId: kIsWeb && _kWebClientId.isNotEmpty ? _kWebClientId : null,
      serverClientId: serverClientId,
    );

    _sub = _gsi.authenticationEvents.listen(
          (GoogleSignInAuthenticationEvent ev) {
        switch (ev) {
          case GoogleSignInAuthenticationEventSignIn():
            user.value = ev.user;
            lastError.value = '';
          case GoogleSignInAuthenticationEventSignOut():
            user.value = null;
            lastError.value = '';
        }
      },
      onError: (Object e) {
        user.value = null;
        lastError.value = e is GoogleSignInException
            ? 'GoogleSignInException: ${e.code.name}'
            : 'Error de autenticación: $e';
      },
    );

    // No bloquea UI.
    // ignore: discarded_futures
    _gsi.attemptLightweightAuthentication();

    _inited = true;
  }

  bool get supportsAuthenticate => _gsi.supportsAuthenticate();

  Future<GoogleSignInAccount?> signIn() async {
    await initOnce();
    if (!supportsAuthenticate) {
      lastError.value = 'authenticate() no soportado en esta plataforma.';
      return null;
    }
    try {
      return await _gsi.authenticate();
    } on GoogleSignInException catch (e) {
      lastError.value = 'GoogleSignInException: ${e.code.name}';
      return null;
    } catch (e) {
      lastError.value = 'Error al iniciar sesión: $e';
      return null;
    }
  }

  Future<void> signOut() async {
    await initOnce();
    try {
      await _gsi.signOut();
    } catch (_) {}
  }

  Future<void> disconnect() async {
    await initOnce();
    try {
      await _gsi.disconnect();
    } catch (_) {}
  }

  Future<bool> authorizeScopes(List<String> scopes) async {
    final u = user.value;
    if (u == null) return false;
    try {
      final auth = await u.authorizationClient.authorizeScopes(scopes);
      return auth != null;
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
    return u.authorizationClient.authorizationHeaders(scopes);
  }

  GoogleSignInAccount? get currentUser => user.value;

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
