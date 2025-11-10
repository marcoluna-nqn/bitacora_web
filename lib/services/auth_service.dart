/* lib/services/auth_service.dart — stub para compilar */
import 'dart:async';

class AuthUser {
  final String id;
  final String? name, email, photoUrl;
  const AuthUser({required this.id, this.name, this.email, this.photoUrl});
}

class AuthService {
  AuthService._();
  static final I = AuthService._();

  final _ctrl = StreamController<AuthUser?>.broadcast();

  // API mínima para no romper referencias
  Stream<AuthUser?> get userChanges => _ctrl.stream;
  AuthUser? get currentUser => null;

  Future<void> signIn() async {}
  Future<void> signOut() async {}
}
