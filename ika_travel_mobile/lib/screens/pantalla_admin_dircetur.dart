import 'package:flutter/material.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../services/dircetur_admin_service.dart';

class PantallaAdminDircetur extends StatefulWidget {
  const PantallaAdminDircetur({super.key});

  @override
  State<PantallaAdminDircetur> createState() => _PantallaAdminDirceturState();
}

class _PantallaAdminDirceturState extends State<PantallaAdminDircetur>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _adminService = DirceturAdminService();

  bool _cargando = true;
  List<dynamic> _atractivos = [];
  List<dynamic> _agencias = [];
  List<dynamic> _reportes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 pestañas
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    try {
      final atr = await _adminService.listarAtractivos();
      final ags = await _adminService.listarAgencias();
      final reps = await _adminService.listarReportes();

      setState(() {
        _atractivos = atr;
        _agencias = ags;
        _reportes = reps;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backend apagado o error de conexión. No se pueden cargar los datos.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => _cargando = false);
  }

  // ==========================================
  // CRUD ATRACTIVOS
  // ==========================================
  Future<void> _guardarAtractivo({Map<String, dynamic>? item}) async {
    final nombreCtrl = TextEditingController(text: item?['name'] ?? '');
    final catCtrl = TextEditingController(text: item?['category'] ?? '');
    final distCtrl = TextEditingController(text: item?['district'] ?? '');

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
                item == null ? 'Nuevo Atractivo' : 'Editar Atractivo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TemaApp.texto(ctx),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: distCtrl,
                decoration: const InputDecoration(
                  labelText: 'Distrito',
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
                  onPressed: () async {
                    if (nombreCtrl.text.isEmpty) return;

                    // Aquí enviamos los datos mínimos que espera el backend
                    final data = {
                      'name': nombreCtrl.text,
                      'category': catCtrl.text.isEmpty
                          ? 'General'
                          : catCtrl.text,
                      'district': distCtrl.text.isEmpty ? 'Ica' : distCtrl.text,
                      'description': 'Atractivo turístico en ${distCtrl.text}',
                      'latitude': -14.0685,
                      'longitude': -75.7288,
                    };

                    bool exito;
                    if (item == null) {
                      exito = await _adminService.crearAtractivo(data);
                    } else {
                      exito = await _adminService.actualizarAtractivo(
                        item['id'].toString(),
                        data,
                      );
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (exito) {
                        _cargarTodo();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Guardado correctamente en el servidor',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Error: El backend rechazó la petición',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    item == null ? 'Guardar Atractivo' : 'Guardar Cambios',
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarAtractivo(String id, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar?'),
        content: Text('¿Eliminar "$nombre" del servidor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final exito = await _adminService.eliminarAtractivo(id);
      if (exito) _cargarTodo();
    }
  }

  // ==========================================
  // CRUD AGENCIAS
  // ==========================================
  Future<void> _guardarAgencia({Map<String, dynamic>? item}) async {
    final nameCtrl = TextEditingController(text: item?['name'] ?? '');
    final regCtrl = TextEditingController(
      text: item?['dircetur_registry_number'] ?? '',
    );

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
                item == null ? 'Nueva Agencia' : 'Editar Agencia',
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
                controller: regCtrl,
                decoration: const InputDecoration(
                  labelText: 'N° Registro DIRCETUR',
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
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;

                    final data = {
                      'name': nameCtrl.text,
                      'dircetur_registry_number': regCtrl.text.isEmpty
                          ? null
                          : regCtrl.text,
                    };

                    bool exito;
                    if (item == null) {
                      exito = await _adminService.crearAgencia(data);
                    } else {
                      exito = await _adminService.actualizarAgencia(
                        item['id'].toString(),
                        data,
                      );
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (exito) {
                        _cargarTodo();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Agencia guardada en el servidor'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Error: El backend rechazó la petición',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    item == null ? 'Guardar Agencia' : 'Guardar Cambios',
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarAgencia(String id, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar?'),
        content: Text('¿Eliminar "$nombre" del servidor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final exito = await _adminService.eliminarAgencia(id);
      if (exito) _cargarTodo();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            Tab(text: 'Atractivos', icon: Icon(Icons.place)),
            Tab(text: 'Agencias', icon: Icon(Icons.business)),
            Tab(text: 'Reportes', icon: Icon(Icons.report_problem)),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: AppColores.naranjaBoton,
              onPressed: () => _guardarAtractivo(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : _tabController.index == 1
          ? FloatingActionButton(
              backgroundColor: AppColores.naranjaBoton,
              onPressed: () => _guardarAgencia(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColores.naranjaBoton),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabAtractivos(colorTexto),
                _buildTabAgencias(colorTexto),
                _buildTabReportes(colorTexto),
              ],
            ),
    );
  }

  // --- PESTAÑA 1: ATRACTIVOS ---
  Widget _buildTabAtractivos(Color colorTexto) {
    if (_atractivos.isEmpty)
      return Center(
        child: Text(
          'No hay atractivos disponibles',
          style: TextStyle(color: colorTexto),
        ),
      );

    return ListView.builder(
      itemCount: _atractivos.length,
      itemBuilder: (context, index) {
        final at = _atractivos[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.landscape, color: Colors.green),
            title: Text(
              at['name'] ?? 'Sin nombre',
              style: TextStyle(fontWeight: FontWeight.bold, color: colorTexto),
            ),
            subtitle: Text('${at['category'] ?? ''} • ${at['district'] ?? ''}'),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'editar') _guardarAtractivo(item: at);
                if (value == 'eliminar')
                  _eliminarAtractivo(at['id'].toString(), at['name']);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- PESTAÑA 2: AGENCIAS ---
  Widget _buildTabAgencias(Color colorTexto) {
    if (_agencias.isEmpty)
      return Center(
        child: Text(
          'No hay agencias disponibles',
          style: TextStyle(color: colorTexto),
        ),
      );

    return ListView.builder(
      itemCount: _agencias.length,
      itemBuilder: (context, index) {
        final ag = _agencias[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.business, color: Colors.blue),
            title: Text(
              ag['name'] ?? 'Sin nombre',
              style: TextStyle(fontWeight: FontWeight.bold, color: colorTexto),
            ),
            subtitle: Text(
              ag['dircetur_registry_number'] ?? 'Sin registro DIRCETUR',
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'editar') _guardarAgencia(item: ag);
                if (value == 'eliminar')
                  _eliminarAgencia(ag['id'].toString(), ag['name']);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- PESTAÑA 3: REPORTES ---
  Widget _buildTabReportes(Color colorTexto) {
    if (_reportes.isEmpty)
      return Center(
        child: Text(
          'No hay reportes pendientes',
          style: TextStyle(color: colorTexto),
        ),
      );

    return ListView.builder(
      itemCount: _reportes.length,
      itemBuilder: (context, index) {
        final rep = _reportes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: Text(
              rep['description'] ?? 'Sin descripción',
              style: TextStyle(color: colorTexto, fontSize: 13),
            ),
            subtitle: Text(
              'Ubicación: ${rep['latitude']}, ${rep['longitude']}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        );
      },
    );
  }
}
