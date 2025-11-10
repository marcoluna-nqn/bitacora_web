import 'package:flutter/material.dart';

/// Passthrough: por ahora no exige login para evitar bloqueos de build.
/// Cuando actives Google Sign-In, reemplazá este archivo por el AuthGate real.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
