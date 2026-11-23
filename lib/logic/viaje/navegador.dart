// Navegador del viaje: decide, muestra a muestra de GPS, en qué paso está el
// usuario y cuánto le falta. Es puro y determinista (sin timers ni I/O): la
// misma secuencia de muestras produce siempre la misma secuencia de pasos.
//
// Un solo camino de detección por tipo de paso:
//   caminar -> llegó al final de la caminata (geofence + confirmación)
//   esperar -> se está moviendo SOBRE el recorrido del bus, en el sentido de
//              marcha y a velocidad de vehículo (subió)
//   bus     -> llegó a la parada de bajada
// Además, si el usuario "se adelanta" (p.ej. el GPS no detectó la subida y ya
// va en el bus), el navegador salta hacia adelante; nunca retrocede.

import 'dart:math' as math;

import '../../contract/app_state.dart';
import '../geo/geo.dart';
import '../puertos.dart';

class ReglasNavegacion {
  /// Llegada a una parada caminando.
  final double radioParada;

  /// Llegada al destino final.
  final double radioDestino;

  /// Bajada: distancia a la parada de bajada.
  final double radioBajada;

  /// Máxima distancia lateral al recorrido del bus para considerar que se va
  /// arriba de él.
  final double corredorBus;

  /// Metros recorridos sobre la línea (desde la parada) para confirmar subida.
  final double avanceSubida;

  /// Velocidad mínima (m/s) de un bus en movimiento (~9 km/h).
  final double velocidadBus;

  /// Muestras consecutivas que confirman un avance.
  final int confirmaciones;

  /// Muestras con peor precisión se ignoran.
  final double precisionMaxima;

  const ReglasNavegacion({
    this.radioParada = 25,
    this.radioDestino = 30,
    this.radioBajada = 40,
    this.corredorBus = 40,
    this.avanceSubida = 60,
    this.velocidadBus = 2.5,
    this.confirmaciones = 2,
    this.precisionMaxima = 80,
  });
}

/// Resultado de procesar una muestra.
class EstadoNavegacion {
  final int paso;
  final ProgresoPaso progreso;
  final bool completado;

  /// true si esta muestra hizo avanzar el paso.
  final bool avanzo;

  const EstadoNavegacion({
    required this.paso,
    required this.progreso,
    required this.completado,
    required this.avanzo,
  });
}

class Navegador {
  final OpcionViaje opcion;
  final ReglasNavegacion reglas;
  final List<Polilinea?> _lineas;

  int _paso = 0;
  bool _completado = false;
  int _confirmadas = 0;
  int? _pasoCandidato;
  double? _metrosTotalesPaso;
  double _recorridoPrevio = 0;
  MuestraUbicacion? _anterior;
  ProgresoPaso _progreso = ProgresoPaso.vacio;

  Navegador(this.opcion, {this.reglas = const ReglasNavegacion()})
    : _lineas = [
        for (final t in opcion.tramos)
          switch (t) {
            TramoCaminar(:final geometria) => Polilinea(geometria),
            TramoBus(:final geometria) => Polilinea(geometria),
            TramoEsperar() => null,
          },
      ];

  int get paso => _paso;
  bool get completado => _completado;
  ProgresoPaso get progreso => _progreso;

  EstadoNavegacion get estado => EstadoNavegacion(
    paso: _paso,
    progreso: _progreso,
    completado: _completado,
    avanzo: false,
  );

  /// Avance manual ("Ya subí", "Ya llegué").
  EstadoNavegacion confirmarPaso() {
    if (_completado) return estado;
    _irA(_paso + 1);
    if (_anterior != null && !_completado) {
      _progreso = _medir(_anterior!);
    }
    return EstadoNavegacion(
      paso: _paso,
      progreso: _progreso,
      completado: _completado,
      avanzo: true,
    );
  }

  EstadoNavegacion procesar(MuestraUbicacion m) {
    if (_completado) return estado;
    if (m.precision != null && m.precision! > reglas.precisionMaxima) {
      return estado;
    }
    final velocidad = m.velocidad ?? _velocidadEstimada(m);
    _anterior = m;

    final destino = _detectar(m.coordenada, velocidad);
    var avanzo = false;
    if (destino != null && destino > _paso) {
      if (_pasoCandidato == destino) {
        _confirmadas++;
      } else {
        _pasoCandidato = destino;
        _confirmadas = 1;
      }
      final necesarias = _confirmacionesPara(m.coordenada);
      if (_confirmadas >= necesarias) {
        _irA(destino);
        avanzo = true;
      }
    } else {
      _pasoCandidato = null;
      _confirmadas = 0;
    }

    if (!_completado) _progreso = _medir(m);
    return EstadoNavegacion(
      paso: _paso,
      progreso: _progreso,
      completado: _completado,
      avanzo: avanzo,
    );
  }

  // --- Detección --------------------------------------------------------

  /// Paso al que correspondería avanzar con esta muestra, o null.
  int? _detectar(Coordenada c, double? velocidad) {
    final tramo = opcion.tramos[_paso];
    switch (tramo) {
      case TramoCaminar():
        final radio =
            tramo.esAlDestino ? reglas.radioDestino : reglas.radioParada;
        if (distancia(c, tramo.fin) <= radio) return _paso + 1;
        // ¿Se adelantó y ya viaja en el bus siguiente?
        final saltoBus = _pasoBusSiViaja(c, velocidad, desde: _paso + 1);
        if (saltoBus != null) return saltoBus;
        final lejos =
            _lineas[_paso]!.proyectar(c).distanciaLateral > reglas.corredorBus;
        return lejos ? _adelante(c, velocidad) : null;
      case TramoEsperar():
        final bus = opcion.tramos[_paso + 1] as TramoBus;
        final linea = _lineas[_paso + 1]!;
        if (distancia(c, bus.bajada.coordenada) <= reglas.radioBajada) {
          return _paso + 2; // Se lo perdimos entero: ya llegó a la bajada.
        }
        if (_viajaSobre(linea, c, velocidad)) return _paso + 1;
        final lejos = distancia(c, tramo.parada.coordenada) > 100;
        return lejos ? _adelante(c, velocidad) : null;
      case TramoBus():
        final linea = _lineas[_paso]!;
        final p = linea.proyectar(c, desde: _recorridoPrevio - 100);
        // Bajó: está al final del recorrido o junto a la bajada, con el bus
        // detenido (o ya a pie). Mientras el bus anda todavía va arriba: no se
        // lo da por bajado unos metros antes de la parada.
        final alFinal =
            p.distanciaLateral <= reglas.corredorBus &&
            linea.largo - p.recorrido <= 20;
        final enLaBajada =
            distancia(c, tramo.bajada.coordenada) <= reglas.radioBajada;
        final enMarcha = velocidad != null && velocidad >= reglas.velocidadBus;
        if ((alFinal || enLaBajada) && !enMarcha) return _paso + 1;
        // Ya había llegado a la bajada y ahora va a pie: bajó, aunque entre
        // dos lecturas se haya alejado de la parada por la misma calle.
        if (linea.largo - _recorridoPrevio <= 20 &&
            velocidad != null &&
            velocidad < reglas.velocidadBus) {
          return _paso + 1;
        }
        // Se bajó entre dos lecturas (GPS cortado, app suspendida, lecturas
        // espaciadas): ya no está sobre el recorrido del bus.
        if (p.distanciaLateral > reglas.corredorBus) {
          return _adelante(c, velocidad);
        }
        return null;
    }
  }

  /// El usuario ya no está donde dice el paso actual: entre dos lecturas
  /// pasó uno o más pasos. El primer paso posterior que coincide con donde
  /// está y cómo se mueve (viajando en un bus, caminando una caminata,
  /// esperando en una parada), o el final si ya llegó al destino.
  int? _adelante(Coordenada c, double? velocidad) {
    final enMarcha = velocidad != null && velocidad >= reglas.velocidadBus;
    for (var j = _paso + 1; j < opcion.tramos.length; j++) {
      final t = opcion.tramos[j];
      switch (t) {
        case TramoBus():
          if (_viajaSobre(_lineas[j]!, c, velocidad)) return j;
        case TramoCaminar():
          if (enMarcha) continue;
          if (t.esAlDestino && distancia(c, t.fin) <= reglas.radioDestino) {
            return j + 1;
          }
          if (_lineas[j]!.proyectar(c).distanciaLateral <= reglas.corredorBus) {
            return j;
          }
        case TramoEsperar():
          if (!enMarcha &&
              distancia(c, t.parada.coordenada) <= reglas.radioParada) {
            return j;
          }
      }
    }
    return null;
  }

  bool _viajaSobre(Polilinea linea, Coordenada c, double? velocidad) {
    final p = linea.proyectar(c);
    if (p.distanciaLateral > reglas.corredorBus) return false;
    if (p.recorrido < reglas.avanceSubida) return false;
    // Sin velocidad informada no se puede distinguir de alguien caminando por
    // la vereda: se exige el doble de avance.
    if (velocidad == null) return p.recorrido >= reglas.avanceSubida * 2;
    return velocidad >= reglas.velocidadBus;
  }

  int? _pasoBusSiViaja(Coordenada c, double? velocidad, {required int desde}) {
    for (var i = desde; i < opcion.tramos.length; i++) {
      final t = opcion.tramos[i];
      if (t is TramoBus) {
        return _viajaSobre(_lineas[i]!, c, velocidad) ? i : null;
      }
      if (t is TramoCaminar) return null; // Solo el próximo bus.
    }
    return null;
  }

  int _confirmacionesPara(Coordenada c) {
    // Muy cerca del objetivo alcanza con una muestra.
    final tramo = opcion.tramos[_paso];
    if (tramo is TramoCaminar && distancia(c, tramo.fin) <= 10) return 1;
    return reglas.confirmaciones;
  }

  void _irA(int paso) {
    _confirmadas = 0;
    _pasoCandidato = null;
    _metrosTotalesPaso = null;
    _recorridoPrevio = 0;
    if (paso >= opcion.tramos.length) {
      _paso = opcion.tramos.length - 1;
      _completado = true;
      _progreso = const ProgresoPaso(metrosRestantes: 0);
      return;
    }
    _paso = paso;
    _progreso = ProgresoPaso.vacio;
  }

  double? _velocidadEstimada(MuestraUbicacion m) {
    final a = _anterior;
    if (a == null) return null;
    final dt = m.momento.difference(a.momento).inMilliseconds / 1000.0;
    if (dt <= 0.5) return null;
    return distancia(a.coordenada, m.coordenada) / dt;
  }

  // --- Medición ---------------------------------------------------------

  ProgresoPaso _medir(MuestraUbicacion m) {
    final c = m.coordenada;
    final tramo = opcion.tramos[_paso];
    switch (tramo) {
      case TramoCaminar():
        final linea = _lineas[_paso]!;
        final p = linea.proyectar(c, desde: math.max(0, _recorridoPrevio - 60));
        _recorridoPrevio = p.recorrido;
        final resto = linea.tramo(p.recorrido, linea.largo);
        final recorrido = [if (p.distanciaLateral > 3) c, ...resto];
        final restante = (linea.largo - p.recorrido) + p.distanciaLateral;
        _metrosTotalesPaso ??= math.max(restante, 1);
        return ProgresoPaso(
          metrosRestantes: restante.round(),
          metrosTotales: _metrosTotalesPaso!.round(),
          recorridoRestante: recorrido.length >= 2 ? recorrido : [c, tramo.fin],
        );
      case TramoEsperar():
        return ProgresoPaso(
          metrosRestantes: distancia(c, tramo.parada.coordenada).round(),
        );
      case TramoBus():
        final linea = _lineas[_paso]!;
        final p = linea.proyectar(
          c,
          desde: math.max(0, _recorridoPrevio - 100),
        );
        _recorridoPrevio = math.max(_recorridoPrevio, p.recorrido);
        final restante = linea.largo - _recorridoPrevio;
        _metrosTotalesPaso ??= linea.largo;
        var faltan = 0;
        Parada? proxima;
        for (final s in tramo.paradasIntermedias) {
          final ps = linea.proyectar(s.coordenada);
          if (ps.recorrido > _recorridoPrevio + 15) {
            faltan++;
            proxima ??= s;
          }
        }
        return ProgresoPaso(
          metrosRestantes: restante.round(),
          metrosTotales: _metrosTotalesPaso!.round(),
          // Desde donde va el bus (avance que nunca retrocede) hasta la bajada.
          recorridoRestante:
              restante > 1 ? linea.tramo(_recorridoPrevio, linea.largo) : null,
          paradasRestantes: faltan,
          proximaParada: proxima ?? tramo.bajada,
        );
    }
  }
}
