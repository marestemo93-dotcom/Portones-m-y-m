import 'package:local_auth/local_auth.dart';

class BiometricGate {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> unlock({String reason = 'Autenticá para continuar'}) async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;

      if (!supported && !canCheck) return true; // o false si querés obligarlo

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}