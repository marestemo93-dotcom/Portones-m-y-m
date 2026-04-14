import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/services/notif_service.dart';

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
    final jobsRepo = ref.read(jobsRepoProvider);
    final clientsRepo = ref.read(clientsRepoProvider);

    final tituloCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final ubicCtrl = TextEditingController();
    final montoCtrl = TextEditingController();

    TimeOfDay? pickedTime;

    try {
      // ✅ Dialog con StatefulBuilder para refrescar solo el dialog
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setStateDialog) {
              Future<void> pickTime() async {
                final t = await pickTimeCupertino12h(
                  ctx,
                  initial: pickedTime ?? const TimeOfDay(hour: 9, minute: 0),
                );
                if (t != null) {
                  setStateDialog(() => pickedTime = t);
                }
              }

              return AlertDialog(
                title: const Text('Agregar trabajo'),
                content: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: tituloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Trabajo',
                          hintText: 'Ej: Mantenimiento portón',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nombreCtrl,
                        decoration:
                        const InputDecoration(labelText: 'Cliente (opcional)'),
                      ),
                      TextField(
                        controller: telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono (opcional)',
                        ),
                      ),
                      TextField(
                        controller: montoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monto (opcional)',
                          hintText: 'Ej: 450000',
                        ),
                      ),
                      TextField(
                        controller: ubicCtrl,
                        decoration:
                        const InputDecoration(labelText: 'Ubicación (opcional)'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickTime,
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                pickedTime == null
                                    ? 'Elegir hora'
                                    : NotifService.formatAmPm(pickedTime!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Guardar'),
                  ),
                ],
              );
            },
          );
        },
      );

      // ✅ Si la pantalla se desmontó mientras el dialog estaba abierto
      if (!context.mounted) return;

      // ✅ Canceló
      if (ok != true) return;

      final titulo = tituloCtrl.text.trim();
      if (titulo.isEmpty) {
        // ✅ Solo si sigue montado
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El campo "Trabajo" es obligatorio')),
        );
        return;
      }

      // ✅ monto tolerante
      final montoRaw = montoCtrl.text.trim();
      double? montoCrc;
      if (montoRaw.isNotEmpty) {
        final cleaned = montoRaw.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleaned.isNotEmpty) {
          montoCrc = double.tryParse(cleaned);
        }
      }

      String? phoneKey;
      final tel = telefonoCtrl.text.trim();
      final nombre = nombreCtrl.text.trim();
      final ubic = ubicCtrl.text.trim();

      if (tel.isNotEmpty) {
        phoneKey = await clientsRepo.upsert(
          nombre: nombre.isEmpty ? 'Cliente' : nombre,
          telefono: tel,
          ubicacionTexto: ubic,
        );

        // ✅ por si se desmontó durante el await
        if (!context.mounted) return;
      }

      final minutes =
      pickedTime == null ? null : (pickedTime!.hour * 60 + pickedTime!.minute);

      await jobsRepo.addJob(
        day: day,
        titulo: titulo,
        timeMinutes: minutes,
        clientPhoneKey: phoneKey,
        clientNameSnapshot: nombre.isEmpty ? null : nombre,
        locationSnapshot: ubic.isEmpty ? null : ubic,
        montoCrc: montoCrc,
      );
    } finally {
      // ✅ Siempre liberar controllers
      tituloCtrl.dispose();
      nombreCtrl.dispose();
      telefonoCtrl.dispose();
      ubicCtrl.dispose();
      montoCtrl.dispose();
    }
  }
}