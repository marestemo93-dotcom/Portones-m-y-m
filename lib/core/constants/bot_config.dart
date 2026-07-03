// lib/core/constants/bot_config.dart
//
// La API key se pasa en tiempo de compilación (no vive en el código fuente,
// que es un repo público en GitHub). Correr con:
//   flutter run --dart-define-from-file=dart_defines.json
// Ver dart_defines.example.json para el formato.

const String kBotBaseUrl = String.fromEnvironment(
  'BOT_BASE_URL',
  defaultValue: 'https://api.portonesmym.com',
);

const String kBotApiKey = String.fromEnvironment('BOT_API_KEY');
