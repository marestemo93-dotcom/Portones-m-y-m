import 'package:flutter/material.dart';

import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/calendar/presentation/widgets/selector_productos_sheet.dart';

/// Controllers de edición de una línea. Las líneas de catálogo tienen precio
/// fijo (no editable); las manuales tienen nombre y precio editables.
class _LineaEditable {
  DetalleTrabajoLinea linea;
  late final TextEditingController nombreCtrl;
  late final TextEditingController precioCtrl;

  _LineaEditable(this.linea) {
    nombreCtrl = TextEditingController(text: linea.nombre);
    precioCtrl = TextEditingController(text: linea.precio > 0 ? linea.precio.toStringAsFixed(0) : '');
  }

  bool get esDeCatalogo => linea.productoId != null;

  /// Un producto de catálogo sin precioNumerico cargado (ej. "Cotización
  /// personalizada") necesita que el usuario complete el precio a mano.
  bool get necesitaPrecioManual => esDeCatalogo && linea.precio <= 0;

  double get precioActual {
    if (esDeCatalogo && !necesitaPrecioManual) return linea.precio;
    return double.tryParse(precioCtrl.text.trim().replaceAll(',', '')) ?? 0;
  }

  DetalleTrabajoLinea toLinea() => DetalleTrabajoLinea(
    productoId: linea.productoId,
    nombre: esDeCatalogo ? linea.nombre : nombreCtrl.text.trim(),
    categoria: linea.categoria,
    precio: precioActual,
  );

  void dispose() {
    nombreCtrl.dispose();
    precioCtrl.dispose();
  }
}

/// Editor embebido de "Detalle del trabajo": líneas de catálogo + manuales,
/// subtotal automático, descuento (monto o porcentaje), y total final.
///
/// Se usa en los 3 puntos donde se crea/edita un Trabajo: calendario,
/// WhatsApp, y edición de un job existente.
class DetalleTrabajoEditor extends StatefulWidget {
  const DetalleTrabajoEditor({
    super.key,
    required this.lineasIniciales,
    this.descuentoValorInicial,
    this.descuentoTipoInicial,
    required this.onChanged,
  });

  final List<DetalleTrabajoLinea> lineasIniciales;
  final double? descuentoValorInicial;
  final String? descuentoTipoInicial; // 'monto' | 'porcentaje'

  /// Se llama cada vez que cambia algo (líneas, descuento). Entrega las
  /// líneas actuales, el descuento y el total final calculado.
  final void Function(List<DetalleTrabajoLinea> lineas, double? descuentoValor, String descuentoTipo, double total) onChanged;

  @override
  State<DetalleTrabajoEditor> createState() => DetalleTrabajoEditorState();
}

class DetalleTrabajoEditorState extends State<DetalleTrabajoEditor> {
  final List<_LineaEditable> _lineas = [];
  final _descuentoCtrl = TextEditingController();
  String _descuentoTipo = 'monto';

  @override
  void initState() {
    super.initState();
    for (final l in widget.lineasIniciales) {
      _lineas.add(_LineaEditable(l));
    }
    if (_lineas.isEmpty) {
      _lineas.add(_LineaEditable(DetalleTrabajoLinea(nombre: '', precio: 0)));
    }
    _descuentoTipo = widget.descuentoTipoInicial ?? 'monto';
    if (widget.descuentoValorInicial != null && widget.descuentoValorInicial! > 0) {
      _descuentoCtrl.text = _descuentoTipo == 'porcentaje'
          ? widget.descuentoValorInicial!.toStringAsFixed(0)
          : widget.descuentoValorInicial!.toStringAsFixed(0);
    }
    _descuentoCtrl.addListener(_notify);
  }

  @override
  void dispose() {
    for (final l in _lineas) {
      l.dispose();
    }
    _descuentoCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _lineas.fold(0.0, (acc, l) => acc + l.precioActual);

  double get _descuentoAplicado {
    final valor = double.tryParse(_descuentoCtrl.text.trim().replaceAll(',', '')) ?? 0;
    if (valor <= 0) return 0;
    if (_descuentoTipo == 'porcentaje') return _subtotal * (valor / 100);
    return valor;
  }

  double get _total {
    final t = _subtotal - _descuentoAplicado;
    return t < 0 ? 0 : t;
  }

  void _notify() {
    setState(() {});
    final descuentoValor = double.tryParse(_descuentoCtrl.text.trim().replaceAll(',', ''));
    widget.onChanged(
      _lineas.map((l) => l.toLinea()).where((l) => l.nombre.trim().isNotEmpty).toList(),
      (descuentoValor != null && descuentoValor > 0) ? descuentoValor : null,
      _descuentoTipo,
      _total,
    );
  }

  Future<void> _abrirSelectorCatalogo() async {
    final elegidos = await SelectorProductosSheet.show(context);
    if (elegidos == null || elegidos.isEmpty) return;
    setState(() {
      // La primera línea manual vacía se reemplaza en vez de acumularse.
      if (_lineas.length == 1 && !_lineas.first.esDeCatalogo && _lineas.first.nombreCtrl.text.trim().isEmpty) {
        _lineas.first.dispose();
        _lineas.clear();
      }
      for (final linea in elegidos) {
        _lineas.add(_LineaEditable(linea));
      }
    });
    _notify();
  }

  void _agregarLineaManual() {
    setState(() => _lineas.add(_LineaEditable(DetalleTrabajoLinea(nombre: '', precio: 0))));
  }

  void _eliminarLinea(int i) {
    setState(() {
      _lineas[i].dispose();
      _lineas.removeAt(i);
      if (_lineas.isEmpty) {
        _lineas.add(_LineaEditable(DetalleTrabajoLinea(nombre: '', precio: 0)));
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _lineas.length; i++) _filaLinea(i),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _abrirSelectorCatalogo,
                icon: const Icon(Icons.storefront, size: 18),
                label: const Text('Del catálogo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _agregarLineaManual,
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Manual'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _descuentoCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Descuento',
                  hintText: _descuentoTipo == 'porcentaje' ? 'Ej: 10' : 'Ej: 15000',
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'monto', label: Text('₡')),
                ButtonSegment(value: 'porcentaje', label: Text('%')),
              ],
              selected: {_descuentoTipo},
              onSelectionChanged: (s) {
                setState(() => _descuentoTipo = s.first);
                _notify();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _resumenFila('Subtotal', _subtotal),
              if (_descuentoAplicado > 0) _resumenFila('Descuento', -_descuentoAplicado),
              const Divider(height: 16),
              _resumenFila('Total', _total, destacado: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filaLinea(int i) {
    final l = _lineas[i];
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: l.esDeCatalogo
                      ? Text(l.linea.nombre, style: const TextStyle(fontWeight: FontWeight.w600))
                      : TextField(
                    controller: l.nombreCtrl,
                    decoration: const InputDecoration(hintText: 'Descripción', isDense: true),
                    onChanged: (_) => _notify(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                  onPressed: () => _eliminarLinea(i),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (l.necesitaPrecioManual)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('Este producto no tiene precio de catálogo — completalo:', style: TextStyle(color: Colors.amber, fontSize: 12))),
                  ],
                ),
              ),
            if (l.necesitaPrecioManual) const SizedBox(height: 6),
            if (!l.esDeCatalogo || l.necesitaPrecioManual)
              TextField(
                controller: l.precioCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(prefixText: '₡ ', hintText: 'Precio', isDense: true),
                onChanged: (_) => _notify(),
              )
            else
              Text('₡${l.linea.precio.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _resumenFila(String label, double valor, {bool destacado = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: destacado ? 15 : 13,
          fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
          color: destacado ? Colors.white : Colors.white70,
        )),
        Text('₡${valor.toStringAsFixed(0)}', style: TextStyle(
          fontSize: destacado ? 15 : 13,
          fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
          color: destacado ? const Color(0xFF25D366) : Colors.white70,
        )),
      ],
    ),
  );
}
