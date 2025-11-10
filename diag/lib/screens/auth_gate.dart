// lib/screens/auth_gate.dart
// Pantalla de login simple. Sin imports a widgets externos.
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_auth.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GoogleSignInAccount?>(
      valueListenable: GoogleAuthService.I.user,
      builder: (_, user, __) => user != null ? child : const _SignInScreen(),
    );
  }
}

class _SignInScreen extends StatelessWidget {
  const _SignInScreen();

  @override
  Widget build(BuildContext context) {
    final err = GoogleAuthService.I.lastError;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Iniciar sesión',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const Text(
                    'Entrá con tu cuenta de Google para continuar.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const _GoogleSignInButton(),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<String>(
                    valueListenable: err,
                    builder: (_, msg, __) => msg.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        msg,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
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

class _GoogleSignInButton extends StatefulWidget {
  const _GoogleSignInButton();

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      await GoogleAuthService.I.signIn();
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await GoogleAuthService.I.signOut();
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GoogleSignInAccount?>(
      valueListenable: GoogleAuthService.I.user,
      builder: (_, u, __) {
        if (u != null) {
          final visible = (u.displayName != null && u.displayName!.trim().isNotEmpty)
              ? u.displayName!
              : u.email;
          return OutlinedButton.icon(
            onPressed: _busy ? null : _logout,
            icon: const Icon(Icons.logout),
            label: Text(_busy ? 'Cerrando sesión…' : 'Cerrar sesión de $visible'),
          );
        }
        return ElevatedButton.icon(
          onPressed: _busy ? null : _login,
          icon: _busy
              ? const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.login),
          label: Text(_busy ? 'Conectando…' : 'Continuar con Google'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        );
      },
    );
  }
}
