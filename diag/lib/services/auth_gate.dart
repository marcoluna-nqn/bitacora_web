// lib/screens/auth_gate.dart
// Muestra login si no hay sesión. Si hay sesión, muestra child.
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_signin_service.dart';
import '../widgets/google_signin_button_web.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GoogleSignInAccount?>(
      valueListenable: GoogleSigninService.I.user,
      builder: (BuildContext _, GoogleSignInAccount? user, Widget? __) {
        if (user != null) return child;
        return const _SignInScreen();
      },
    );
  }
}

class _SignInScreen extends StatelessWidget {
  const _SignInScreen();

  @override
  Widget build(BuildContext context) {
    final err = GoogleSigninService.I.lastError;
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
                  const Text('Iniciar sesión', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const Text('Entrá con tu cuenta de Google para usar Bitácora Web.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const GoogleSignInButtonWeb(),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<String>(
                    valueListenable: err,
                    builder: (BuildContext _, String msg, Widget? __) {
                      if (msg.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          msg,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
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
