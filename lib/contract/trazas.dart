// Trazas: las llamadas entre las piezas de la app, a medida que ocurren.
//
// Las usa la presentación web de la demo para mostrar cómo trabaja la app
// por dentro. La lógica las emite en sus costuras (las acciones que recibe de
// la UI, los puertos hacia el mundo, las piezas del núcleo) y la UI solo las
// lee, como lee el estado. Sin nadie escuchando no cuestan nada.

import 'dart:async';

/// Las piezas de la app entre las que viajan las llamadas.
enum Pieza {
  /// La UI: el teléfono.
  interfaz,

  /// El núcleo: implementa las acciones y publica el estado.
  controlador,

  /// Detecta el paso del viaje con cada lectura del GPS.
  navegador,

  /// Elige el bus que viene y su recorrido hasta la parada.
  seguidor,

  /// Ordena las opciones y elige la recomendada.
  recomendador,

  // Puertos hacia el mundo.
  planificador,
  llegadas,
  ubicacion,
  catalogo,
  lugares,
}

/// Una llamada de [desde] a [hacia] (o su respuesta, si [respuesta]).
class Traza {
  final Pieza desde;
  final Pieza hacia;

  /// La llamada tal como está en el código: `llegadas("5296")`.
  final String llamada;

  /// Qué devolvió, en pocas palabras (null si todavía no o no aplica).
  final String? resultado;
  final DateTime momento;

  const Traza(
    this.desde,
    this.hacia,
    this.llamada, {
    this.resultado,
    required this.momento,
  });
}

class Trazas {
  final _salida = StreamController<Traza>.broadcast();

  Stream<Traza> get stream => _salida.stream;

  void emitir(Pieza desde, Pieza hacia, String llamada, {String? resultado}) {
    if (!_salida.hasListener) return;
    _salida.add(
      Traza(
        desde,
        hacia,
        llamada,
        resultado: resultado,
        momento: DateTime.now(),
      ),
    );
  }

  void cerrar() => _salida.close();
}
