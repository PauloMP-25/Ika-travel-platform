import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../models/prestador_servicio_modelo.dart';

class PantallaAdminDircetur extends StatefulWidget {
  const PantallaAdminDircetur({super.key});

  @override
  State<PantallaAdminDircetur> createState() => _PantallaAdminDirceturState();
}

class _PantallaAdminDirceturState extends State<PantallaAdminDircetur>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sincronizarDircetur() async {
    setState(() => _sincronizando = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _sincronizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronización completada.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _mostrarFormularioNuevaAgencia() {
    final nameCtrl = TextEditingController();
    final rucCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final regCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TemaApp.tarjeta(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nueva Agencia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TemaApp.texto(ctx),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rucCtrl,
                decoration: const InputDecoration(
                  labelText: 'RUC',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: regCtrl,
                decoration: const InputDecoration(
                  labelText: 'N° Registro DIRCETUR',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.naranjaBoton,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (nameCtrl.text.isEmpty) return;

                    // AGREGAR A LA LISTA GLOBAL
                    final nuevaLista = List<PrestadorServicioModel>.from(
                      prestadoresGlobales.value,
                    );
                    nuevaLista.add(
                      PrestadorServicioModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text,
                        dirceturRegistryNumber: regCtrl.text.isEmpty
                            ? null
                            : regCtrl.text,
                        isValidated: false,
                        ruc: rucCtrl.text.isEmpty ? null : rucCtrl.text,
                        contactPhone: phoneCtrl.text.isEmpty
                            ? null
                            : phoneCtrl.text,
                        tours: [],
                      ),
                    );
                    prestadoresGlobales.value = nuevaLista;

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Agencia agregada exitosamente.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Guardar Agencia'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      appBar: AppBar(
        title: Text(
          'Panel DIRCETUR',
          style: TextStyle(color: colorTexto, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColores.naranjaBoton,
          labelColor: AppColores.naranjaBoton,
          unselectedLabelColor: colorTexto,
          tabs: const [
            Tab(text: 'Agencias', icon: Icon(Icons.business)),
            Tab(text: 'Sincronizar', icon: Icon(Icons.sync)),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: AppColores.naranjaBoton,
              onPressed: _mostrarFormularioNuevaAgencia,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabAgencias(colorTexto),
          _buildTabSincronizacion(colorTexto),
        ],
      ),
    );
  }

  Widget _buildTabAgencias(Color colorTexto) {
    return ValueListenableBuilder<List<PrestadorServicioModel>>(
      valueListenable: prestadoresGlobales,
      builder: (context, ags, _) {
        return ListView.builder(
          itemCount: ags.length,
          itemBuilder: (context, index) {
            final ag = ags[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ListTile(
                title: Text(
                  ag.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
                subtitle: Text(
                  ag.dirceturRegistryNumber ?? 'Sin registro DIRCETUR',
                ),
                trailing: Switch(
                  value: ag.isValidated,
                  activeColor: Colors.green,
                  onChanged: (val) {
                    final nuevaLista = List<PrestadorServicioModel>.from(
                      prestadoresGlobales.value,
                    );
                    nuevaLista[index] = ag.copyWith(isValidated: val);
                    prestadoresGlobales.value =
                        nuevaLista; // Actualiza toda la app
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabSincronizacion(Color colorTexto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_sync, size: 80, color: AppColores.naranjaBoton),
            const SizedBox(height: 20),
            Text(
              'Sincronización con el Padrón Oficial',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorTexto,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Este proceso actualizará la base de datos local.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorTexto.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.naranjaBoton,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _sincronizando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  _sincronizando ? 'Sincronizando...' : 'Sincronizar Ahora',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _sincronizando ? null : _sincronizarDircetur,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
