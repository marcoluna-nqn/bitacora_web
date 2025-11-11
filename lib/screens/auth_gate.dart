// lib/screens/auth_gate.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Puerta de autenticación:
/// - Si el usuario está logueado con Google, muestra [child]
/// - Si no, muestra pantalla de login simple
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Versión 6.x: constructor normal y métodos signIn / signInSilently.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  GoogleSignInAccount? _account;
  bool _loading = true;
  StreamSubscription<GoogleSignInAccount?>? _sub;

  @override
  void initState() {
    super.initState();
    _initSignIn();
  }

  Future<void> _initSignIn() async {
    try {
      // Listener por si el usuario cambia de cuenta / cierra sesión
      _sub = _googleSignIn.onCurrentUserChanged.listen((acc) {
        if (!mounted) return;
        setState(() => _account = acc);
      });

      // Intento silencioso (si ya estaba logueado)
      final acc = await _googleSignIn.signInSilently();
      if (!mounted) return;
      setState(() {
        _account = acc;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _loading = true);
    try {
      final acc = await _googleSignIn.signIn();
      if (!mounted) return;
      setState(() {
        _account = acc;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _loading = true);
    try {
      await _googleSignIn.signOut();
      if (!mounted) return;
      setState(() {
        _account = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    // Si hay usuario, se deja pasar al árbol principal.
    if (_account != null) {
      return Stack(
        children: [
          widget.child,
          // Botoncito flotante discreto para cerrar sesión (opcional)
          Positioned(
            right: 16,
            top: 40,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _handleSignOut,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Salir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Pantalla de login
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bitácora Web',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Entrá con tu cuenta de Google para sincronizar tus planillas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _handleSignIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Continuar con Google'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      // Modo invitado: sin sync remoto, solo local
                      setState(() {
                        _account = null;
                        _loading = false;
                      });
                      // Simplemente mostramos el child
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => widget.child),
                      );
                    },
                    child: const Text('Seguir sin cuenta (modo local)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
