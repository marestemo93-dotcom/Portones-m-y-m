import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSigninService {

  static Future<User?> signIn() async {

    final googleUser = await GoogleSignIn().signIn();

    if (googleUser == null) {
      return null;
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;

    // ✅ Si hay usuario anónimo → unir cuenta
    if (currentUser != null && currentUser.isAnonymous) {

      final result =
      await currentUser.linkWithCredential(credential);

      return result.user;
    }

    // ✅ Login normal
    final userCredential =
    await auth.signInWithCredential(credential);

    return userCredential.user;
  }

}