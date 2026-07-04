// lib/features/whatsapp/presentation/whatsapp_tab.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:portones_mym/core/constants/bot_config.dart';
import 'productos_screen.dart';
import 'agendar_bottom_sheet.dart';

class WhatsappTab extends StatelessWidget {
  const WhatsappTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ConversacionesList();
  }
}

class _ConversacionesList extends StatefulWidget {
  const _ConversacionesList();

  @override
  State<_ConversacionesList> createState() => _ConversacionesListState();
}

class _ConversacionesListState extends State<_ConversacionesList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.chat, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('WhatsApp'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, color: Color(0xFF25D366)),
            tooltip: 'Productos',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ProductosScreenGuard(),
            )),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar conversacion...',
                filled: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('conversaciones').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white38),
                      SizedBox(height: 12),
                      Text('Sin conversaciones aun', style: TextStyle(color: Colors.white54)),
                    ]),
                  );
                }

                var docs = snap.data!.docs.where((doc) {
                  if (_q.trim().isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final telefono = (data['telefono'] ?? '').toString().toLowerCase();
                  final nombre = ((data['nombreCliente'] ?? '') as String).toLowerCase();
                  final s = _q.toLowerCase();
                  return telefono.contains(s) || nombre.contains(s);
                }).toList();

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = (aData['ultimoContacto'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  final bTime = (bData['ultimoContacto'] as Timestamp?)?.toDate() ?? DateTime(2000);
                  return bTime.compareTo(aTime);
                });

                if (docs.isEmpty) return const Center(child: Text('Sin resultados'));

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _ConversacionTile(docId: docs[i].id, data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversacionTile extends StatelessWidget {
  const _ConversacionTile({required this.docId, required this.data});
  final String docId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final telefono = (data['telefono'] ?? docId).toString();
    final historial = data['historial'] as List<dynamic>? ?? [];
    final nombre = (data['nombreCliente'] ?? '').toString();
    final provincia = (data['provinciaCliente'] ?? '').toString();
    final ultimoMensaje = _ultimoMensaje(historial);
    final ultimoContacto = (data['ultimoContacto'] as Timestamp?)?.toDate();
    final cantidadMensajes = historial.length;
    final modoManual = data['modoManual'] ?? false;
    final hayMensajeNuevo = historial.isNotEmpty && (historial.last as Map)['role'] == 'user';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.2),
        child: Text(_inicial(nombre, telefono),
            style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              nombre.isNotEmpty ? nombre : _formatTelefono(telefono),
              style: TextStyle(fontWeight: hayMensajeNuevo ? FontWeight.bold : FontWeight.normal),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          if (modoManual)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Text('Manual', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          if (ultimoContacto != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(_formatFecha(ultimoContacto),
                  style: TextStyle(fontSize: 11, color: hayMensajeNuevo ? const Color(0xFF25D366) : Colors.white38)),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provincia.isNotEmpty)
            Text(provincia, style: const TextStyle(color: Color(0xFF25D366), fontSize: 11)),
          Row(
            children: [
              Expanded(
                child: Text(ultimoMensaje, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hayMensajeNuevo ? Colors.white70 : Colors.white38,
                      fontWeight: hayMensajeNuevo ? FontWeight.w500 : FontWeight.normal,
                    )),
              ),
              if (hayMensajeNuevo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(10)),
                  child: Text('$cantidadMensajes',
                      style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(telefono: telefono, nombre: nombre, data: data),
      )),
    );
  }

  String _inicial(String nombre, String telefono) {
    if (nombre.isNotEmpty) return nombre[0].toUpperCase();
    return telefono.isNotEmpty ? telefono[telefono.length - 1] : '?';
  }

  String _formatTelefono(String t) {
    if (t.startsWith('506') && t.length == 11) return '+506 ${t.substring(3, 7)}-${t.substring(7)}';
    return t;
  }

  String _ultimoMensaje(List<dynamic> historial) {
    if (historial.isEmpty) return 'Sin mensajes';
    final ultimo = historial.last as Map;
    final content = (ultimo['content'] ?? '').toString();
    final role = ultimo['role'] ?? '';
    if (content.startsWith('[imagen:')) return role == 'assistant' ? '⚙️ 📷 Imagen' : '👤 📷 Imagen';
    if (content.startsWith('[audio:')) return role == 'assistant' ? '⚙️ 🎵 Audio' : '👤 🎵 Audio';
    final prefix = role == 'assistant' ? '⚙️ ' : '👤 ';
    return '$prefix$content';
  }

  String _formatFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diff = ahora.difference(fecha);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return DateFormat('HH:mm').format(fecha);
    if (diff.inDays < 7) return DateFormat('EEE', 'es').format(fecha);
    return DateFormat('dd/MM').format(fecha);
  }
}

// ============================================================
// CHAT SCREEN
// ============================================================
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.telefono, required this.nombre, required this.data});
  final String telefono;
  final String nombre;
  final Map<String, dynamic> data;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _recorder = FlutterSoundRecorder();
  bool _enviando = false;
  bool _grabando = false;
  bool _grabacionBloqueada = false;
  static const double _umbralCancelar = -80;
  static const double _umbralBloquear = -60;
  bool _recorderIniciado = false;
  String? _rutaGrabacion;
  DateTime? _inicioGrabacion;
  Timer? _grabTimer;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _iniciarRecorder();
  }

  Future<void> _iniciarRecorder() async {
    // Si el permiso todavia no esta concedido, no abrimos el grabador aca:
    // se reintenta en _iniciarGrabacion cuando el usuario toque el boton
    // (ahi si pedimos el permiso). Evita que openRecorder() falle en frio
    // y deje _recorderIniciado en false para siempre.
    if (!await Permission.microphone.status.isGranted) return;
    await _recorder.openRecorder();
    setState(() => _recorderIniciado = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    _pulseController.dispose();
    _grabTimer?.cancel();
    super.dispose();
  }

  void _scrollAbajo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _tiempoGrabacion() {
    final segundos = _inicioGrabacion == null ? 0 : DateTime.now().difference(_inicioGrabacion!).inSeconds;
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleModoManual(bool actual) async {
    final ref = FirebaseFirestore.instance.collection('conversaciones').doc(widget.telefono);

    if (!actual) {
      // Se está ACTIVANDO manual (humano toma la conversación): corta el
      // flujo automático del bot ahí mismo, sin importar en que paso estaba.
      await ref.update({'modoManual': true, 'estado': 'modo_manual'});
      return;
    }

    // Se está DESACTIVANDO manual (reactivar el bot): resetea el estado
    // interno del bot en el servidor. Los strings deben coincidir
    // exactamente con ESTADOS en bot.js.
    final doc = await ref.get();
    final data = doc.data() ?? {};
    final tieneNombreYProvincia =
        ((data['nombreCliente'] as String?)?.trim().isNotEmpty ?? false) &&
        ((data['provinciaCliente'] as String?)?.trim().isNotEmpty ?? false);

    await ref.update({
      'modoManual': false,
      'estado': tieneNombreYProvincia ? 'reactivado' : 'esperando_nombre',
    });
  }

  Future<void> _enviarTexto(String texto) async {
    if (texto.trim().isEmpty) return;
    setState(() => _enviando = true);
    _controller.clear();
    try {
      final response = await http.post(
        Uri.parse('${BotConfig.baseUrl}/enviar-texto-manual'),
        headers: {'Content-Type': 'application/json', 'X-Api-Key': BotConfig.apiKey},
        body: jsonEncode({'telefono': widget.telefono, 'texto': texto}),
      );
      if (response.statusCode == 200) {
        _scrollAbajo();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      final ref = FirebaseFirestore.instance.collection('conversaciones').doc(widget.telefono);
      final doc = await ref.get();
      final historial = List<Map<String, dynamic>>.from(
        (doc.data()?['historial'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      historial.add({'role': 'assistant', 'content': texto, 'timestamp': DateTime.now().toIso8601String()});
      await ref.update({'historial': historial, 'ultimoContacto': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarImagen() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _enviando = true);
    try {
      final bytes = await picked.readAsBytes();
      final base64Img = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('${BotConfig.baseUrl}/enviar-imagen'),
        headers: {'Content-Type': 'application/json', 'X-Api-Key': BotConfig.apiKey},
        body: jsonEncode({'telefono': widget.telefono, 'imagenBase64': base64Img, 'mimeType': 'image/jpeg'}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final storageUrl = data['storageUrl'];
        final ref = FirebaseFirestore.instance.collection('conversaciones').doc(widget.telefono);
        final doc = await ref.get();
        final historial = List<Map<String, dynamic>>.from(
          (doc.data()?['historial'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        historial.add({'role': 'assistant', 'content': '[imagen:$storageUrl]', 'timestamp': DateTime.now().toIso8601String()});
        await ref.update({'historial': historial, 'ultimoContacto': FieldValue.serverTimestamp()});
        _scrollAbajo();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _abrirSelectorProductos() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductosBottomSheet(telefono: widget.telefono),
    );
  }

  Future<void> _abrirAgendarSheet() async {
    final doc = await FirebaseFirestore.instance
        .collection('conversaciones')
        .doc(widget.telefono)
        .get();
    final datos = doc.data() ?? {};
    final nombre = (datos['nombreCliente'] ?? widget.nombre).toString();
    final provincia = (datos['provinciaCliente'] ?? '').toString();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AgendarBottomSheet(
        telefono: widget.telefono,
        nombreCliente: nombre.isNotEmpty ? nombre : widget.nombre,
        provinciaCliente: provincia,
      ),
    );
  }

  Future<void> _iniciarGrabacion() async {
    final permiso = await Permission.microphone.request();
    if (!permiso.isGranted) return;
    if (!_recorderIniciado) {
      await _recorder.openRecorder();
      setState(() => _recorderIniciado = true);
    }
    final dir = await getTemporaryDirectory();
    _rutaGrabacion = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: _rutaGrabacion, codec: Codec.aacADTS);
    _inicioGrabacion = DateTime.now();
    _pulseController.repeat(reverse: true);
    _grabTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    setState(() {
      _grabando = true;
      _grabacionBloqueada = false;
    });
  }

  void _onGrabacionMove(LongPressMoveUpdateDetails details) {
    if (!_grabando || _grabacionBloqueada) return;
    final dx = details.offsetFromOrigin.dx;
    final dy = details.offsetFromOrigin.dy;

    if (dx < _umbralCancelar) {
      _cancelarGrabacion();
      return;
    }
    if (dy < _umbralBloquear) {
      setState(() => _grabacionBloqueada = true);
    }
  }

  Future<void> _cancelarGrabacion() async {
    await _recorder.stopRecorder();
    _pulseController.stop();
    _pulseController.reset();
    _grabTimer?.cancel();
    _grabTimer = null;

    final ruta = _rutaGrabacion;
    _rutaGrabacion = null;
    if (ruta != null) {
      final f = File(ruta);
      if (await f.exists()) await f.delete();
    }

    setState(() {
      _grabando = false;
      _grabacionBloqueada = false;
    });
  }

  Future<void> _detenerYEnviarAudio() async {
    await _recorder.stopRecorder();
    _pulseController.stop();
    _pulseController.reset();
    _grabTimer?.cancel();
    _grabTimer = null;
    setState(() {
      _grabando = false;
      _grabacionBloqueada = false;
    });
    if (_rutaGrabacion == null) return;
    setState(() => _enviando = true);
    try {
      final bytes = await File(_rutaGrabacion!).readAsBytes();
      final base64Audio = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('${BotConfig.baseUrl}/enviar-audio'),
        headers: {'Content-Type': 'application/json', 'X-Api-Key': BotConfig.apiKey},
        body: jsonEncode({'telefono': widget.telefono, 'audioBase64': base64Audio}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final storageUrl = data['storageUrl'];
        final ref = FirebaseFirestore.instance.collection('conversaciones').doc(widget.telefono);
        final doc = await ref.get();
        final historial = List<Map<String, dynamic>>.from(
          (doc.data()?['historial'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        historial.add({'role': 'assistant', 'content': '[audio:$storageUrl]', 'timestamp': DateTime.now().toIso8601String()});
        await ref.update({'historial': historial, 'ultimoContacto': FieldValue.serverTimestamp()});
        _scrollAbajo();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('conversaciones').doc(widget.telefono).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final modoManual = data['modoManual'] ?? false;
        final historial = data['historial'] as List<dynamic>? ?? [];

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollAbajo());

        return Scaffold(
          appBar: AppBar(
            leadingWidth: 40,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.2),
                  child: Text(widget.nombre.isNotEmpty ? widget.nombre[0].toUpperCase() : '?',
                      style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.nombre.isNotEmpty ? widget.nombre : _formatTelefono(widget.telefono),
                          style: const TextStyle(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          Flexible(
                            child: Text(_formatTelefono(widget.telefono),
                                style: const TextStyle(fontSize: 12, color: Colors.white54),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if ((widget.data['provinciaCliente'] ?? '').toString().isNotEmpty) ...[
                            const Text('  •  ', style: TextStyle(fontSize: 12, color: Colors.white38)),
                            Flexible(
                              child: Text((widget.data['provinciaCliente'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF25D366)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              GestureDetector(
                onTap: () => _toggleModoManual(modoManual),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: modoManual ? Colors.orange : const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(modoManual ? Icons.person : Icons.smart_toy, size: 16, color: Colors.black),
                      const SizedBox(width: 4),
                      Text(modoManual ? 'Manual' : 'IA',
                          style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmarBorrar(context)),
            ],
          ),
          body: Column(
            children: [
              if (modoManual)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.orange.withValues(alpha: 0.15),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.orange),
                      SizedBox(width: 6),
                      Text('Modo manual activo — la IA no responde',
                          style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ),
                ),

              Expanded(
                child: historial.isEmpty
                    ? const Center(child: Text('Sin mensajes', style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: historial.length,
                  itemBuilder: (context, i) {
                    final msg = historial[i] as Map;
                    final role = msg['role'] ?? '';
                    final content = (msg['content'] ?? '').toString();
                    final audioUrl = msg['audioUrl']?.toString();
                    final esBot = role == 'assistant';

                    if (role == 'system') return const SizedBox.shrink();

                    if (content.startsWith('[ubicacion:')) {
                      final coords = content.substring(11, content.length - 1).split(',');
                      if (coords.length == 2) {
                        return _BurbujaUbicacion(
                          lat: double.tryParse(coords[0]) ?? 0,
                          lng: double.tryParse(coords[1]) ?? 0,
                          esBot: esBot,
                        );
                      }
                    }
                    if (content.startsWith('[imagen:')) {
                      return _BurbujaImagen(url: content.substring(8, content.length - 1), esBot: esBot);
                    }
                    if (content.startsWith('[audio:') || audioUrl != null) {
                      final url = audioUrl ?? content.substring(7, content.length - 1);
                      return _BurbujaAudio(url: url, esBot: esBot, transcripcion: audioUrl != null ? content : null);
                    }
                    if (content.startsWith('[video:')) {
                      return _BurbujaVideo(url: content.substring(7, content.length - 1), esBot: esBot);
                    }

                    return _BurbujaMensaje(texto: content, esBot: esBot, timestamp: msg['timestamp']?.toString());
                  },
                ),
              ),

              // Barra de entrada
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    border: Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    children: [
                      // Imagen
                      IconButton(
                        icon: const Icon(Icons.image_outlined, color: Colors.white54),
                        onPressed: (_enviando || _grabando) ? null : _enviarImagen,
                      ),
                      // Calendario
                      IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.white54),
                        tooltip: 'Agendar',
                        onPressed: (_enviando || _grabando) ? null : _abrirAgendarSheet,
                      ),
                      // Productos
                      IconButton(
                        icon: const Icon(Icons.settings, color: Color(0xFF25D366)),
                        tooltip: 'Enviar producto',
                        onPressed: (_enviando || _grabando) ? null : _abrirSelectorProductos,
                      ),
                      // Campo de texto / indicador de grabacion
                      Expanded(
                        child: _grabando
                            ? Row(
                                children: [
                                  ScaleTransition(
                                    scale: Tween(begin: 0.8, end: 1.3).animate(
                                      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                                    ),
                                    child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text('Grabando...  ${_tiempoGrabacion()}',
                                        style: const TextStyle(color: Colors.white70),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_grabacionBloqueada)
                                    const Icon(Icons.lock, color: Colors.white38, size: 16)
                                  else
                                    const Flexible(
                                      child: Text('‹ Deslizá para cancelar',
                                          style: TextStyle(color: Colors.white38, fontSize: 11),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                ],
                              )
                            : TextField(
                          controller: _controller,
                          minLines: 1, maxLines: 4,
                          decoration: InputDecoration(
                            hintText: modoManual ? 'Responder como Marco...' : 'Escribir mensaje...',
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: _enviando ? null : _enviarTexto,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Enviar / Grabar
                      _enviando
                          ? const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 2))
                          : (_grabando && _grabacionBloqueada)
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Cancelar audio',
                            onPressed: _cancelarGrabacion,
                          ),
                          GestureDetector(
                            onTap: _detenerYEnviarAudio,
                            child: Container(
                              width: 44, height: 44,
                              decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                              child: const Icon(Icons.send, color: Colors.black, size: 20),
                            ),
                          ),
                        ],
                      )
                          : (_controller.text.isEmpty || _grabando)
                          ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (_grabando)
                            const Positioned(
                              top: -32,
                              left: 0,
                              right: 0,
                              child: Icon(Icons.lock_outline, color: Colors.white38, size: 20),
                            ),
                          GestureDetector(
                            onLongPressStart: (_) => _iniciarGrabacion(),
                            onLongPressMoveUpdate: _onGrabacionMove,
                            onLongPressEnd: (_) {
                              if (_grabacionBloqueada) return;
                              _detenerYEnviarAudio();
                            },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: _grabando ? Colors.red : (modoManual ? Colors.orange : const Color(0xFF25D366)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_grabando ? Icons.stop : Icons.mic, color: Colors.black, size: 22),
                            ),
                          ),
                        ],
                      )
                          : IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: modoManual ? Colors.orange : const Color(0xFF25D366),
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.send),
                        onPressed: () => _enviarTexto(_controller.text),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmarBorrar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar conversacion'),
        content: const Text('Borrar todo el historial?'),
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
      final nav = Navigator.of(context);
      await FirebaseFirestore.instance.collection('conversaciones').doc(widget.telefono).delete();
      if (mounted) nav.pop();
    }
  }

  String _formatTelefono(String t) {
    if (t.startsWith('506') && t.length == 11) return '+506 ${t.substring(3, 7)}-${t.substring(7)}';
    return t;
  }
}

// ============================================================
// BOTTOM SHEET — MOTORES / ACCESORIOS / SERVICIOS
// ============================================================
class _ProductosBottomSheet extends StatefulWidget {
  const _ProductosBottomSheet({required this.telefono});
  final String telefono;

  @override
  State<_ProductosBottomSheet> createState() => _ProductosBottomSheetState();
}

class _ProductosBottomSheetState extends State<_ProductosBottomSheet>
    with SingleTickerProviderStateMixin {
  final Set<String> _seleccionados = {};
  bool _enviando = false;
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

  Future<void> _enviarSeleccionados() async {
    if (_seleccionados.isEmpty) return;
    setState(() => _enviando = true);
    try {
      final response = await http.post(
        Uri.parse('${BotConfig.baseUrl}/enviar-motores'),
        headers: {'Content-Type': 'application/json', 'X-Api-Key': BotConfig.apiKey},
        body: jsonEncode({'telefono': widget.telefono, 'motores': _seleccionados.toList()}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Enviado'), backgroundColor: Color(0xFF25D366)),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
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
                const Expanded(child: Text('Seleccioná qué enviar',
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
                _ListaSeleccion(categoria: 'motor', seleccionados: _seleccionados, onToggle: _toggle, scrollCtrl: scrollCtrl),
                _ListaSeleccion(categoria: 'accesorio', seleccionados: _seleccionados, onToggle: _toggle, scrollCtrl: scrollCtrl),
                _ListaSeleccion(categoria: 'servicio', seleccionados: _seleccionados, onToggle: _toggle, scrollCtrl: scrollCtrl),
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
                  onPressed: (_seleccionados.isEmpty || _enviando) ? null : _enviarSeleccionados,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.send),
                  label: Text(
                    _enviando ? 'Enviando...' : _seleccionados.isEmpty ? 'Seleccioná un producto' : 'Enviar ${_seleccionados.length} producto${_seleccionados.length > 1 ? 's' : ''}',
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

  void _toggle(String id) {
    setState(() {
      if (_seleccionados.contains(id)) _seleccionados.remove(id);
      else _seleccionados.add(id);
    });
  }
}

class _ListaSeleccion extends StatelessWidget {
  const _ListaSeleccion({required this.categoria, required this.seleccionados, required this.onToggle, required this.scrollCtrl});
  final String categoria;
  final Set<String> seleccionados;
  final void Function(String) onToggle;
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
            final precio = (data['precio'] ?? '').toString();
            final imagen = (data['mediaImagen'] ?? '').toString();
            final seleccionado = seleccionados.contains(id);

            return CheckboxListTile(
              value: seleccionado,
              activeColor: const Color(0xFF25D366),
              onChanged: (_) => onToggle(id),
              secondary: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imagen.isNotEmpty
                    ? Image.network(imagen, width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconoDefault(categoria))
                    : _iconoDefault(categoria),
              ),
              title: Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: precio.isNotEmpty ? Text(precio, style: const TextStyle(color: Color(0xFF25D366), fontSize: 12)) : null,
            );
          },
        );
      },
    );
  }

  Widget _iconoDefault(String cat) {
    IconData icon = cat == 'motor' ? Icons.settings : cat == 'accesorio' ? Icons.cable : Icons.build;
    return Container(
      width: 48, height: 48,
      color: const Color(0xFF25D366).withValues(alpha: 0.15),
      child: Icon(icon, color: const Color(0xFF25D366), size: 24),
    );
  }
}

// ============================================================
// BURBUJAS
// ============================================================
class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje({required this.texto, required this.esBot, this.timestamp});
  final String texto;
  final bool esBot;
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: esBot ? const Color(0xFF1E2A1E) : const Color(0xFF005C4B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esBot ? 4 : 16), bottomRight: Radius.circular(esBot ? 16 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: esBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (esBot) const Text('⚙️ ', style: TextStyle(fontSize: 13)),
              Flexible(child: Text(texto, style: const TextStyle(fontSize: 14, color: Colors.white))),
            ]),
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(_formatHora(timestamp!), style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ),
          ],
        ),
      ),
    );
  }

  String _formatHora(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}

class _BurbujaImagen extends StatelessWidget {
  const _BurbujaImagen({required this.url, required this.esBot});
  final String url;
  final bool esBot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: esBot ? const Color(0xFF1E2A1E) : const Color(0xFF005C4B)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(url, fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null ? child : const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
              errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(12), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.broken_image, color: Colors.white38), SizedBox(width: 8), Text('Imagen no disponible', style: TextStyle(color: Colors.white38))]))),
        ),
      ),
    );
  }
}

class _BurbujaVideo extends StatelessWidget {
  const _BurbujaVideo({required this.url, required this.esBot});
  final String url;
  final bool esBot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esBot ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
          decoration: BoxDecoration(color: esBot ? const Color(0xFF1E2A1E) : const Color(0xFF005C4B), borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (esBot) const Text('⚙️ ', style: TextStyle(fontSize: 13)),
            const Icon(Icons.play_circle, color: Color(0xFF25D366), size: 32),
            const SizedBox(width: 8),
            const Text('Ver video', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _BurbujaUbicacion extends StatelessWidget {
  const _BurbujaUbicacion({required this.lat, required this.lng, required this.esBot});
  final double lat;
  final double lng;
  final bool esBot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: esBot ? const Color(0xFF1E2A1E) : const Color(0xFF005C4B),
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(esBot ? 4 : 16), bottomRight: Radius.circular(esBot ? 16 : 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on, color: Colors.redAccent, size: 18),
            SizedBox(width: 6),
            Text('Ubicación del cliente', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text('Lat: ${lat.toStringAsFixed(6)}\nLng: ${lng.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00AAFF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              icon: const Icon(Icons.navigation, size: 16),
              label: const Text('Waze', style: TextStyle(fontSize: 13)),
              onPressed: () async => launchUrl(Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes'), mode: LaunchMode.externalApplication),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4285F4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              icon: const Icon(Icons.map, size: 16),
              label: const Text('Maps', style: TextStyle(fontSize: 13)),
              onPressed: () async => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _BurbujaAudio extends StatefulWidget {
  const _BurbujaAudio({required this.url, required this.esBot, this.transcripcion});
  final String url;
  final bool esBot;
  final String? transcripcion;

  @override
  State<_BurbujaAudio> createState() => _BurbujaAudioState();
}

class _BurbujaAudioState extends State<_BurbujaAudio> {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _loading = false;

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _togglePlay() async {
    if (_loading) return;
    if (_playing) { await _player.pause(); setState(() => _playing = false); return; }
    setState(() => _loading = true);
    try {
      await _player.setUrl(widget.url);
      await _player.play();
      setState(() => _playing = true);
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playing = false);
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.esBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: widget.esBot ? const Color(0xFF1E2A1E) : const Color(0xFF005C4B),
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(widget.esBot ? 4 : 16), bottomRight: Radius.circular(widget.esBot ? 16 : 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.esBot) const Text('⚙️ ', style: TextStyle(fontSize: 13)),
            _loading
                ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle, color: const Color(0xFF25D366), size: 32), onPressed: _togglePlay, padding: EdgeInsets.zero),
            const SizedBox(width: 8),
            const Icon(Icons.graphic_eq, color: Colors.white54),
            const SizedBox(width: 4),
            const Text('Audio', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          if (widget.transcripcion != null && widget.transcripcion!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('"${widget.transcripcion}"', style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
            ),
        ]),
      ),
    );
  }
}