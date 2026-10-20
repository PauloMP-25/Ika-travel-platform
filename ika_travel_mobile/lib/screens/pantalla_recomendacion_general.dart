import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/colores_tema.dart';
import '../services/api_service.dart';
import '../services/weather_service.dart';
import 'pantalla_detalle.dart';

class PantallaRecomendacionGeneral extends StatefulWidget {
  const PantallaRecomendacionGeneral({super.key});

  @override
  State<PantallaRecomendacionGeneral> createState() =>
      _PantallaRecomendacionGeneralState();
}

class _PantallaRecomendacionGeneralState
    extends State<PantallaRecomendacionGeneral> {
  List<dynamic> _recomendaciones = [];
  Map<String, dynamic>? _clima;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final api = ApiService();
    final weather = WeatherService();

    // 1. Cargamos el clima
    final dataClima = await weather.obtenerClimaActual();

    // 2. Cargamos las recomendaciones de la IA
    final recomendacionesMap = await api.obtenerRecomendacionesIA();

    // 3. Cargamos la lista de actividades (para obtener imágenes y descripciones reales)
    final listaActividades = await api.obtenerActividades();

    // Creamos un mapa para buscar actividades por su ID fácilmente
    final Map<String, Map<String, dynamic>> actividadesPorId = {
      for (var act in listaActividades) act['id']: act,
    };

    // 4. Combinamos los datos de la IA con los de la actividad
    List<dynamic> listaCombinada = [];
    if (recomendacionesMap != null) {
      recomendacionesMap.forEach((id, rec) {
        final actividadReal = actividadesPorId[id];

        listaCombinada.add({
          'atractivo_id': id,
          'atractivo_nombre': rec['atractivo_nombre'],
          'score': rec['score'],
          'nivel': rec['nivel'],
          'recommendation_text': rec['recommendation_text'],
          // 👇 Agregamos los datos reales de la actividad si existen
          'imagen':
              actividadReal?['imagen'] ?? 'https://via.placeholder.com/150',
          'subtitulo': actividadReal?['subtitulo'] ?? 'Ica',
          'imagenes_detalle': actividadReal?['imagenes_detalle'] ?? [],
        });
      });

      // Ordenamos por score (mayor a menor)
      listaCombinada.sort(
        (a, b) => (b['score'] as num).compareTo(a['score'] as num),
      );
    }

    setState(() {
      _clima = dataClima;
      _recomendaciones = listaCombinada;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);
    final colorTarjeta = TemaApp.tarjeta(context);

    final temp = _clima != null
        ? '${(_clima!['temperatura_actual'] as num).round()}°C'
        : '--';

    return Scaffold(
      backgroundColor: TemaApp.fondo(context),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AppBar simple
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: colorTexto),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'Recomendación del Día',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorTexto,
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                  ),

                  // Banner principal
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorTarjeta,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF3E0),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('😊', style: TextStyle(fontSize: 32)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¡Buen día para explorar!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorTexto,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Clima actual en Ica: $temp. Aquí están las mejores actividades según la IA.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorTextoSecundario,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Lista de recomendaciones
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Top actividades recomendadas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _recomendaciones.length,
                    itemBuilder: (context, index) {
                      final rec = _recomendaciones[index];
                      final nombre = rec['atractivo_nombre'] ?? 'Sin nombre';
                      final score = (rec['score'] as num).toDouble();
                      final nivel = rec['nivel'] ?? 'Bueno';
                      final texto = rec['recommendation_text'] ?? '';
                      final id = rec['atractivo_id'];
                      final imagen = rec['imagen']; // 👈 Imagen real
                      final subtitulo = rec['subtitulo']; // 👈 Subtítulo real
                      final imagenesDetalle = List<String>.from(
                        rec['imagenes_detalle'] ?? [imagen],
                      ); // 👈 Galería real

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colorTarjeta,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () {
                              // 👇 Ahora pasamos los datos REALES al detalle
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PantallaDetalle(
                                    id: id,
                                    titulo: nombre,
                                    subtitulo: subtitulo,
                                    imagenes: imagenesDetalle,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 👇 Imagen de la actividad
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      imagen,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 👇 Textos
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                nombre,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorTexto,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${(score * 100).round()}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          nivel.toString().toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColores.naranjaBoton,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          texto,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorTextoSecundario,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
