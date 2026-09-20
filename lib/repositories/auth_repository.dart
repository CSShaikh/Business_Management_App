import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository({
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isLoggedIn => _auth.currentUser != null;

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    final String normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Email address is required.',
      );
    }

    // Firebase generates and sends the secure reset link. We deliberately do
    // not hard-code a continue URL because it must belong to a domain that is
    // authorized in the Firebase Authentication console.
    await _auth.sendPasswordResetEmail(
      email: normalizedEmail,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> updateDisplayName(
    String name,
  ) async {
    await _auth.currentUser?.updateDisplayName(name.trim());

    await _auth.currentUser?.reload();
  }

  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }
}