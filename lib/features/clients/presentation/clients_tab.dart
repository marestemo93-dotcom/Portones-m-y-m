import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/features/clients/data/models/client_item.dart';
import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/utils/location_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(clientsRepoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar cliente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await repo.deleteByPhoneKey(widget.client.telefonoKey);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
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
      ),
    );
  }
}