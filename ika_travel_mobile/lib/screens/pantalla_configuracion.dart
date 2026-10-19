import 'package:flutter/material.dart';

import '../config/tema.dart';
import '../config/tema_manager.dart';
import '../config/colores_tema.dart';
import '../config/idioma_manager.dart'; // 👈 Nuevo
import '../config/traducciones.dart'; // 👈 Nuevo

class PantallaConfiguracion extends StatefulWidget {
  const PantallaConfiguracion({super.key});

  @override
  State<PantallaConfiguracion> createState() => _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends State<PantallaConfiguracion> {
  bool _notificacionesActivas = true;
  String _idiomaSeleccionado = 'Español';

  @override
  Widget build(BuildContext context) {
    final colorTexto = TemaApp.texto(context);
    final colorFondoTarjeta = TemaApp.tarjeta(context);
    final colorTextoSecundario = TemaApp.textoSecundario(context);

    // 👇 Obtenemos el idioma actual
    return ValueListenableBuilder<Locale>(
      valueListenable: idiomaActivo,
      builder: (context, locale, child) {
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
              Traducciones.get('configuracion', locale), // 👈 Traducido
              style: TextStyle(color: colorTexto, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                Traducciones.get('preferencias', locale), // 👈 Traducido
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorTexto,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: colorFondoTarjeta,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        Traducciones.get(
                          'notificaciones',
                          locale,
                        ), // 👈 Traducido
                        style: TextStyle(color: colorTexto),
                      ),
                      subtitle: Text(
                        Traducciones.get(
                          'recibir_alertas',
                          locale,
                        ), // 👈 Traducido
                        style: TextStyle(
                          fontSize: 12,
                          color: colorTextoSecundario,
                        ),
                      ),
                      activeColor: AppColores.naranjaBoton,
                      value: _notificacionesActivas,
                      onChanged: (bool value) {
                        setState(() {
                          _notificacionesActivas = value;
                        });
                      },
                    ),
                    Divider(
                      height: 1,
                      color: colorTextoSecundario.withOpacity(0.2),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: modoOscuroActivo,
                      builder: (context, isDarkMode, child) {
                        return SwitchListTile(
                          title: Text(
                            Traducciones.get(
                              'modo_oscuro',
                              locale,
                            ), // 👈 Traducido
                            style: TextStyle(color: colorTexto),
                          ),
                          subtitle: Text(
                            Traducciones.get(
                              'cambiar_apariencia',
                              locale,
                            ), // 👈 Traducido
                            style: TextStyle(
                              fontSize: 12,
                              color: colorTextoSecundario,
                            ),
                          ),
                          activeColor: AppColores.naranjaBoton,
                          value: isDarkMode,
                          onChanged: (bool value) {
                            toggleModoOscuro(value);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                Traducciones.get('region', locale), // 👈 Traducido
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorTexto,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: colorFondoTarjeta,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: Icon(Icons.language, color: colorTexto),
                  title: Text(
                    Traducciones.get('idioma_app', locale), // 👈 Traducido
                    style: TextStyle(color: colorTexto),
                  ),
                  trailing: Text(
                    _idiomaSeleccionado,
                    style: TextStyle(color: colorTextoSecundario),
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: colorFondoTarjeta,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Traducciones.get(
                                  'seleccionar_idioma',
                                  locale,
                                ), // 👈 Traducido
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorTexto,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ListTile(
                                title: Text(
                                  'Español',
                                  style: TextStyle(color: colorTexto),
                                ),
                                trailing: _idiomaSeleccionado == 'Español'
                                    ? const Icon(
                                        Icons.check,
                                        color: AppColores.naranjaBoton,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _idiomaSeleccionado = 'Español';
                                  });
                                  cambiarIdioma(
                                    'es',
                                  ); // 👈 CAMBIA EL IDIOMA DE LA APP
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                title: Text(
                                  'English',
                                  style: TextStyle(color: colorTexto),
                                ),
                                trailing: _idiomaSeleccionado == 'English'
                                    ? const Icon(
                                        Icons.check,
                                        color: AppColores.naranjaBoton,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _idiomaSeleccionado = 'English';
                                  });
                                  cambiarIdioma(
                                    'en',
                                  ); // 👈 CAMBIA EL IDIOMA DE LA APP
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
              Text(
                Traducciones.get('cuenta', locale), // 👈 Traducido
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorTexto,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: colorFondoTarjeta,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: Text(
                    Traducciones.get('cerrar_sesion', locale), // 👈 Traducido
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {},
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
