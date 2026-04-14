import 'package:hive_flutter/hive_flutter.dart';

import 'package:portones_mym/core/constants/hive_boxes.dart';
import 'package:portones_mym/core/utils/formatters.dart';
import 'package:portones_mym/data/models/client_item.dart';

class ClientsRepository {
  final _box = Hive.box(kClientsBox);

  List<ClientItem> getAll() {
    final items = <ClientItem>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is Map) {
        items.add(ClientItem.fromMap(Map<String, dynamic>.from(raw)));
      }
    }
    items.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return items;
  }

  ClientItem? getByPhoneKey(String phoneKey) {
    final raw = _box.get(phoneKey);
    if (raw is Map) return ClientItem.fromMap(Map<String, dynamic>.from(raw));
    return null;
  }

  Future<void> deleteByPhoneKey(String phoneKey) => _box.delete(phoneKey);

  Future<String> upsert({
    required String nombre,
    required String telefono,
    String? ubicacionTexto,
  }) async {
    final phoneKey = normalizePhone(telefono);
    if (phoneKey.isEmpty) throw Exception('Teléfono inválido');

    final existing = _box.get(phoneKey);
    final nowIso = DateTime.now().toIso8601String();

    if (existing is Map) {
      final old = Map<String, dynamic>.from(existing);

      final n = nombre.trim();
      final u = (ubicacionTexto ?? '').trim();
      final tr = telefono.trim();

      if (n.isNotEmpty) old['nombre'] = n;
      if (tr.isNotEmpty) old['telefonoRaw'] = tr;
      if (u.isNotEmpty) old['ubicacionTexto'] = u;

      old['telefonoKey'] = phoneKey;
      old['id'] = phoneKey;
      old['updatedAt'] = nowIso;

      await _box.put(phoneKey, old);
      return phoneKey;
    } else {
      final item = ClientItem(
        id: phoneKey,
        nombre: nombre.trim(),
        telefonoRaw: telefono.trim(),
        telefonoKey: phoneKey,
        ubicacionTexto: (ubicacionTexto ?? '').trim(),
      );
      final map = item.toMap();
      map['createdAt'] = nowIso;
      map['updatedAt'] = nowIso;
      await _box.put(phoneKey, map);
      return phoneKey;
    }
  }

  Future<void> updateClient({
    required String phoneKey,
    required String nombre,
    required String telefonoRaw,
    required String ubicacionTexto,
  }) async {
    final newKey = normalizePhone(telefonoRaw);
    if (newKey.isEmpty) throw Exception('Teléfono inválido');

    final nowIso = DateTime.now().toIso8601String();
    final data = <String, dynamic>{
      'id': newKey,
      'nombre': nombre.trim(),
      'telefonoRaw': telefonoRaw.trim(),
      'telefonoKey': newKey,
      'ubicacionTexto': ubicacionTexto.trim(),
      'updatedAt': nowIso,
      'createdAt': nowIso,
    };

    if (newKey != phoneKey) {
      final existingOld = _box.get(phoneKey);
      if (existingOld is Map && existingOld['createdAt'] != null) {
        data['createdAt'] = existingOld['createdAt'];
      }
      await _box.delete(phoneKey);

      final existingNew = _box.get(newKey);
      if (existingNew is Map) {
        final old = Map<String, dynamic>.from(existingNew);
        if (data['nombre'].toString().isNotEmpty) old['nombre'] = data['nombre'];
        if (data['telefonoRaw'].toString().isNotEmpty) old['telefonoRaw'] = data['telefonoRaw'];
        if (data['ubicacionTexto'].toString().isNotEmpty) old['ubicacionTexto'] = data['ubicacionTexto'];
        old['updatedAt'] = nowIso;
        await _box.put(newKey, old);
        return;
      }
    } else {
      final existing = _box.get(phoneKey);
      if (existing is Map && existing['createdAt'] != null) {
        data['createdAt'] = existing['createdAt'];
      }
    }

    await _box.put(newKey, data);
  }
}