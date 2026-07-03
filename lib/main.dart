// lib/main.dart
import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/core/constants/hive_boxes.dart';

import 'package:portones_mym/app/app.dart';
import 'package:portones_mym/core/security/encrypted_box.dart';
import 'package:portones_mym/core/security/hive_key_service.dart';
import 'package:portones_mym/core/services/notif_service.dart';

// ✅ Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'package:portones_mym/core/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ✅ Si ya tenés tu servicio de Google Sign-In, importalo:
// import 'package:portones_mym/core/services/google_signin_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Inicializar Firebase ANTES de usar servicios/sync
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Asegurar que exista un usuario autenticado (al menos anónimo)
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
    } catch (e, st) {
      debugPrint('❌ signInAnonymously error: $e');
      debugPrint('$st');
    }
  }

  // ✅ Debug: ver quién está logueado
  final u = auth.currentUser;
  debugPrint(
    'AUTH user=${u?.uid} anon=${u?.isAnonymous} providers=${u?.providerData.map((p) => p.providerId).toList()}',
  );

  // ⭐ BLOQUEAR ROTACIÓN (solo vertical)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await initializeDateFormatting(kLocaleEs, null);

  await Hive.initFlutter();
  final hiveCipher = HiveAesCipher(await HiveKeyService.getOrCreateKey());
  await openEncryptedBox(kJobsBox, hiveCipher);
  await openEncryptedBox(kClientsBox, hiveCipher);
  await openEncryptedBox(kGarantiasBox, hiveCipher);
  await openEncryptedBox(kJobsTombBox, hiveCipher);

  await NotifService.instance.init();

  // ✅ Si querés forzar Google al iniciar (solo si está anónimo), descomentá:
  /*
  if (auth.currentUser != null && auth.currentUser!.isAnonymous) {
    await GoogleSigninService.signIn(); // o linkWithCredential dentro del service
  }
  */

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.initialize();

  runApp(const ProviderScope(child: PortonesApp()));
}