// lib/core/constants/bot_config.dart
//
// La API key no vive en el código fuente (el repo es público en GitHub).
// Se carga en tiempo de ejecución desde un asset local que NO se sube a
// git: assets/config/bot_secrets.json (ver bot_secrets.example.json para
// el formato). Hay que llamar BotConfig.load() una vez, antes de runApp.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class BotConfig {
  static String baseUrl = 'https://api.portonesmym.com';
  static String apiKey = '';

  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/config/bot_secrets.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      baseUrl = (data['BOT_BASE_URL'] as String?) ?? baseUrl;
      apiKey = (data['BOT_API_KEY'] as String?) ?? '';
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar assets/config/bot_secrets.json: $e');
    }
  }
}
