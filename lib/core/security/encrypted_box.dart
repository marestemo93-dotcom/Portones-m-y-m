import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Abre [name] cifrada con [cipher]. Si ya existe en disco sin cifrar
/// (versión previa de la app), migra sus datos a una copia cifrada
/// sin perder ninguna entrada.
Future<Box> openEncryptedBox(String name, HiveAesCipher cipher) async {
  try {
    return await Hive.openBox(name, encryptionCipher: cipher);
  } catch (_) {
    debugPrint('🔐 Migrando box "$name" a almacenamiento cifrado...');

    final plainBox = await Hive.openBox(name);
    final data = Map<dynamic, dynamic>.from(plainBox.toMap());
    await plainBox.close();
    await Hive.deleteBoxFromDisk(name);

    final encryptedBox = await Hive.openBox(name, encryptionCipher: cipher);
    await encryptedBox.putAll(data);
    return encryptedBox;
  }
}
