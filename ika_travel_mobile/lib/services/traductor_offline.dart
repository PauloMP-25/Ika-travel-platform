/// Traductor español ↔ inglés que funciona **sin conexión**.
///
/// No reemplaza a un traductor real: es el último recurso para que la app
/// siga siendo útil cuando el backend no responde y tampoco hay internet
/// para consultar a la IA. Trabaja con un diccionario de viaje embebido en
/// la app y busca siempre la coincidencia **más larga** primero, así que
/// "¿cuánto cuesta?" se traduce como expresión completa y no palabra por
/// palabra.
///
/// El resultado se marca como aproximado para que la pantalla lo advierta:
/// nunca presentamos una traducción incompleta como si fuera definitiva.
library;

class ResultadoOffline {
  final String texto;

  /// true cuando hubo palabras que el diccionario no conocía.
  final bool aproximada;

  /// Porción del texto que sí se pudo traducir (0 a 1).
  final double cobertura;

  const ResultadoOffline({
    required this.texto,
    required this.aproximada,
    required this.cobertura,
  });
}

class TraductorOffline {
  /// Cantidad máxima de palabras que puede tener una expresión del
  /// diccionario. Define hasta dónde mira la búsqueda por coincidencia larga.
  static const int _maxPalabrasExpresion = 6;

  /// ¿Se puede traducir este par de idiomas sin conexión?
  static bool soporta(String origen, String destino) {
    const admitidos = {'es', 'en'};
    return admitidos.contains(origen) &&
        admitidos.contains(destino) &&
        origen != destino;
  }

  static ResultadoOffline traducir({
    required String texto,
    required String origen,
    required String destino,
  }) {
    final diccionario = origen == 'es' ? _esAEn : _enAEs;
    return _aplicar(texto, diccionario);
  }

  // ---------------------------------------------------------------------
  // Motor
  // ---------------------------------------------------------------------

  static ResultadoOffline _aplicar(String texto, Map<String, String> dicc) {
    final tokens = _separar(texto);
    final salida = <String>[];
    var palabras = 0;
    var acertadas = 0;

    var i = 0;
    while (i < tokens.length) {
      final token = tokens[i];

      // La puntuación pasa tal cual, no cuenta para la cobertura.
      if (_esPuntuacion(token)) {
        salida.add(token);
        i++;
        continue;
      }

      // Coincidencia más larga primero: "cuanto cuesta" antes que "cuanto".
      var encontrado = false;
      final maximo = (i + _maxPalabrasExpresion).clamp(0, tokens.length);
      for (var fin = maximo; fin > i; fin--) {
        final trozo = tokens.sublist(i, fin);
        // La ventana no puede contener signos: si los absorbiera, "¿Habla
        // inglés?" perdería el signo de cierre al saltar hasta `fin`.
        if (trozo.any(_esPuntuacion)) continue;
        final clave = trozo.map(_normalizar).join(' ');
        final valor = dicc[clave];
        if (valor != null) {
          salida.add(valor);
          final cuantas = trozo.length;
          palabras += cuantas;
          acertadas += cuantas;
          i = fin;
          encontrado = true;
          break;
        }
      }

      if (!encontrado) {
        // Palabra desconocida: se deja como está para no perder información.
        salida.add(token);
        palabras++;
        i++;
      }
    }

    final cobertura = palabras == 0 ? 1.0 : acertadas / palabras;
    return ResultadoOffline(
      texto: _recomponer(salida),
      aproximada: acertadas < palabras,
      cobertura: cobertura,
    );
  }

  /// Parte el texto en palabras y signos, conservando los signos como piezas
  /// propias para poder reconstruir la frase al final.
  static List<String> _separar(String texto) {
    final limpio = texto.replaceAll('¿', '').replaceAll('¡', '');
    final conEspacios = limpio.replaceAllMapped(
      RegExp(r'([.,;:!?()"])'),
      (m) => ' ${m[1]} ',
    );
    return conEspacios
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String _recomponer(List<String> piezas) {
    final buffer = StringBuffer();
    for (var i = 0; i < piezas.length; i++) {
      final pieza = piezas[i];
      final pegaAlAnterior = _esPuntuacion(pieza) && pieza != '(' && pieza != '"';
      if (i > 0 && !pegaAlAnterior) buffer.write(' ');
      buffer.write(pieza);
    }
    final texto = buffer.toString().trim();
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  static bool _esPuntuacion(String token) =>
      token.length == 1 && '.,;:!?()"'.contains(token);

  /// Minúsculas y sin tildes, para que "dónde" y "donde" sean la misma clave.
  static String _normalizar(String texto) {
    var t = texto.toLowerCase();
    const reemplazos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    };
    reemplazos.forEach((k, v) => t = t.replaceAll(k, v));
    return t.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // ---------------------------------------------------------------------
  // Diccionario de viaje
  // ---------------------------------------------------------------------

  /// Expresiones completas. Van primero porque dan una traducción natural;
  /// las claves están normalizadas (minúsculas, sin tildes).
  static const Map<String, String> _expresionesEs = {
    // Cortesía y presentación
    'buenos dias': 'good morning',
    'buenas tardes': 'good afternoon',
    'buenas noches': 'good evening',
    'muchas gracias': 'thank you very much',
    'por favor': 'please',
    'de nada': "you're welcome",
    'lo siento': "I'm sorry",
    'con permiso': 'excuse me',
    'como esta': 'how are you',
    'como estas': 'how are you',
    'mucho gusto': 'nice to meet you',
    'hasta luego': 'see you later',
    'mi nombre es': 'my name is',
    'de donde eres': 'where are you from',
    'muy bien': 'very well',
    'esta bien': "that's fine",
    'no hay problema': 'no problem',
    // Comprensión
    'no entiendo': "I don't understand",
    'no hablo espanol': "I don't speak Spanish",
    'habla ingles': 'do you speak English',
    'puede repetir': 'could you repeat that',
    'mas despacio por favor': 'more slowly, please',
    'mas despacio': 'more slowly',
    'como se dice': 'how do you say',
    // Orientación
    'donde esta': 'where is',
    'donde estan': 'where are',
    'como llego a': 'how do I get to',
    'estoy perdido': 'I am lost',
    'estoy perdida': 'I am lost',
    'quiero ir a': 'I want to go to',
    'esta lejos': 'is it far',
    'esta cerca': 'is it near',
    'a la izquierda': 'to the left',
    'a la derecha': 'to the right',
    'todo recto': 'straight ahead',
    'donde hay un cajero': 'where is there an ATM',
    'donde puedo comprar': 'where can I buy',
    // Tiempo
    'a que hora': 'what time',
    'que hora es': 'what time is it',
    'a que hora abren': 'what time do you open',
    'a que hora cierran': 'what time do you close',
    'cuanto tiempo dura': 'how long does it take',
    'esta abierto': 'is it open',
    'esta cerrado': 'it is closed',
    // Dinero
    'cuanto cuesta': 'how much does it cost',
    'cuanto vale': 'how much is it',
    'esta muy caro': 'that is too expensive',
    'acepta tarjeta': 'do you accept cards',
    'en efectivo': 'in cash',
    'la cuenta por favor': 'the check, please',
    'me puede dar un descuento': 'can you give me a discount',
    // Ayuda y salud
    'me puede ayudar': 'can you help me',
    'necesito ayuda': 'I need help',
    'llame a la policia': 'call the police',
    'llame a una ambulancia': 'call an ambulance',
    'necesito un medico': 'I need a doctor',
    'me siento mal': 'I feel sick',
    'me duele': 'it hurts',
    'soy alergico a': 'I am allergic to',
    'tenga cuidado': 'be careful',
    'ten cuidado': 'be careful',
    'es peligroso': 'it is dangerous',
    'es seguro': 'it is safe',
    // Comida
    'tengo hambre': 'I am hungry',
    'tengo sed': 'I am thirsty',
    'sin gluten': 'gluten free',
    'sin azucar': 'sugar free',
    'soy vegetariano': 'I am vegetarian',
    'soy vegetariana': 'I am vegetarian',
    'la carta por favor': 'the menu, please',
    'para llevar': 'to go',
    // Turismo de Ica
    'me gustaria': 'I would like',
    'puedo tomar una foto': 'may I take a photo',
    'agencia autorizada': 'authorized agency',
    'paseo en buggy': 'buggy ride',
    'tabla de arena': 'sandboard',
    'protector solar': 'sunscreen',
    'indice uv': 'UV index',
    'cata de vinos': 'wine tasting',
    'vino y pisco': 'wine and pisco',
    'plaza de armas': 'Main Square',
    'oasis de huacachina': 'Huacachina Oasis',
    'islas ballestas': 'Ballestas Islands',
    'reserva nacional de paracas': 'Paracas National Reserve',
    'lineas de nazca': 'Nazca Lines',
  };

  /// Palabras sueltas. Se usan cuando no hubo una expresión que encajara.
  static const Map<String, String> _palabrasEs = {
    // Básicas
    'hola': 'hello', 'adios': 'goodbye', 'gracias': 'thank you',
    'si': 'yes', 'no': 'no', 'disculpe': 'excuse me', 'perdon': 'sorry',
    'bienvenido': 'welcome', 'senor': 'sir', 'senora': 'madam',
    // Gramática mínima
    'yo': 'I', 'tu': 'you', 'usted': 'you', 'nosotros': 'we', 'ellos': 'they',
    'el': 'the', 'la': 'the', 'los': 'the', 'las': 'the',
    'un': 'a', 'una': 'a', 'unos': 'some', 'unas': 'some',
    'y': 'and', 'o': 'or', 'pero': 'but', 'con': 'with', 'sin': 'without',
    'para': 'for', 'por': 'for', 'de': 'of', 'en': 'in', 'a': 'to',
    'que': 'that', 'es': 'is', 'esta': 'is', 'son': 'are', 'estan': 'are',
    'soy': 'I am', 'estoy': 'I am', 'tiene': 'has', 'tengo': 'I have',
    'quiero': 'I want', 'puedo': 'I can', 'puede': 'you can',
    'necesito': 'I need', 'hay': 'there is', 'ser': 'to be', 'ir': 'to go',
    'donde': 'where', 'cuando': 'when', 'como': 'how', 'cuanto': 'how much',
    'quien': 'who', 'porque': 'because', 'cual': 'which',
    'muy': 'very', 'mas': 'more', 'menos': 'less', 'tambien': 'also',
    'solo': 'only', 'todo': 'everything', 'nada': 'nothing', 'algo': 'something',
    'alguien': 'someone', 'siempre': 'always', 'nunca': 'never',
    'bien': 'well', 'mal': 'badly', 'aqui': 'here', 'alli': 'there',
    // Alojamiento
    'hotel': 'hotel', 'hostal': 'hostel', 'habitacion': 'room', 'cama': 'bed',
    'bano': 'bathroom', 'ducha': 'shower', 'toalla': 'towel', 'llave': 'key',
    'equipaje': 'luggage', 'maleta': 'suitcase', 'mochila': 'backpack',
    'pasaporte': 'passport', 'documento': 'document', 'reservacion': 'reservation',
    // Dinero y compras
    'dinero': 'money', 'precio': 'price', 'barato': 'cheap', 'caro': 'expensive',
    'descuento': 'discount', 'boleto': 'ticket', 'entrada': 'entrance',
    'salida': 'exit', 'tienda': 'shop', 'mercado': 'market', 'recuerdo': 'souvenir',
    'tarjeta': 'card', 'efectivo': 'cash', 'propina': 'tip', 'gratis': 'free',
    'incluido': 'included', 'cuenta': 'bill',
    // Transporte
    'taxi': 'taxi', 'bus': 'bus', 'colectivo': 'shared van', 'auto': 'car',
    'carro': 'car', 'moto': 'motorcycle', 'bicicleta': 'bicycle',
    'aeropuerto': 'airport', 'terminal': 'terminal', 'estacion': 'station',
    'calle': 'street', 'avenida': 'avenue', 'carretera': 'road',
    'izquierda': 'left', 'derecha': 'right', 'recto': 'straight',
    'cerca': 'near', 'lejos': 'far', 'arriba': 'up', 'abajo': 'down',
    // Lugares
    'plaza': 'square', 'iglesia': 'church', 'museo': 'museum',
    'farmacia': 'pharmacy', 'hospital': 'hospital', 'clinica': 'clinic',
    'medico': 'doctor', 'policia': 'police', 'bombero': 'firefighter',
    'emergencia': 'emergency', 'ayuda': 'help', 'peligro': 'danger',
    'cuidado': 'careful', 'seguro': 'safe', 'mapa': 'map', 'guia': 'guide',
    // Ica y naturaleza
    'tour': 'tour', 'excursion': 'excursion', 'paseo': 'ride',
    'playa': 'beach', 'mar': 'sea', 'oceano': 'ocean', 'duna': 'dune',
    'dunas': 'dunes', 'desierto': 'desert', 'oasis': 'oasis',
    'laguna': 'lagoon', 'isla': 'island', 'islas': 'islands',
    'reserva': 'reserve', 'bodega': 'winery', 'vina': 'vineyard',
    'vino': 'wine', 'pisco': 'pisco', 'uva': 'grape', 'arena': 'sand',
    'sandboarding': 'sandboarding', 'buggy': 'buggy', 'lancha': 'boat',
    'atardecer': 'sunset', 'amanecer': 'sunrise', 'foto': 'photo',
    // Comida
    'restaurante': 'restaurant', 'desayuno': 'breakfast', 'almuerzo': 'lunch',
    'cena': 'dinner', 'comida': 'food', 'agua': 'water', 'cafe': 'coffee',
    'te': 'tea', 'cerveza': 'beer', 'jugo': 'juice', 'pan': 'bread',
    'pollo': 'chicken', 'pescado': 'fish', 'carne': 'meat', 'arroz': 'rice',
    'papa': 'potato', 'ensalada': 'salad', 'postre': 'dessert',
    'helado': 'ice cream', 'sal': 'salt', 'azucar': 'sugar',
    'picante': 'spicy', 'delicioso': 'delicious', 'menu': 'menu',
    'carta': 'menu', 'mesa': 'table', 'vegetariano': 'vegetarian',
    // Clima
    'sol': 'sun', 'lluvia': 'rain', 'viento': 'wind', 'calor': 'heat',
    'frio': 'cold', 'nube': 'cloud', 'nublado': 'cloudy',
    'temperatura': 'temperature', 'clima': 'weather', 'sombra': 'shade',
    // Tiempo
    'manana': 'tomorrow', 'hoy': 'today', 'ayer': 'yesterday',
    'ahora': 'now', 'despues': 'later', 'temprano': 'early', 'tarde': 'late',
    'noche': 'night', 'dia': 'day', 'hora': 'hour', 'minuto': 'minute',
    'semana': 'week', 'mes': 'month', 'ano': 'year',
    'lunes': 'Monday', 'martes': 'Tuesday', 'miercoles': 'Wednesday',
    'jueves': 'Thursday', 'viernes': 'Friday', 'sabado': 'Saturday',
    'domingo': 'Sunday',
    // Números
    'uno': 'one', 'dos': 'two', 'tres': 'three', 'cuatro': 'four',
    'cinco': 'five', 'seis': 'six', 'siete': 'seven', 'ocho': 'eight',
    'nueve': 'nine', 'diez': 'ten', 'veinte': 'twenty', 'cien': 'one hundred',
    // Adjetivos útiles
    'grande': 'big', 'pequeno': 'small', 'bueno': 'good', 'malo': 'bad',
    'bonito': 'beautiful', 'abierto': 'open', 'cerrado': 'closed',
    'nuevo': 'new', 'viejo': 'old', 'limpio': 'clean', 'rapido': 'fast',
    'lento': 'slow', 'facil': 'easy', 'dificil': 'difficult',
  };

  /// Casos en inglés donde invertir el diccionario daría una palabra pobre.
  static const Map<String, String> _correccionesEn = {
    'thank you': 'gracias',
    'thank you very much': 'muchas gracias',
    'please': 'por favor',
    'excuse me': 'disculpe',
    'sorry': 'lo siento',
    'how much': 'cuánto',
    'how much does it cost': '¿cuánto cuesta?',
    'how much is it': '¿cuánto vale?',
    'where is': '¿dónde está?',
    'where are': '¿dónde están?',
    'how do i get to': '¿cómo llego a',
    'what time': '¿a qué hora?',
    'what time is it': '¿qué hora es?',
    'can you help me': '¿me puede ayudar?',
    'i need help': 'necesito ayuda',
    'i am lost': 'estoy perdido',
    "i don't understand": 'no entiendo',
    'i dont understand': 'no entiendo',
    "i don't speak spanish": 'no hablo español',
    'do you speak english': '¿habla inglés?',
    'the check please': 'la cuenta por favor',
    'gluten free': 'sin gluten',
    'i am vegetarian': 'soy vegetariano',
    'call the police': 'llame a la policía',
    'call an ambulance': 'llame a una ambulancia',
    'i need a doctor': 'necesito un médico',
    'be careful': 'tenga cuidado',
    'sunscreen': 'protector solar',
    'wine tasting': 'cata de vinos',
    'sandboard': 'tabla de arena',
    'buggy ride': 'paseo en buggy',
    'good morning': 'buenos días',
    'good afternoon': 'buenas tardes',
    'good evening': 'buenas noches',
    'hello': 'hola',
    'goodbye': 'adiós',
    'yes': 'sí',
    'no': 'no',
    'water': 'agua',
    'food': 'comida',
    'help': 'ayuda',
    'the': 'el',
    'a': 'un',
    'i': 'yo',
    'you': 'usted',
    'is': 'es',
    'are': 'son',
    'and': 'y',
    'to': 'a',
    'of': 'de',
    'in': 'en',
    'for': 'para',
    'with': 'con',
    'without': 'sin',
    'beach': 'playa',
    'desert': 'desierto',
    'dunes': 'dunas',
    'wine': 'vino',
    'ticket': 'boleto',
    'bathroom': 'baño',
    'open': 'abierto',
    'closed': 'cerrado',
    'expensive': 'caro',
    'cheap': 'barato',
    'today': 'hoy',
    'tomorrow': 'mañana',
    'now': 'ahora',
  };

  /// es → en: expresiones y palabras en un solo mapa.
  static final Map<String, String> _esAEn = {
    ..._palabrasEs,
    ..._expresionesEs,
  };

  /// en → es: se invierte el mapa español y luego se aplican las correcciones,
  /// que mandan sobre cualquier inversión automática.
  static final Map<String, String> _enAEs = () {
    final mapa = <String, String>{};
    // Las expresiones se invierten primero para que ganen a las palabras
    // sueltas cuando compiten por la misma clave en inglés.
    for (final entrada in _palabrasEs.entries) {
      mapa.putIfAbsent(_clave(entrada.value), () => entrada.key);
    }
    for (final entrada in _expresionesEs.entries) {
      mapa[_clave(entrada.value)] = entrada.key;
    }
    for (final entrada in _correccionesEn.entries) {
      mapa[_clave(entrada.key)] = entrada.value;
    }
    return mapa;
  }();

  static String _clave(String frase) =>
      frase.split(RegExp(r'\s+')).map(_normalizar).join(' ');
}
