import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:portones_mym/data/models/job_item.dart';

/// Bottom sheet para elegir productos del catálogo y agregarlos como líneas
/// de "Detalle del trabajo". Es un widget separado de _ProductosBottomSheet
/// (usado en whatsapp_tab.dart para MANDAR productos por WhatsApp) a
/// propósito: son casos de uso distintos y no vale la pena arriesgar ese
/// flujo en producción para compartir ~80 líneas.
///
/// Devuelve la lista de líneas elegidas via Navigator.pop, o null si se
/// cancela.
class SelectorProductosSheet extends StatefulWidget {
  const SelectorProductosSheet({super.key});

  static Future<List<DetalleTrabajoLinea>?> show(BuildContext context) {
    return showModalBottomSheet<List<DetalleTrabajoLinea>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const SelectorProductosSheet(),
    );
  }

  @override
  State<SelectorProductosSheet> createState() => _SelectorProductosSheetState();
}

class _SelectorProductosSheetState extends State<SelectorProductosSheet>
    with SingleTickerProviderStateMixin {
  final Map<String, DetalleTrabajoLinea> _seleccionados = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggle(String id, DetalleTrabajoLinea linea) {
    setState(() {
      if (_seleccionados.containsKey(id)) {
        _seleccionados.remove(id);
      } else {
        _seleccionados[id] = linea;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.80,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.settings, color: Color(0xFF25D366)),
                const SizedBox(width: 8),
                const Expanded(child: Text('Agregar del catálogo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                if (_seleccionados.isNotEmpty)
                  Text('${_seleccionados.length} sel.',
                      style: const TextStyle(color: Color(0xFF25D366), fontSize: 13)),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF25D366),
            labelColor: const Color(0xFF25D366),
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'MOTORES'),
              Tab(text: 'ACCESORIOS'),
              Tab(text: 'SERVICIOS'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ListaSeleccionCatalogo(categoria: 'motor', seleccionados: _seleccionados, onToggle: _toggle, scrollCtrl: scrollCtrl),
                _ListaSeleccionCatalogo(categoria: 'accesorio', seleccionados: _seleccionados, onToggle: _toggle, scrollCtrl: scrollCtrl),
                _ListaSeleccionCatalogo(categoria: 'servicio', seleccionados: _seleccionados, onToggle: _toggle, scrollCtrl: scrollCtrl),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _seleccionados.isEmpty
                      ? null
                      : () => Navigator.pop(context, _seleccionados.values.toList()),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(
                    _seleccionados.isEmpty
                        ? 'Seleccioná un producto'
                        : 'Agregar ${_seleccionados.length} producto${_seleccionados.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaSeleccionCatalogo extends StatelessWidget {
  const _ListaSeleccionCatalogo({
    required this.categoria,
    required this.seleccionados,
    required this.onToggle,
    required this.scrollCtrl,
  });

  final String categoria;
  final Map<String, DetalleTrabajoLinea> seleccionados;
  final void Function(String id, DetalleTrabajoLinea linea) onToggle;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .where('activo', isEqualTo: true)
          .where('categoria', isEqualTo: categoria)
          .orderBy('orden')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return Center(child: Text('Sin ${categoria}s activos', style: const TextStyle(color: Colors.white38)));
        return ListView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final nombre = (data['nombre'] ?? id).toString();
            final precioTexto = (data['precio'] ?? '').toString();
            final precioNumerico = (data['precioNumerico'] as num?)?.toDouble() ?? 0;
            final imagen = (data['mediaImagen'] ?? '').toString();
            final seleccionado = seleccionados.containsKey(id);

            return CheckboxListTile(
              value: seleccionado,
              activeColor: const Color(0xFF25D366),
              onChanged: (_) => onToggle(id, DetalleTrabajoLinea(
                productoId: id,
                nombre: nombre,
                categoria: categoria,
                precio: precioNumerico,
              )),
              secondary: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imagen.isNotEmpty
                    ? Image.network(imagen, width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconoDefault(categoria))
                    : _iconoDefault(categoria),
              ),
              title: Text(nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                precioNumerico > 0 ? '₡${precioNumerico.toStringAsFixed(0)}' : (precioTexto.isEmpty ? 'Sin precio' : precioTexto),
                style: TextStyle(fontSize: 12, color: precioNumerico > 0 ? Colors.white54 : Colors.amber),
              ),
            );
          },
        );
      },
    );
  }

  Widget _iconoDefault(String categoria) {
    IconData icon;
    if (categoria == 'motor') icon = Icons.settings;
    else if (categoria == 'accesorio') icon = Icons.cable;
    else icon = Icons.build;
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: Colors.white38),
    );
  }
}
