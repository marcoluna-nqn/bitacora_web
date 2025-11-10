// lib/widgets/google_signin_button_web.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_signin_service.dart';

class GoogleSignInButtonWeb extends StatefulWidget {
  const GoogleSignInButtonWeb({super.key});

  @override
  State<GoogleSignInButtonWeb> createState() => _GoogleSignInButtonWebState();
}

class _GoogleSignInButtonWebState extends State<GoogleSignInButtonWeb> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    // Inicializa el SDK una vez. No bloquea UI.
    // ignore: discarded_futures
    GoogleSigninService.I.initOnce();
  }

  Future<void> _doSignIn() async {
    setState(() => _working = true);
    try {
      await GoogleSigninService.I.signIn();
    } finally {
      if (!mounted) return;
      setState(() => _working = false);
    }
  }

  Future<void> _doSignOut() async {
    setState(() => _working = true);
    try {
      await GoogleSigninService.I.signOut();
    } finally {
      if (!mounted) return;
      setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final err = GoogleSigninService.I.lastError;
    final userListenable = GoogleSigninService.I.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<GoogleSignInAccount?>(
          valueListenable: userListenable,
          builder: (BuildContext _, GoogleSignInAccount? user, Widget? __) {
            if (user != null) {
              final String nameOrMail = (user.displayName != null && user.displayName!.trim().isNotEmpty)
                  ? user.displayName!
                  : user.email;
              return OutlinedButton.icon(
                onPressed: _working ? null : _doSignOut,
                icon: const Icon(Icons.logout),
                label: Text(_working ? 'Cerrando sesión…' : 'Cerrar sesión de $nameOrMail'),
              );
            }
            return ElevatedButton.icon(
              onPressed: _working ? null : _doSignIn,
              icon: _working
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: Text(_working ? 'Conectando…' : 'Continuar con Google'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            );
          },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<String>(
          valueListenable: err,
          builder: (BuildContext _, String msg, Widget? __) {
            if (msg.isEmpty) return const SizedBox.shrink();
            return Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            );
          },
        ),
      ],
    );
  }
}
