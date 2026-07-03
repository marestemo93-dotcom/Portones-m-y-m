import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Handler para mensajes en background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _mostrarNotificacion(message);
}

final FlutterLocalNotificationsPlugin _notificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> _mostrarNotificacion(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'whatsapp_channel',
    'Mensajes WhatsApp',
    channelDescription: 'Notificaciones de mensajes de clientes',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
    color: Color(0xFF25D366),
    enableVibration: true,
    playSound: true,
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await _notificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'Nuevo mensaje',
    message.notification?.body ?? '',
    details,
  );
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Pedir permisos
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Inicializar notificaciones locales
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    // Crear canal de notificaciones
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'whatsapp_channel',
      'Mensajes WhatsApp',
      description: 'Notificaciones de mensajes de clientes',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    // Handler para mensajes en background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handler para mensajes en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _mostrarNotificacion(message);
    });

    // Obtener token FCM
    final token = await _messaging.getToken();
    print('FCM Token: $token');

// Guardar token en Firestore
    if (token != null) {
      try {
        await FirebaseFirestore.instance
            .collection('config')
            .doc('fcm')
            .set({'token': token, 'updatedAt': DateTime.now()});
        print('✅ FCM Token guardado en Firestore');
      } catch (e) {
        print('❌ Error guardando FCM Token: $e');
      }
    }
  }
}