import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final isLoggedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authStateProvider);
  final user = auth.asData?.value;
  return user != null && !user.isAnonymous; // ✅ bloquea solo si ya está con Google (no anónimo)
});