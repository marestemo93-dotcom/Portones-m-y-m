import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/features/calendar/presentation/dialogs/agregar_trabajo_screen.dart';
import 'package:portones_mym/features/calendar/presentation/dialogs/agregar_visita_screen.dart';

class JobDialogs {
  static Future<TimeOfDay?> pickTimeCupertino12h(
      BuildContext context, {
        TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0),
      }) async {
    TimeOfDay tempTime = initial;

    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: 300,
          color: Colors.black,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Cancelar'),
                  ),
                  const Text(
                    'Seleccionar hora',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, tempTime),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.dark),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    initialDateTime: DateTime(
                      2024,
                      1,
                      1,
                      initial.hour,
                      initial.minute,
                    ),
                    onDateTimeChanged: (d) {
                      tempTime = TimeOfDay(hour: d.hour, minute: d.minute);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  static Future<void> addJobDialog(
      BuildContext context,
      WidgetRef ref, {
        required DateTime day,
      }) async {
    final tipo = await pickTipoJob(context);
    if (!context.mounted || tipo == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => tipo == 'visita' ? AgregarVisitaScreen(day: day) : AgregarTrabajoScreen(day: day),
        fullscreenDialog: true,
      ),
    );
  }

  /// Picker "¿Qué querés agendar?" (Visita / Trabajo). Público para que lo
  /// reutilicen otros puntos de entrada (ej. agendar_bottom_sheet.dart desde
  /// el chat de WhatsApp) sin duplicar el widget.
  static Future<String?> pickTipoJob(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('¿Qué querés agendar?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Visita'),
                subtitle: const Text('Visita técnica previa, sin costo, para cotizar'),
                onTap: () => Navigator.pop(ctx, 'visita'),
              ),
              ListTile(
                leading: const Icon(Icons.handyman),
                title: const Text('Trabajo'),
                subtitle: const Text('Instalación, mantenimiento, con productos y costo'),
                onTap: () => Navigator.pop(ctx, 'trabajo'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}