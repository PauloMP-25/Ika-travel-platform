import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import '../config/api_config.dart';
import '../services/auth_service.dart';

class PantallaAdminDircetur extends StatefulWidget {
  const PantallaAdminDircetur({super.key});

  @override
  State<PantallaAdminDircetur> createState() => _PantallaAdminDirceturState();
}

class _PantallaAdminDirceturState extends State<PantallaAdminDircetur> {
  bool _cargando = false;
  List<dynamic> _reportes = [];
  List<dynamic> _agencias = [];

  // Cabeceras con el JWT
  Map<String, String> _getAdminHeaders() {
    final token = AuthService().usuarioActual?.token ?? '';
    return {
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      'Authorization': 'Bearer $token',
    };
  }

  // 1. Cargar reportes de informalidad (RF-21)
  Future<void> _cargarReportes() async {
    setState(() => _cargando = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/emergency/admin/reports'),
        headers: _getAdminHeaders(),
      );
      if (response.statusCode == 200) {
        setState(
          () => _reportes = json.decode(utf8.decode(response.bodyBytes)),
        );
      } else {
        throw Exception('Error ${response.statusCode} al cargar reportes');
      }
    } catch (e) {
      _mostrarError('Error de conexión: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  // 2. Cargar agencias (RF-04 y RF-19)
  Future<void> _cargarAgencias() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/catalog/agencies'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(
          () => _agencias = json.decode(utf8.decode(response.bodyBytes)),
        );
      }
    } catch (e) {
      debugPrint('Error agencias: $e');
    }
  }

  // 3. Sincronizar con DIRCETUR (RF-20)
  Future<void> _sincronizarAgencias() async {
    setState(() => _cargando = true);
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/catalog/admin/agencies/sync-dircetur',
        ),
        headers: _getAdminHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Text(
              'Sincronización exitosa: ${data['total_en_padron'] ?? 0} agencias procesadas.',
            ),
          ),
        );
        _cargarAgencias();
      } else {
        _mostrarError(
          'Error ${response.statusCode}: Token inválido o no autorizado',
        );
      }
    } catch (e) {
      _mostrarError('Error al sincronizar: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  // 4. Crear Atractivo Manualmente (RF-19)
  Future<void> _crearAtractivo(Map<String, dynamic> data) async {
    setState(() => _cargando = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/catalog/admin/attractions'),
        headers: {..._getAdminHeaders(), 'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF2E7D32),
            content: Text('Atractivo creado y publicado con éxito'),
          ),
        );
        Navigator.pop(context); // Cierra el formulario
      } else {
        _mostrarError(
          'Error ${response.statusCode}: No se pudo crear el atractivo',
        );
      }
    } catch (e) {
      _mostrarError('Error de red: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  // 5. Validar Agencia individualmente (RF-19)
  Future<void> _validarAgencia(String id) async {
    setState(() => _cargando = true);
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/v1/catalog/admin/agencies/$id/validate',
        ),
        headers: {..._getAdminHeaders(), 'Content-Type': 'application/json'},
        body: json.encode({"dircetur_registry_number": "REG-MANUAL-APP"}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF2E7D32),
            content: Text('Agencia validada'),
          ),
        );
        _cargarAgencias(); // Refresca la lista
      }
    } catch (e) {
      _mostrarError('Error: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: const Color(0xFFC62828), content: Text(msj)),
    );
  }

  // Formulario visual (BottomSheet) para crear atractivo
  void _mostrarFormularioAtractivo(BuildContext context) {
    final nombreCtrl = TextEditingController();
    final distritoCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Registrar Nuevo Atractivo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF382E27),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del Atractivo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: distritoCtrl,
              decoration: const InputDecoration(
                labelText: 'Distrito (Ej. Ica, Paracas)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97724),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                if (nombreCtrl.text.isEmpty || distritoCtrl.text.isEmpty) {
                  _mostrarError('El nombre y distrito son obligatorios');
                  return;
                }
                _crearAtractivo({
                  "name": nombreCtrl.text,
                  "description": descCtrl.text.isEmpty
                      ? "Sin descripción"
                      : descCtrl.text,
                  "district": distritoCtrl.text,
                  "latitude": -14.0678, // Coordenadas base (Ica)
                  "longitude": -75.7286,
                  "official_recommendation": "Visita recomendada",
                  "is_active": true,
                  "category_slugs": [
                    "aventura_desierto",
                  ], // Categoría por defecto
                  "image_urls": [
                    "https://images.unsplash.com/photo-1549419136-a2897e39b795",
                  ],
                });
              },
              child: const Text(
                'Guardar y Publicar',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarReportes();
    _cargarAgencias();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel DIRCETUR'),
          backgroundColor: const Color(0xFF382E27),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: const Color(0xFFD97724),
            tabs: [
              Tab(icon: Icon(Icons.report_problem), text: 'Reportes'),
              Tab(icon: Icon(Icons.business), text: 'Agencias'),
              Tab(icon: Icon(Icons.landscape), text: 'Atractivos'),
            ],
          ),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Pestaña 1: Reportes
                  _reportes.isEmpty
                      ? const Center(child: Text('No hay reportes pendientes.'))
                      : ListView.builder(
                          itemCount: _reportes.length,
                          itemBuilder: (context, index) {
                            final rep = _reportes[index];
                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.warning,
                                  color: Color(0xFFD97724),
                                ),
                                title: Text(
                                  rep['description'] ?? 'Sin descripción',
                                ),
                                subtitle: Text(
                                  'Estado: ${rep['status'] ?? 'Pendiente'}',
                                ),
                              ),
                            );
                          },
                        ),

                  // Pestaña 2: Agencias
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97724),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: _sincronizarAgencias,
                          icon: const Icon(Icons.sync),
                          label: const Text('Sincronizar Padrón DIRCETUR'),
                        ),
                      ),
                      Expanded(
                        child: _agencias.isEmpty
                            ? const Center(
                                child: Text('No hay agencias cargadas.'),
                              )
                            : ListView.builder(
                                itemCount: _agencias.length,
                                itemBuilder: (context, index) {
                                  final ag = _agencias[index];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.store,
                                      color: Color(0xFF382E27),
                                    ),
                                    title: Text(
                                      ag['name'] ?? 'Agencia sin nombre',
                                    ),
                                    subtitle: Text(
                                      'RUC: ${ag['ruc'] ?? 'No registrado'}',
                                    ),
                                    trailing: ag['is_validated'] == true
                                        ? const Chip(
                                            label: Text('Validado'),
                                            backgroundColor: Color(0xFFE8F5E9),
                                          )
                                        : TextButton(
                                            onPressed: () =>
                                                _validarAgencia(ag['id']),
                                            child: const Text(
                                              'Validar',
                                              style: TextStyle(
                                                color: Color(0xFFD97724),
                                              ),
                                            ),
                                          ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // Pestaña 3: Atractivos (Ahora funcional)
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF382E27),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: () => _mostrarFormularioAtractivo(context),
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Registrar Nuevo Atractivo'),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Usa el botón para crear y publicar un atractivo en tiempo real.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
