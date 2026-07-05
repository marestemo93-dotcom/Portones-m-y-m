import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/garantias/presentation/generar_garantia_screen.dart';

class _OpcionPostTrabajo {
  final String id;
  final String titulo;
  final String subtitulo;
  final IconData icono;

  const _OpcionPostTrabajo({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
  });
}

// Lista de opciones al marcar un Trabajo como "Listo". Es una lista (no
// botones hardcodeados) para poder sumar "Crear contrato" más adelante
// agregando solo una entrada acá, sin tocar el resto del flujo.
const _opcionesPostTrabajo = <_OpcionPostTrabajo>[
  _OpcionPostTrabajo(
    id: 'certificado',
    titulo: 'Generar certificado de garantía',
    subtitulo: 'Formulario, vista previa y envío por WhatsApp',
    icono: Icons.verified_user,
  ),
  _OpcionPostTrabajo(
    id: 'omitir',
    titulo: 'Omitir por ahora',
    subtitulo: 'Podés generarlo después desde el detalle del trabajo',
    icono: Icons.skip_next_outlined,
  ),
  // 'contrato' se agrega acá después.
];

class CertificadoGarantiaFlow {
  /// Muestra la elección "¿Qué querés hacer?" (certificado / omitir / futuro
  /// contrato) al marcar un Trabajo como "Listo".
  ///
  /// Devuelve true si corresponde continuar marcando el trabajo como "Listo"
  /// (haya generado certificado o lo haya omitido). Devuelve false si el
  /// usuario canceló - en ese caso el trabajo NO debe marcarse como "Listo",
  /// igual que cancelar cualquier otro paso de este flujo.
  static Future<bool> run({
    required BuildContext context,
    required WidgetRef ref,
    required DateTime day,
    required JobItem job,
  }) async {
    final opcion = await _pickOpcion(context);
    if (!context.mounted || opcion == null) return false;

    switch (opcion.id) {
      case 'certificado':
        return generarCertificado(context: context, ref: ref, day: day, job: job);
      case 'omitir':
        return true;
      default:
        return true;
    }
  }

  /// Abre directamente el formulario de certificado (GenerarGarantiaScreen),
  /// sin el picker previo. Se usa tanto desde la opción "Generar
  /// certificado" de arriba como desde el botón manual "Generar
  /// certificado" en el detalle de un Trabajo ya completado.
  static Future<bool> generarCertificado({
    required BuildContext context,
    required WidgetRef ref,
    required DateTime day,
    required JobItem job,
  }) async {
    final jobsRepo = ref.read(jobsRepoProvider);
    final garantiasRepo = ref.read(garantiasRepoProvider);

    final completado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GenerarGarantiaScreen(
          job: job,
          day: day,
          jobsRepo: jobsRepo,
          garantiasRepo: garantiasRepo,
        ),
        fullscreenDialog: true,
      ),
    );

    return completado == true;
  }

  static Future<_OpcionPostTrabajo?> _pickOpcion(BuildContext context) {
    return showModalBottomSheet<_OpcionPostTrabajo>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Trabajo completado', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              for (final opcion in _opcionesPostTrabajo)
                ListTile(
                  leading: Icon(opcion.icono),
                  title: Text(opcion.titulo),
                  subtitle: Text(opcion.subtitulo),
                  onTap: () => Navigator.pop(ctx, opcion),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
