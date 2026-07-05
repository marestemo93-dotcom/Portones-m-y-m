import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:portones_mym/core/constants/app_constants.dart' show kLocaleEs;

class DetalleTrabajoItem {
  String cantidad;
  String descripcion;
  String precio;
  String total;

  DetalleTrabajoItem({
    this.cantidad = '1',
    this.descripcion = '',
    this.precio = '',
    this.total = '',
  });
}

class CertificadoGarantiaData {
  final String numeroGarantia;
  final DateTime fecha;
  final String clienteNombre;
  final String clienteTelefono;
  final String clienteDireccion;
  final List<DetalleTrabajoItem> detalle;
  final String formaPago;
  final String garantiaFabrica;
  final String garantiaInstalacion;

  CertificadoGarantiaData({
    required this.numeroGarantia,
    required this.fecha,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.clienteDireccion,
    required this.detalle,
    required this.formaPago,
    required this.garantiaFabrica,
    required this.garantiaInstalacion,
  });
}

class CertificadoGarantiaPdf {
  static const _dorado = PdfColor.fromInt(0xFFFFC857);
  static const _grisTexto = PdfColor.fromInt(0xFF2A2A2A);

  static Future<Uint8List> build(CertificadoGarantiaData data) async {
    final doc = pw.Document();

    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final logoBytes = (await rootBundle.load('assets/images/logo_mym.png')).buffer.asUint8List();
    final marcaAguaBytes = (await rootBundle.load('assets/images/marca_agua_mym.png')).buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);
    final marcaAgua = pw.MemoryImage(marcaAguaBytes);

    final fechaTexto = DateFormat.yMMMMd(kLocaleEs).format(data.fecha);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
          margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 30),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Stack(
              children: [
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.15,
                      child: pw.Image(marcaAgua, width: 320),
                    ),
                  ),
                ),
                pw.Positioned.fill(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _dorado, width: 2.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logo, height: 64),
            pw.SizedBox(height: 8),
            pw.Text(
              'CERTIFICADO OFICIAL DE GARANTÍA',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _grisTexto),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'MYM PORTONES Y SISTEMAS AUTOMÁTICOS - Seguridad • Calidad • Confianza',
              style: const pw.TextStyle(fontSize: 9, color: _dorado),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: _dorado, thickness: 1),
          ],
        ),
        build: (context) => [
          _seccion('Información del cliente'),
          _fila('No. Garantía', data.numeroGarantia),
          _fila('Fecha', fechaTexto),
          _fila('Cliente', data.clienteNombre),
          _fila('Teléfono', data.clienteTelefono),
          _fila('Dirección', data.clienteDireccion),
          pw.SizedBox(height: 12),

          _seccion('Detalle del trabajo'),
          _tablaDetalle(data.detalle),
          pw.SizedBox(height: 12),

          _seccion('Forma de pago'),
          pw.Text(
            data.formaPago.trim().isEmpty ? '—' : data.formaPago,
            style: const pw.TextStyle(fontSize: 10, color: _grisTexto),
          ),
          pw.SizedBox(height: 12),

          _seccion('Garantía'),
          _fila('Garantía de fábrica', data.garantiaFabrica.trim().isEmpty ? '—' : data.garantiaFabrica),
          _fila('Garantía de instalación', data.garantiaInstalacion.trim().isEmpty ? '—' : data.garantiaInstalacion),
          pw.SizedBox(height: 12),

          _seccion('Condiciones'),
          _condiciones(),
          pw.SizedBox(height: 28),

          _firma('Firma del cliente'),
          pw.SizedBox(height: 24),
          _firma('Firma del gerente', nombre: 'Marco Esteban Loaiza Mora', detalle: 'Cédula 1-1528-0523 • Gerente'),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _seccion(String titulo) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      titulo.toUpperCase(),
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _dorado, letterSpacing: 0.6),
    ),
  );

  static pw.Widget _fila(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _grisTexto)),
          pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10, color: _grisTexto)),
        ],
      ),
    ),
  );

  static pw.Widget _tablaDetalle(List<DetalleTrabajoItem> detalle) {
    return pw.Table(
      border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCCCCCC), width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3EAD3)),
          children: [
            _celda('Cant.', bold: true),
            _celda('Descripción', bold: true),
            _celda('Precio', bold: true),
            _celda('Total', bold: true),
          ],
        ),
        for (final item in detalle)
          pw.TableRow(
            children: [
              _celda(item.cantidad),
              _celda(item.descripcion),
              _celda(item.precio),
              _celda(item.total),
            ],
          ),
      ],
    );
  }

  static pw.Widget _celda(String texto, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      texto,
      style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: _grisTexto),
    ),
  );

  static pw.Widget _condiciones() {
    const items = [
      'Aplica por defectos de fabricación e instalación.',
      'No cubre golpes, mal uso, modificaciones, humedad, vandalismo o falta de mantenimiento.',
      'Este certificado debe presentarse para hacer válida la garantía.',
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final texto in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text('•  $texto', style: const pw.TextStyle(fontSize: 9.5, color: _grisTexto)),
          ),
      ],
    );
  }

  static pw.Widget _firma(String etiqueta, {String? nombre, String? detalle}) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(width: 220, height: 0.8, color: const PdfColor.fromInt(0xFF999999)),
      pw.SizedBox(height: 4),
      pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 9.5, color: _grisTexto)),
      if (nombre != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(nombre, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _grisTexto)),
      ],
      if (detalle != null)
        pw.Text(detalle, style: const pw.TextStyle(fontSize: 8.5, color: _grisTexto)),
    ],
  );
}
