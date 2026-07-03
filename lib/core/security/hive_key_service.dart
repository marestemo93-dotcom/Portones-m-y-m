import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HiveKeyService {
  static const _storageKey = 'hive_encryption_key';
  static const _secureStorage = FlutterSecureStorage();

  /// Devuelve la clave AES de 256 bits usada para cifrar las cajas de Hive.
  /// La genera una sola vez y la guarda en el Keystore/Keychain del sistema.
  static Future<List<int>> getOrCreateKey() async {
    final existing = await _secureStorage.read(key: _storageKey);
    if (existing != null) {
      return existing.split(',').map(int.parse).toList();
    }

    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.write(key: _storageKey, value: key.join(','));
    return key;
  }
}
