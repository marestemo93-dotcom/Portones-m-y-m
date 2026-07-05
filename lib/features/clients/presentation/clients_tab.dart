import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/features/clients/data/models/client_item.dart';
import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/utils/location_colors.dart';
import 'package:portones_mym/core/widgets/contact_action_buttons.dart';
import 'package:portones_mym/features/whatsapp/presentation/whatsapp_tab.dart';
import 'package:portones_mym/data/models/job_item.dart';

/* ==========================
   CLIENTES TAB (AGENDA APP)
========================== */

class ClientsTab extends ConsumerStatefulWidget {
  const ClientsTab({super.key});

  @override
  ConsumerState<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends ConsumerState<ClientsTab> {
  String _q = '';

  Widget _dot(Color c, {double size = 10}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(clientsRepoProvider);
    final all = repo.getAll();
    final filtered = _q.trim().isEmpty
        ? all
        : all.where((c) {
      final s = _q.toLowerCase();
      return c.nombre.toLowerCase().contains(s) ||
          c.telefonoRaw.toLowerCase().contains(s) ||
          c.ubicacionTexto.toLowerCase().contains(s);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar cliente…',
                filled: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                // Agrupar por provincia (a partir de ubicacionTexto)
                final Map<String, List<ClientItem>> groups = {
                  for (final p in kProvinceOrder) p: <ClientItem>[],
                };

                for (final c in filtered) {
                  final prov = provinciaFromUbic(c.ubicacionTexto);
                  (groups[prov] ??= <ClientItem>[]).add(c);
                }

                // Orden interno por nombre
                for (final entry in groups.entries) {
                  entry.value.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
                }

                final children = <Widget>[];

                for (final prov in kProvinceOrder) {
                  final list = groups[prov] ?? const <ClientItem>[];
                  if (list.isEmpty) continue;
                  final provColor =colorForProvincia(prov);

                  // Header provincia
                  children.add(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Row(
                        children: [
                          _dot(provColor, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            prov,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  );

                  // Clientes
                  for (final c in list) {
                    children.add(
                      Card(
                        child: ListTile(
                          title: Row(
                            children: [
                              _dot(provColor, size: 10),
                              const SizedBox(width: 8),
                              Expanded(child: Text(c.nombre.isEmpty ? 'Cliente' : c.nombre)),
                            ],
                          ),
                          subtitle: Text('${c.telefonoRaw}\n${c.ubicacionTexto.isEmpty ? "—" : c.ubicacionTexto}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await repo.deleteByPhoneKey(c.telefonoKey);
                              setState(() {});
                            },
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => EditClientScreen(client: c)),
                            );
                            setState(() {});
                          },
                        ),
                      ),
                    );
                  }
                }

                if (children.isEmpty) {
                  return const Center(child: Text('No hay clientes'));
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  children: children,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EditClientScreen extends ConsumerStatefulWidget {
  const EditClientScreen({super.key, required this.client});
  final ClientItem client;

  @override
  ConsumerState<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends ConsumerState<EditClientScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _loc;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.client.nombre);
    _phone = TextEditingController(text: widget.client.telefonoRaw);
    _loc = TextEditingController(text: widget.client.ubicacionTexto);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _loc.dispose();
    super.dispose();
  }

  /// Busca el job (Visita o Trabajo) más reciente de este cliente que tenga
  /// ubicación guardada. No se duplica lat/lng en ClientItem (que solo vive
  /// en Hive local) - se deriva al vuelo desde los jobs, que sí sincronizan
  /// con Firestore y reciben la ubicación automáticamente por WhatsApp.
  JobItem? _ultimoJobConUbicacion(String phoneKey) {
    final jobsRepo = ref.read(jobsRepoProvider);
    final candidatos = jobsRepo.getAllEvents().values
        .expand((lista) => lista)
        .where((j) => j.clientPhoneKey == phoneKey && j.ubicacionLat != null)
        .toList();
    if (candidatos.isEmpty) return null;
    candidatos.sort((a, b) => b.fecha.compareTo(a.fecha));
    return candidatos.first;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(clientsRepoProvider);
    final jobConUbicacion = _ultimoJobConUbicacion(widget.client.telefonoKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar cliente'),
        actions: [
          WhatsAppButton(telefono: widget.client.telefonoRaw),
          WazeButton(lat: jobConUbicacion?.ubicacionLat, lng: jobConUbicacion?.ubicacionLng),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await repo.deleteByPhoneKey(widget.client.telefonoKey);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                    ),
                    TextField(controller: _loc, decoration: const InputDecoration(labelText: 'Ubicación')),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        await repo.updateClient(
                          phoneKey: widget.client.telefonoKey,
                          nombre: _name.text,
                          telefonoRaw: _phone.text,
                          ubicacionTexto: _loc.text,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _UbicacionesGuardadas(telefonoKey: widget.client.telefonoKey, nombre: widget.client.nombre),
          ],
        ),
      ),
    );
  }
}

/// Lista de todas las ubicaciones que el cliente mandó por WhatsApp (puede
/// tener más de una propiedad). Vive en Firestore, no en Hive - por eso el
/// servidor sí puede escribirla apenas llega un mensaje de ubicación, a
/// diferencia de ClientItem.
class _UbicacionesGuardadas extends StatelessWidget {
  const _UbicacionesGuardadas({required this.telefonoKey, required this.nombre});
  final String telefonoKey;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    if (telefonoKey.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversaciones')
          .doc(telefonoKey)
          .collection('ubicaciones')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        final df = DateFormat.yMMMd(kLocaleEs).add_Hm();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ubicaciones guardadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                for (var i = 0; i < docs.length; i++) ...[
                  Builder(builder: (context) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final lat = (data['lat'] as num?)?.toDouble();
                    final lng = (data['lng'] as num?)?.toDouble();
                    final tsRaw = data['timestamp']?.toString();
                    DateTime? ts;
                    if (tsRaw != null) {
                      try {
                        ts = DateTime.parse(tsRaw).toLocal();
                      } catch (_) {}
                    }
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                      title: Text(ts != null ? df.format(ts) : 'Fecha desconocida'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                            tooltip: 'Ver en el chat',
                            onPressed: tsRaw == null
                                ? null
                                : () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        telefono: telefonoKey,
                                        nombre: nombre,
                                        data: const {},
                                        scrollToTimestamp: tsRaw,
                                      ),
                                    )),
                          ),
                          WazeButton(lat: lat, lng: lng),
                        ],
                      ),
                    );
                  }),
                  if (i != docs.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}