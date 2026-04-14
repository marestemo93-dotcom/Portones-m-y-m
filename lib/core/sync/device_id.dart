import 'dart:math';
import 'package:hive/hive.dart';

import 'package:portones_mym/core/constants/hive_boxes.dart';

class DeviceId {

  static const _key = 'deviceId';

  /// Obtiene el deviceId o lo crea si no existe
  static String getOrCreate() {

    final box = Hive.box(kJobsBox);

    String? id = box.get(_key);

    if (id != null && id.isNotEmpty) {
      return id;
    }

    final random = Random();

    id =
        DateTime.now().millisecondsSinceEpoch.toString()
            + "_"
            + random.nextInt(999999).toString();

    box.put(_key, id);

    return id;
  }
}