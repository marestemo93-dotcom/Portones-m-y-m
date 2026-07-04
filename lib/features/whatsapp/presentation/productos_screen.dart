// lib/features/whatsapp/presentation/productos_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';

// ============================================================
// GUARD DE BIOMETRÍA
// ============================================================
class ProductosScreenGuard extends StatefulWidget {
  const ProductosScreenGuard({super.key});

  @override
  State<ProductosScreenGuard> createState() => _ProductosScreenGuardState();
}

class _ProductosScreenGuardState extends State<ProductosScreenGuard> {
  bool _autenticado = false;
  bool _verificando = true;

  @override
  void initState() {
    super.initState();
    _autenticar();
  }

  Future<void> _autenticar() async {
    final auth = LocalAuthentication();
    try {
      final isSupported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      if (!isSupported && !canCheck) {
        if (mounted) setState(() { _autenticado = true; _verificando = false; });
        return;
      }
      final ok = await auth.authenticate(
        localizedReason: 'Autenticá para acceder a Productos',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true, useErrorDialogs: true),
      );
      if (mounted) setState(() { _autenticado = ok; _verificando = false; });
      if (!ok && mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _verificando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error biometría: $e')));
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verificando) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_autenticado) return const Scaffold(body: Center(child: Text('Acceso denegado')));
    return const ProductosScreen();
  }
}

// ============================================================
// PANTALLA PRINCIPAL — dividida en MOTORES / ACCESORIOS / SERVICIOS
// ============================================================
class ProductosScreen extends StatelessWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.inventory_2, color: Color(0xFF25D366)),
              SizedBox(width: 8),
              Text('Productos'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF25D366)),
              tooltip: 'Agregar',
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AgregarProductoScreen(),
              )),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF25D366),
            labelColor: Color(0xFF25D366),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'MOTORES'),
              Tab(text: 'ACCESORIOS'),
              Tab(text: 'SERVICIOS'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ListaProductos(categoria: 'motor'),
            _ListaProductos(categoria: 'accesorio'),
            _ListaProductos(categoria: 'servicio'),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LISTA POR CATEGORÍA
// ============================================================
class _ListaProductos extends StatelessWidget {
  const _ListaProductos({required this.categoria});
  final String categoria;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .where('categoria', isEqualTo: categoria)
          .orderBy('orden')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox, color: Colors.white38, size: 48),
                const SizedBox(height: 12),
                Text('Sin $categoria s', style: const TextStyle(color: Colors.white38)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AgregarProductoScreen(categoriaInicial: categoria),
                  )),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF25D366)),
                ),
              ],
            ),
          );
        }

        final docs = snap.data!.docs;
        return ListView.separated(
          padding: EdgeInsets.only(
            left: 12, right: 12, top: 12,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
          ),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final nombre = (data['nombre'] ?? id).toString();
            final precio = (data['precio'] ?? '').toString();
            final activo = data['activo'] ?? true;
            final imagen = (data['mediaImagen'] ?? '').toString();

            return Card(
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imagen.isNotEmpty
                      ? Image.network(imagen, width: 50, height: 50, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconoProducto(categoria))
                      : _iconoProducto(categoria),
                ),
                title: Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: precio.isNotEmpty
                    ? Text(precio, style: const TextStyle(color: Color(0xFF25D366), fontSize: 12))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: activo,
                      activeColor: const Color(0xFF25D366),
                      onChanged: (v) => FirebaseFirestore.instance
                          .collection('productos').doc(id).update({'activo': v}),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ],
                ),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => EditarProductoScreen(id: id, data: data),
                )),
                onLongPress: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Borrar producto'),
                      content: Text('¿Borrar "$nombre"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Borrar'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await FirebaseFirestore.instance.collection('productos').doc(id).delete();
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _iconoProducto(String categoria) {
    IconData icon;
    if (categoria == 'motor') icon = Icons.settings;
    else if (categoria == 'accesorio') icon = Icons.cable;
    else icon = Icons.build;

    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: const Color(0xFF25D366), size: 24),
    );
  }
}

// ============================================================
// AGREGAR PRODUCTO
// ============================================================
class AgregarProductoScreen extends StatefulWidget {
  const AgregarProductoScreen({super.key, this.categoriaInicial});
  final String? categoriaInicial;

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _idCtrl       = TextEditingController();
  final _nombreCtrl   = TextEditingController();
  final _precioCtrl   = TextEditingController();
  final _garantiaCtrl = TextEditingController();
  final _notaCtrl     = TextEditingController();
  final _videoCtrl    = TextEditingController();
  final _ordenCtrl    = TextEditingController();
  String _categoria   = 'motor';
  final List<TextEditingController> _kitCtrls = [TextEditingController()];
  File? _imagenFile;
  bool _guardando     = false;

  @override
  void initState() {
    super.initState();
    if (widget.categoriaInicial != null) _categoria = widget.categoriaInicial!;
  }

  @override
  void dispose() {
    _idCtrl.dispose(); _nombreCtrl.dispose(); _precioCtrl.dispose();
    _garantiaCtrl.dispose(); _notaCtrl.dispose(); _videoCtrl.dispose();
    _ordenCtrl.dispose();
    for (final c in _kitCtrls) { c.dispose(); }
    super.dispose();
  }

  void _onKitFieldChanged(int i, String value) {
    final esUltimo = i == _kitCtrls.length - 1;
    if (esUltimo && value.trim().isNotEmpty) {
      setState(() => _kitCtrls.add(TextEditingController()));
    }
  }

  void _eliminarKitCampo(int i) {
    setState(() {
      _kitCtrls[i].dispose();
      _kitCtrls.removeAt(i);
      if (_kitCtrls.isEmpty) _kitCtrls.add(TextEditingController());
    });
  }

  Future<void> _seleccionarImagen() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _imagenFile = File(picked.path));
  }

  Future<String?> _subirImagen(String id) async {
    if (_imagenFile == null) return null;
    final ref = FirebaseStorage.instance.ref('motores/$id/${id}_image.png');
    await ref.putFile(_imagenFile!);
    return 'https://firebasestorage.googleapis.com/v0/b/portones-mym.firebasestorage.app/o/motores%2F${Uri.encodeComponent(id)}%2F${id}_image.png?alt=media';
  }

  Future<void> _guardar() async {
    final id = _idCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
    if (id.isEmpty || _nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID y nombre son obligatorios')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      String? imagenUrl;
      if (_imagenFile != null) imagenUrl = await _subirImagen(id);
      final orden = int.tryParse(_ordenCtrl.text.trim()) ?? 99;

      await FirebaseFirestore.instance.collection('productos').doc(id).set({
        'nombre':      _nombreCtrl.text.trim(),
        'precio':      _precioCtrl.text.trim(),
        'garantia':    _garantiaCtrl.text.trim(),
        'nota':        _notaCtrl.text.trim(),
        'mediaImagen': imagenUrl ?? '',
        'mediaVideo':  _videoCtrl.text.trim(),
        'categoria':   _categoria,
        'kit':         _categoria == 'motor'
            ? _kitCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
            : [],
        'activo':      true,
        'orden':       orden,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Producto creado'), backgroundColor: Color(0xFF25D366)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo producto'),
        actions: [
          if (_guardando)
            const Padding(padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.save, color: Color(0xFF25D366)), onPressed: _guardar),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Center(
              child: GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: _imagenFile != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(11),
                      child: Image.file(_imagenFile!, fit: BoxFit.cover))
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate, color: Color(0xFF25D366), size: 40),
                    SizedBox(height: 8),
                    Text('Subir imagen', style: TextStyle(color: Color(0xFF25D366), fontSize: 12)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Categoría
            _label('Categoría'),
            Row(
              children: [
                _chipCategoria('motor', 'Motor'),
                const SizedBox(width: 8),
                _chipCategoria('accesorio', 'Accesorio'),
                const SizedBox(width: 8),
                _chipCategoria('servicio', 'Servicio'),
              ],
            ),
            const SizedBox(height: 16),

            _label('ID del producto *'),
            _campo(_idCtrl, hint: 'Ej: control_vulcan (sin espacios)'),
            const SizedBox(height: 12),

            _label('Nombre *'),
            _campo(_nombreCtrl, hint: 'Ej: Control Vulcan'),
            const SizedBox(height: 12),

            _label('Precio'),
            _campo(_precioCtrl, hint: 'Ej: ₡17,000'),
            const SizedBox(height: 12),

            _label('Garantía'),
            _campo(_garantiaCtrl, hint: 'Ej: 1 año'),
            const SizedBox(height: 12),

            if (_categoria == 'motor') ...[
              _label('Kit incluye'),
              for (var i = 0; i < _kitCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Text('•  ', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      Expanded(
                        child: _campo(_kitCtrls[i],
                            hint: 'Ej: 2 controles para carro',
                            onChanged: (v) => _onKitFieldChanged(i, v)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                        onPressed: () => _eliminarKitCampo(i),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],

            _label('Nota (opcional)'),
            _campo(_notaCtrl, hint: 'Ej: Compatible con todos los motores'),
            const SizedBox(height: 12),

            _label('URL Video (opcional)'),
            _campo(_videoCtrl, hint: 'https://firebasestorage...'),
            const SizedBox(height: 12),

            _label('Orden en la lista'),
            _campo(_ordenCtrl, hint: 'Ej: 0 = primero', tipo: TextInputType.number),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Crear producto', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipCategoria(String valor, String label) => ChoiceChip(
    label: Text(label),
    selected: _categoria == valor,
    selectedColor: const Color(0xFF25D366),
    onSelected: (_) => setState(() => _categoria = valor),
    labelStyle: TextStyle(
      color: _categoria == valor ? Colors.black : Colors.white70,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _label(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(texto, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
  );

  Widget _campo(TextEditingController ctrl, {String? hint, TextInputType tipo = TextInputType.text, ValueChanged<String>? onChanged}) => TextField(
    controller: ctrl,
    keyboardType: tipo,
    onChanged: onChanged,
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

// ============================================================
// EDITAR PRODUCTO
// ============================================================
class EditarProductoScreen extends StatefulWidget {
  const EditarProductoScreen({super.key, required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  @override
  State<EditarProductoScreen> createState() => _EditarProductoScreenState();
}

class _EditarProductoScreenState extends State<EditarProductoScreen> {
  late TextEditingController _nombreCtrl;
  late TextEditingController _precioCtrl;
  late TextEditingController _garantiaCtrl;
  late TextEditingController _notaCtrl;
  late TextEditingController _videoCtrl;
  late String _categoria;
  late List<TextEditingController> _kitCtrls;
  File? _imagenFile;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl   = TextEditingController(text: widget.data['nombre'] ?? '');
    _precioCtrl   = TextEditingController(text: widget.data['precio'] ?? '');
    _garantiaCtrl = TextEditingController(text: widget.data['garantia'] ?? '');
    _notaCtrl     = TextEditingController(text: widget.data['nota'] ?? '');
    _videoCtrl    = TextEditingController(text: widget.data['mediaVideo'] ?? '');
    _categoria    = widget.data['categoria'] ?? 'motor';
    final kitGuardado = List<String>.from(widget.data['kit'] ?? []);
    _kitCtrls = [
      ...kitGuardado.map((s) => TextEditingController(text: s)),
      TextEditingController(),
    ];
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _precioCtrl.dispose(); _garantiaCtrl.dispose();
    _notaCtrl.dispose(); _videoCtrl.dispose();
    for (final c in _kitCtrls) { c.dispose(); }
    super.dispose();
  }

  void _onKitFieldChanged(int i, String value) {
    final esUltimo = i == _kitCtrls.length - 1;
    if (esUltimo && value.trim().isNotEmpty) {
      setState(() => _kitCtrls.add(TextEditingController()));
    }
  }

  void _eliminarKitCampo(int i) {
    setState(() {
      _kitCtrls[i].dispose();
      _kitCtrls.removeAt(i);
      if (_kitCtrls.isEmpty) _kitCtrls.add(TextEditingController());
    });
  }

  Future<void> _seleccionarImagen() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _imagenFile = File(picked.path));
  }

  Future<String?> _subirImagen() async {
    if (_imagenFile == null) return null;
    final id = widget.id;
    final ref = FirebaseStorage.instance.ref('motores/$id/${id}_image.png');
    await ref.putFile(_imagenFile!);
    return 'https://firebasestorage.googleapis.com/v0/b/portones-mym.firebasestorage.app/o/motores%2F${Uri.encodeComponent(id)}%2F${id}_image.png?alt=media';
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      String? imagenUrl;
      if (_imagenFile != null) imagenUrl = await _subirImagen();

      final update = {
        'nombre':    _nombreCtrl.text.trim(),
        'precio':    _precioCtrl.text.trim(),
        'garantia':  _garantiaCtrl.text.trim(),
        'nota':      _notaCtrl.text.trim(),
        'mediaVideo': _videoCtrl.text.trim(),
        'categoria': _categoria,
        'kit':       _categoria == 'motor'
            ? _kitCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
            : [],
        if (imagenUrl != null) 'mediaImagen': imagenUrl,
      };

      await FirebaseFirestore.instance.collection('productos').doc(widget.id).update(update);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Producto actualizado'), backgroundColor: Color(0xFF25D366)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar producto'),
        content: Text('¿Borrar "${widget.data['nombre']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await FirebaseFirestore.instance.collection('productos').doc(widget.id).delete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagenActual = (widget.data['mediaImagen'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id, style: const TextStyle(fontSize: 16)),
        actions: [
          if (_guardando)
            const Padding(padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else ...[
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: _borrar),
            IconButton(icon: const Icon(Icons.save, color: Color(0xFF25D366)), onPressed: _guardar),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Center(
              child: GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: _imagenFile != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(11),
                      child: Image.file(_imagenFile!, fit: BoxFit.cover))
                      : imagenActual.isNotEmpty
                      ? ClipRRect(borderRadius: BorderRadius.circular(11),
                      child: Image.network(imagenActual, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _iconoCamara()))
                      : _iconoCamara(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(child: Text('Tap para cambiar imagen',
                style: TextStyle(color: Colors.white38, fontSize: 11))),
            const SizedBox(height: 20),

            // Categoría
            _label('Categoría'),
            Row(
              children: [
                _chipCategoria('motor', 'Motor'),
                const SizedBox(width: 8),
                _chipCategoria('accesorio', 'Accesorio'),
                const SizedBox(width: 8),
                _chipCategoria('servicio', 'Servicio'),
              ],
            ),
            const SizedBox(height: 16),

            _label('Nombre'),
            _campo(_nombreCtrl),
            const SizedBox(height: 12),

            _label('Precio'),
            _campo(_precioCtrl, hint: 'Ej: ₡195,000 todo instalado'),
            const SizedBox(height: 12),

            _label('Garantía'),
            _campo(_garantiaCtrl),
            const SizedBox(height: 12),

            if (_categoria == 'motor') ...[
              _label('Kit incluye'),
              for (var i = 0; i < _kitCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Text('•  ', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      Expanded(
                        child: _campo(_kitCtrls[i],
                            hint: 'Ej: 2 controles para carro',
                            onChanged: (v) => _onKitFieldChanged(i, v)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                        onPressed: () => _eliminarKitCampo(i),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],

            _label('Nota (opcional)'),
            _campo(_notaCtrl),
            const SizedBox(height: 12),

            _label('URL Video (opcional)'),
            _campo(_videoCtrl, hint: 'https://firebasestorage...'),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipCategoria(String valor, String label) => ChoiceChip(
    label: Text(label),
    selected: _categoria == valor,
    selectedColor: const Color(0xFF25D366),
    onSelected: (_) => setState(() => _categoria = valor),
    labelStyle: TextStyle(
      color: _categoria == valor ? Colors.black : Colors.white70,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _iconoCamara() => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.add_photo_alternate, color: Color(0xFF25D366), size: 40),
      SizedBox(height: 8),
      Text('Cambiar imagen', style: TextStyle(color: Color(0xFF25D366), fontSize: 12)),
    ],
  );

  Widget _label(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(texto, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
  );

  Widget _campo(TextEditingController ctrl, {String? hint, TextInputType tipo = TextInputType.text, ValueChanged<String>? onChanged}) => TextField(
    controller: ctrl,
    keyboardType: tipo,
    onChanged: onChanged,
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