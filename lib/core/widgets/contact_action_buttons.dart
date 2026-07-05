import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Botón de Waze reutilizable. Se deshabilita (gris, no clickeable) si no
/// hay coordenadas todavía - mismo patrón de URL que ya usa la burbuja de
/// ubicación en el chat de WhatsApp (whatsapp_tab.dart, sin tocar ese flujo).
class WazeButton extends StatelessWidget {
  const WazeButton({super.key, required this.lat, required this.lng});

  final double? lat;
  final double? lng;

  bool get _habilitado => lat != null && lng != null;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _habilitado ? 'Abrir en Waze' : 'Sin ubicación guardada',
      icon: const Icon(Icons.navigation),
      color: _habilitado ? const Color(0xFF00AAFF) : Colors.white24,
      onPressed: _habilitado
          ? () => launchUrl(Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes'), mode: LaunchMode.externalApplication)
          : null,
    );
  }
}

/// Botón de WhatsApp reutilizable: abre un chat directo con el número.
class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({super.key, required this.telefono});

  final String? telefono;

  bool get _habilitado => (telefono ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _habilitado ? 'Escribir por WhatsApp' : 'Sin teléfono',
      icon: const Icon(Icons.chat),
      color: _habilitado ? const Color(0xFF25D366) : Colors.white24,
      onPressed: _habilitado
          ? () {
        final numero = telefono!.replaceAll(RegExp(r'[^0-9]'), '');
        launchUrl(Uri.parse('https://wa.me/$numero'), mode: LaunchMode.externalApplication);
      }
          : null,
    );
  }
}
