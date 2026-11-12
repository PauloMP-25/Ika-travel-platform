import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/colores_tema.dart';
import '../config/tema.dart';
import '../models/prestador_servicio_modelo.dart';
import '../services/prestadores_service.dart';

/// Pantalla para la Búsqueda y Consulta de Prestadores de Servicios Turísticos Formalizados.
/// Cumple con RF-03 y la regla RN-01: Exclusivamente prestadores empadronados y validados por DIRCETUR Ica.
/// No incluye reservas ni pasarelas de pago (alcance informativo y de contacto oficial).
class PantallaPrestadores extends StatefulWidget {
  final String? filtroInicial;

  const PantallaPrestadores({super.key, this.filtroInicial});

  @override
  State<PantallaPrestadores> createState() => _PantallaPrestadoresState();
}

class _PantallaPrestadoresState extends State<PantallaPrestadores> {
  final PrestadoresService _prestadoresService = PrestadoresService();
  final TextEditingController _busquedaCtrl = TextEditingController();

  List<PrestadorServicioModel> _prestadores = [];
  bool _cargando = true;
  String? _error;
  String _filtroTipo = 'Todos';

  final List<String> _categoriasFiltro = [
    'Todos',
    'Buggy & Arena',
    'Náutico & Islas',
    'Viñedos & Pisco',
    'Aventura',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.filtroInicial != null && widget.filtroInicial!.isNotEmpty) {
      _busquedaCtrl.text = widget.filtroInicial!;
    }
    _cargarPrestadores();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPrestadores() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final query = _busquedaCtrl.text.trim();
      final resultados = await _prestadoresService.buscarPrestadores(
        query: query.isNotEmpty ? query : null,
      );

      if (mounted) {
        setState(() {
          _prestadores = resultados;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No fue posible cargar el padrón de prestadores. Revisa tu conexión.';
          _cargando = false;
        });
      }
    }
  }

  List<PrestadorServicioModel> get _prestadoresFiltrados {
    if (_filtroTipo == 'Todos') return _prestadores;

    return _prestadores.where((p) {
      final t = _filtroTipo.toLowerCase();
      if (t.contains('arena') || t.contains('buggy')) {
        return p.name.toLowerCase().contains('buggy') ||
            p.name.toLowerCase().contains('desert') ||
            p.tours.any((tour) =>
                tour.name.toLowerCase().contains('buggy') ||
                tour.name.toLowerCase().contains('sandboarding') ||
                tour.name.toLowerCase().contains('arena'));
      }
      if (t.contains('náutico') || t.contains('islas')) {
        return p.name.toLowerCase().contains('bahía') ||
            p.name.toLowerCase().contains('marina') ||
            p.tours.any((tour) =>
                tour.name.toLowerCase().contains('islas') ||
                tour.name.toLowerCase().contains('paracas') ||
                tour.name.toLowerCase().contains('marina'));
      }
      if (t.contains('viñedo') || t.contains('pisco')) {
        return p.name.toLowerCase().contains('pisquera') ||
            p.name.toLowerCase().contains('viñedo') ||
            p.tours.any((tour) =>
                tour.name.toLowerCase().contains('pisco') ||
                tour.name.toLowerCase().contains('bodega') ||
                tour.name.toLowerCase().contains('vino'));
      }
      return true;
    }).toList();
  }

  Future<void> _llamarTelefono(String? telefono) async {
    if (telefono == null || telefono.trim().isEmpty) return;
    final uri = Uri.parse('tel:${telefono.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la llamada a $telefono')),
        );
      }
    }
  }

  Future<void> _abrirWhatsApp(String? telefono, String nombreAgencia) async {
    if (telefono == null || telefono.trim().isEmpty) return;
    final numeroLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final mensaje = Uri.encodeComponent(
      'Hola $nombreAgencia, vi sus servicios formalizados en Ika Travel y deseo información oficial sobre sus tours.',
    );
    final uri = Uri.parse('https://wa.me/$numeroLimpio?text=$mensaje');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir WhatsApp para $telefono')),
        );
      }
    }
  }

  Future<void> _enviarCorreo(String? email, String nombreAgencia) async {
    if (email == null || email.trim().isEmpty) return;
    final uri = Uri.parse(
      'mailto:$email?subject=${Uri.encodeComponent('Consulta Turística - Ika Travel')}&body=${Uri.encodeComponent('Estimado equipo de $nombreAgencia,\n\nSolicito información oficial de sus servicios empadronados por DIRCETUR Ica.')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _mostrarDetallePrestador(PrestadorServicioModel prestador) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSec = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorTarjeta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF2E7D32),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prestador.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✓ Empadronado y Validado por DIRCETUR',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Ficha técnica oficial DIRCETUR
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF252525)
                          : const Color(0xFFF7F4EE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: [
                        if (prestador.ruc != null)
                          _filaDato('RUC:', prestador.ruc!, colorTexto, colorTextoSec),
                        if (prestador.dirceturRegistryNumber != null)
                          _filaDato('N° Padrón DIRCETUR:', prestador.dirceturRegistryNumber!, colorTexto, colorTextoSec),
                        _filaDato('Estado en padrón:', 'Vigente y Validado', colorTexto, Colors.green.shade700),
                        _filaDato('Intermediación de pagos:', 'No aplica (Contratación directa)', colorTexto, colorTextoSec),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Canales Oficiales de Contacto',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorTexto),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (prestador.contactPhone != null) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.chat, size: 18),
                            label: const Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            onPressed: () => _abrirWhatsApp(prestador.contactPhone, prestador.name),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColores.naranjaBoton,
                              side: const BorderSide(color: AppColores.naranjaBoton),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.phone, size: 18),
                            label: const Text('Llamar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            onPressed: () => _llamarTelefono(prestador.contactPhone),
                          ),
                        ),
                      ],
                      if (prestador.contactEmail != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Enviar correo',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue.shade700,
                          ),
                          icon: const Icon(Icons.email_outlined),
                          onPressed: () => _enviarCorreo(prestador.contactEmail, prestador.name),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Servicios y Tours Certificados (${prestador.tours.length})',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorTexto),
                      ),
                      Text(
                        'Precios referenciales',
                        style: TextStyle(fontSize: 11, color: colorTextoSec),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (prestador.tours.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Consulta directamente al prestador para conocer el itinerario y salidas del día.',
                        style: TextStyle(color: colorTextoSec, fontSize: 13),
                      ),
                    )
                  else
                    ...prestador.tours.map(
                      (tour) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2C2C2C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    tour.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: colorTexto,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColores.naranjaBoton.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'S/ ${tour.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: AppColores.naranjaBoton,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tour.description,
                              style: TextStyle(fontSize: 12, color: colorTextoSec, height: 1.3),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 14, color: colorTextoSec),
                                const SizedBox(width: 4),
                                Text(
                                  'Duración aprox: ${tour.durationHours} ${tour.durationHours == 1 ? 'hora' : 'horas'}',
                                  style: TextStyle(fontSize: 11, color: colorTextoSec),
                                ),
                                if (tour.attractionName != null) ...[
                                  const SizedBox(width: 10),
                                  Icon(Icons.place_outlined, size: 14, color: colorTextoSec),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      tour.attractionName!,
                                      style: TextStyle(fontSize: 11, color: colorTextoSec),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),
                  // Nota legal / transparencia informativa
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ika Travel facilita el acceso directo a prestadores formalizados inscritos en DIRCETUR Ica. La contratación y pago se acuerdan directamente con la agencia sin intermediación de la app.',
                            style: TextStyle(fontSize: 11, color: Colors.brown.shade900, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _filaDato(String etiqueta, String valor, Color colorTxt, Color colorVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 12, color: colorTxt)),
          Text(valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorVal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSec = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);
    final lista = _prestadoresFiltrados;

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorTexto),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Servicios Formalizados',
          style: TextStyle(color: colorTexto, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Buscador por texto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _busquedaCtrl,
                onSubmitted: (_) => _cargarPrestadores(),
                onChanged: (_) {
                  setState(() {});
                },
                style: TextStyle(color: colorTexto),
                decoration: InputDecoration(
                  hintText: 'Buscar agencia, tour o destino...',
                  hintStyle: TextStyle(color: colorTextoSec, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: colorTextoSec),
                  suffixIcon: _busquedaCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _busquedaCtrl.clear();
                            _cargarPrestadores();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorTarjeta,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Filtros rápidos de categoría
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categoriasFiltro.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categoriasFiltro[index];
                  final activa = _filtroTipo == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: activa,
                    onSelected: (val) {
                      if (val) setState(() => _filtroTipo = cat);
                    },
                    selectedColor: AppColores.naranjaBoton,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                      color: activa ? Colors.white : colorTexto,
                    ),
                    backgroundColor: colorTarjeta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Contenido principal: Lista / Carga / Error / Vacío
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColores.naranjaBoton),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colorTexto, fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColores.naranjaBoton,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _cargarPrestadores,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : lista.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 54, color: colorTextoSec),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No se encontraron prestadores validados para esta búsqueda.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14, color: colorTextoSec),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Por seguridad (RN-01), solo se presentan empresas verificadas por DIRCETUR.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: lista.length,
                              itemBuilder: (context, index) {
                                final prestador = lista[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: colorTarjeta,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _mostrarDetallePrestador(prestador),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(
                                                    Icons.business_outlined,
                                                    color: Color(0xFF2E7D32),
                                                    size: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        prestador.name,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                          color: colorTexto,
                                                        ),
                                                      ),
                                                      if (prestador.dirceturRegistryNumber != null)
                                                        Text(
                                                          prestador.dirceturRegistryNumber!,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: colorTextoSec,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'DIRCETUR ✓',
                                                    style: TextStyle(
                                                      color: Color(0xFF2E7D32),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '${prestador.tours.length} ${prestador.tours.length == 1 ? 'servicio/tour homologado' : 'servicios/tours homologados'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colorTextoSec,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    if (prestador.contactPhone != null)
                                                      IconButton(
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        icon: const Icon(Icons.phone_outlined, size: 20, color: AppColores.naranjaBoton),
                                                        onPressed: () => _llamarTelefono(prestador.contactPhone),
                                                      ),
                                                    if (prestador.contactPhone != null) const SizedBox(width: 12),
                                                    if (prestador.contactEmail != null)
                                                      IconButton(
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        icon: const Icon(Icons.email_outlined, size: 20, color: Colors.blue),
                                                        onPressed: () => _enviarCorreo(prestador.contactEmail, prestador.name),
                                                      ),
                                                  ],
                                                ),
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: AppColores.naranjaBoton,
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  icon: const Icon(Icons.arrow_forward, size: 16),
                                                  label: const Text('Ver servicios', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                  onPressed: () => _mostrarDetallePrestador(prestador),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
