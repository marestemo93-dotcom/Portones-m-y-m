import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/core/constants/bot_config.dart';
import 'package:portones_mym/core/utils/formatters.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/data/repositories/jobs_repository.dart';
import 'package:portones_mym/features/garantias/data/repositories/garantias_repository.dart';
import 'package:portones_mym/features/garantias/pdf/certificado_garantia_pdf.dart';

/// Controllers de una fila editable de la tabla "Detalle del trabajo".
/// Se mantiene separado de [DetalleTrabajoItem] (que es texto plano, usado
/// por el generador de PDF) para no mezclar estado de UI con el modelo.
class _DetalleRowControllers {
  final cantidad = TextEditingController(text: '1');
  final descripcion = TextEditingController();
  final precio = TextEditingController();
  final total = TextEditingController();

  void dispose() {
    cantidad.dispose();
    descripcion.dispose();
    precio.dispose();
    total.dispose();
  }

  DetalleTrabajoItem toItem() => DetalleTrabajoItem(
    cantidad: cantidad.text.trim(),
    descripcion: descripcion.text.trim(),
    precio: precio.text.trim(),
    total: total.text.trim(),
  );
}

class GenerarGarantiaScreen extends StatefulWidget {
  const GenerarGarantiaScreen({
    super.key,
    required this.job,
    required this.day,
    required this.jobsRepo,
    required this.garantiasRepo,
  });

  final JobItem job;
  final DateTime day;
  final JobsRepository jobsRepo;
  final GarantiasRepository garantiasRepo;

  @override
  State<GenerarGarantiaScreen> createState() => _GenerarGarantiaScreenState();
}

class _GenerarGarantiaScreenState extends State<GenerarGarantiaScreen> {
  final _numeroCtrl = TextEditingController(text: '…');
  DateTime _fecha = DateTime.now();
  final _clienteCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _formaPagoCtrl = TextEditingController();
  final _garantiaFabricaCtrl = TextEditingController();
  final _garantiaInstalacionCtrl = TextEditingController();

  final List<_DetalleRowControllers> _detalle = [_DetalleRowControllers()];

  bool _cargando = true;
  bool _generandoPreview = false;

  @override
  void initState() {
    super.initState();
    _clienteCtrl.text = widget.job.clientNameSnapshot ?? '';
    _telefonoCtrl.text = widget.job.clientPhoneKey ?? '';
    _direccionCtrl.text = widget.job.locationSnapshot ?? '';

    // Fallback para trabajos viejos (de antes de tener detalleTrabajo):
    // una sola línea manual con el título y el monto total del job.
    if (widget.job.detalleTrabajo.isEmpty) {
      final monto = widget.job.montoCrc;
      _detalle.first.descripcion.text = widget.job.titulo;
      if (monto != null) {
        _detalle.first.precio.text = formatCrc(monto);
        _detalle.first.total.text = formatCrc(monto);
      }
    }

    _cargarDatosIniciales();
  }

  /// Arma las filas de la tabla desde job.detalleTrabajo (productos de
  /// catálogo + líneas manuales agregadas al crear/editar el Trabajo). Si
  /// una línea es de categoría "motor", le agrega el kit completo del
  /// producto a la descripción - mismo criterio que /enviar-motores usa
  /// para el mensaje de WhatsApp.
  Future<void> _prefillDesdeDetalleTrabajo() async {
    final filas = <_DetalleRowControllers>[];

    for (final linea in widget.job.detalleTrabajo) {
      var descripcion = linea.nombre;

      if (linea.categoria == 'motor' && linea.productoId != null) {
        try {
          final doc = await FirebaseFirestore.instance.collection('productos').doc(linea.productoId).get();
          final kit = List<String>.from(doc.data()?['kit'] ?? []);
          if (kit.isNotEmpty) {
            descripcion = '$descripcion\n${kit.map((k) => '• $k').join('\n')}';
          }
        } catch (_) {
          // si falla la consulta, se deja solo el nombre
        }
      }

      final fila = _DetalleRowControllers();
      fila.cantidad.text = linea.cantidad.toString();
      fila.descripcion.text = descripcion;
      fila.precio.text = formatCrc(linea.precio);
      fila.total.text = formatCrc(linea.precio * linea.cantidad);
      filas.add(fila);
    }

    if (!mounted) return;
    setState(() {
      for (final d in _detalle) {
        d.dispose();
      }
      _detalle
        ..clear()
        ..addAll(filas);
    });
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _clienteCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _formaPagoCtrl.dispose();
    _garantiaFabricaCtrl.dispose();
    _garantiaInstalacionCtrl.dispose();
    for (final d in _detalle) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    if (widget.job.detalleTrabajo.isNotEmpty) {
      await _prefillDesdeDetalleTrabajo();
    }
    final numero = await _reclamarNumeroGarantia();
    final garantiaMatch = await _buscarGarantiaProducto(widget.job.titulo);
    if (!mounted) return;
    setState(() {
      _numeroCtrl.text = numero;
      _garantiaFabricaCtrl.text = garantiaMatch['fabrica'] ?? '';
      _garantiaInstalacionCtrl.text = garantiaMatch['instalacion'] ?? '';
      _cargando = false;
    });
  }

  /// Reserva atómicamente el siguiente número correlativo en
  /// config/garantias.ultimoNumero (arranca en 101 => primer certificado
  /// "0101"). Se reserva una sola vez, al abrir esta pantalla - si el
  /// usuario cancela sin confirmar, el número queda "quemado" (igual que
  /// un número de factura anulado); es preferible a arriesgar una
  /// condición de carrera entre los 2 teléfonos si se reservara recién al
  /// confirmar.
  Future<String> _reclamarNumeroGarantia() async {
    final ref = FirebaseFirestore.instance.collection('config').doc('garantias');
    final siguiente = await FirebaseFirestore.instance.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final actual = (snap.data()?['ultimoNumero'] as num?)?.toInt() ?? 100;
      final nuevo = actual + 1;
      tx.set(ref, {'ultimoNumero': nuevo}, SetOptions(merge: true));
      return nuevo;
    });
    return siguiente.toString().padLeft(4, '0');
  }

  /// Busca en la colección 'productos' el que mejor coincida con el título
  /// del trabajo (por palabras en común) y devuelve su campo 'garantia'
  /// separado en fábrica/instalación si el texto lo permite. Si no hay
  /// coincidencia clara, ambos quedan vacíos para completar a mano.
  Future<Map<String, String>> _buscarGarantiaProducto(String tituloJob) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('productos').get();
      final palabrasTitulo = _palabrasClave(tituloJob);
      if (palabrasTitulo.isEmpty) return {'fabrica': '', 'instalacion': ''};

      String? mejorGarantia;
      int mejorPuntaje = 0;

      for (final doc in snap.docs) {
        final garantia = (doc.data()['garantia'] ?? '').toString().trim();
        if (garantia.isEmpty) continue;

        final nombre = (doc.data()['nombre'] ?? '').toString();
        final palabrasNombre = _palabrasClave(nombre);
        final comunes = palabrasTitulo.intersection(palabrasNombre).length;

        if (comunes > mejorPuntaje) {
          mejorPuntaje = comunes;
          mejorGarantia = garantia;
        }
      }

      if (mejorGarantia == null || mejorPuntaje == 0) {
        return {'fabrica': '', 'instalacion': ''};
      }

      final regex = RegExp(r'([^+]*fábrica[^+]*)\+?\s*([^+]*instalaci[oó]n[^+]*)?', caseSensitive: false);
      final m = regex.firstMatch(mejorGarantia);
      if (m != null && (m.group(1) ?? '').trim().isNotEmpty) {
        return {
          'fabrica': (m.group(1) ?? '').trim(),
          'instalacion': (m.group(2) ?? '').trim(),
        };
      }
      return {'fabrica': mejorGarantia, 'instalacion': ''};
    } catch (_) {
      return {'fabrica': '', 'instalacion': ''};
    }
  }

  Set<String> _palabrasClave(String texto) {
    var out = texto.toLowerCase();
    const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ñ': 'n'};
    acentos.forEach((k, v) => out = out.replaceAll(k, v));
    out = out.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return out.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
  }

  void _agregarFilaDetalle() {
    setState(() => _detalle.add(_DetalleRowControllers()));
  }

  void _eliminarFilaDetalle(int i) {
    setState(() {
      _detalle[i].dispose();
      _detalle.removeAt(i);
    });
  }

  Future<void> _elegirFecha() async {
    final nueva = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (nueva != null) setState(() => _fecha = nueva);
  }

  CertificadoGarantiaData _armarData() => CertificadoGarantiaData(
    numeroGarantia: _numeroCtrl.text.trim(),
    fecha: _fecha,
    clienteNombre: _clienteCtrl.text.trim(),
    clienteTelefono: _telefonoCtrl.text.trim(),
    clienteDireccion: _direccionCtrl.text.trim(),
    detalle: _detalle.map((d) => d.toItem()).toList(),
    formaPago: _formaPagoCtrl.text.trim(),
    garantiaFabrica: _garantiaFabricaCtrl.text.trim(),
    garantiaInstalacion: _garantiaInstalacionCtrl.text.trim(),
  );

  Future<void> _verVistaPrevia() async {
    if (_telefonoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta el teléfono del cliente')),
      );
      return;
    }

    setState(() => _generandoPreview = true);
    Uint8List bytes;
    try {
      bytes = await CertificadoGarantiaPdf.build(_armarData());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando el PDF: $e')));
      }
      return;
    } finally {
      if (mounted) setState(() => _generandoPreview = false);
    }

    if (!mounted) return;
    final confirmado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PreviewCertificadoScreen(
          bytes: bytes,
          onConfirmar: () => _confirmarYEnviar(bytes),
        ),
      ),
    );

    if (confirmado == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _confirmarYEnviar(Uint8List bytes) async {
    final telefono = _telefonoCtrl.text.trim();
    final numero = _numeroCtrl.text.trim();

    final storageRef = FirebaseStorage.instance.ref('garantias/$telefono/$numero.pdf');
    await storageRef.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    final pdfUrl = await storageRef.getDownloadURL();

    final resp = await http.post(
      Uri.parse('${BotConfig.baseUrl}/enviar-documento'),
      headers: {'Content-Type': 'application/json', 'X-Api-Key': BotConfig.apiKey},
      body: jsonEncode({
        'telefono': telefono,
        'documentoUrl': pdfUrl,
        'filename': 'Certificado_Garantia_$numero.pdf',
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    await widget.garantiasRepo.attachCertificado(
      job: widget.job,
      numeroGarantia: numero,
      pdfUrl: pdfUrl,
    );

    await widget.jobsRepo.updateJobInDay(
      day: widget.day,
      id: widget.job.id,
      numeroGarantiaCertificado: numero,
    );

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd(kLocaleEs);

    return Scaffold(
      appBar: AppBar(title: const Text('Certificado de garantía')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('No. Garantía'),
            _campo(_numeroCtrl),
            const SizedBox(height: 12),

            _label('Fecha'),
            InkWell(
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: const InputDecoration(filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderSide: BorderSide.none)),
                child: Text(df.format(_fecha)),
              ),
            ),
            const SizedBox(height: 12),

            _label('Cliente'),
            _campo(_clienteCtrl),
            const SizedBox(height: 12),

            _label('Teléfono'),
            _campo(_telefonoCtrl, tipo: TextInputType.phone),
            const SizedBox(height: 12),

            _label('Dirección'),
            _campo(_direccionCtrl),
            const SizedBox(height: 20),

            _label('Detalle del trabajo'),
            for (var i = 0; i < _detalle.length; i++) _filaDetalle(i),
            TextButton.icon(
              onPressed: _agregarFilaDetalle,
              icon: const Icon(Icons.add),
              label: const Text('Agregar fila'),
            ),
            const SizedBox(height: 12),

            _label('Forma de pago'),
            _campo(_formaPagoCtrl, hint: 'Ej: Transferencia, contado, etc.'),
            const SizedBox(height: 20),

            _label('Garantía de fábrica'),
            _campo(_garantiaFabricaCtrl, hint: 'Ej: 2 años'),
            const SizedBox(height: 12),

            _label('Garantía de instalación'),
            _campo(_garantiaInstalacionCtrl, hint: 'Ej: 1 año'),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _generandoPreview ? null : _verVistaPrevia,
                style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _generandoPreview
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Vista previa', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDetalle(int i) {
    final d = _detalle[i];
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 60, child: _campo(d.cantidad, hint: 'Cant.', tipo: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _campo(d.descripcion, hint: 'Descripción')),
                if (_detalle.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                    onPressed: () => _eliminarFilaDetalle(i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _campo(d.precio, hint: 'Precio')),
                const SizedBox(width: 8),
                Expanded(child: _campo(d.total, hint: 'Total')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(texto, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
  );

  Widget _campo(TextEditingController ctrl, {String? hint, TextInputType tipo = TextInputType.text}) => TextField(
    controller: ctrl,
    keyboardType: tipo,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

class _PreviewCertificadoScreen extends StatefulWidget {
  const _PreviewCertificadoScreen({required this.bytes, required this.onConfirmar});

  final Uint8List bytes;
  final Future<bool> Function() onConfirmar;

  @override
  State<_PreviewCertificadoScreen> createState() => _PreviewCertificadoScreenState();
}

class _PreviewCertificadoScreenState extends State<_PreviewCertificadoScreen> {
  bool _enviando = false;

  Future<void> _confirmar() async {
    setState(() => _enviando = true);
    try {
      final ok = await widget.onConfirmar();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error enviando el certificado: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa'),
        actions: [
          TextButton.icon(
            onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.edit, color: kGold),
            label: const Text('Editar', style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PdfPreview(
        build: (format) => widget.bytes,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: false,
        allowSharing: false,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _enviando ? null : _confirmar,
              style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _enviando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirmar y enviar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
