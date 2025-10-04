# 📁 Fixtures - Datos Reales de Viajes para Testing

Este directorio contiene **datos reales capturados** de viajes en la app para usar en tests de integración.

## 🎯 Propósito

Estos JSONs permiten:
- ✅ Testear con datos 100% reales de Montevideo
- ✅ Reproducir viajes reales para debugging
- ✅ Tests de integración que validan la app completa
- ✅ LLM puede iterar autónomamente con feedback de tests

## 📋 Formato del JSON

Cada archivo JSON contiene toda la información necesaria para reproducir un viaje:

```json
{
  "tripId": "identificador_unico",
  "name": "Descripción legible del viaje",
  "capturedAt": "2025-01-03T12:00:00.000Z",

  "origin": {
    "lat": -34.9011,
    "lng": -56.1645,
    "name": "Nombre del origen"
  },

  "destination": {
    "lat": -34.8960,
    "lng": -56.1555,
    "name": "Nombre del destino"
  },

  "route": {
    "routeId": "route_001",
    "recommended": true,
    "totalDuration": 1800,
    "totalWalkDistance": 600,
    "totalWaitTime": 480,

    "stops": [
      {
        "stopId": "stop_1",
        "name": "Parada Bulevar Artigas",
        "lat": -34.9000,
        "lng": -56.1640,
        "busLines": ["64", "180"]
      }
    ],

    "segments": [
      {
        "type": "CAMINAR",
        "description": "Caminar a parada",
        "duration": 300,
        "distance": 400,
        "from": "origin",
        "to": "stop_1",
        "geometry": [
          {"lat": -34.9011, "lng": -56.1645},
          {"lat": -34.9000, "lng": -56.1640}
        ]
      },
      {
        "type": "ESPERAR_BUS",
        "description": "Esperar bus línea 64",
        "duration": 480,
        "at": "stop_1",
        "busLine": "64",
        "hasEta": true,
        "etaMinutes": 5
      },
      {
        "type": "VIAJE_EN_BUS",
        "description": "Bus 64 a destino",
        "duration": 720,
        "from": "stop_1",
        "to": "stop_2",
        "busLine": "64",
        "shapeId": "shape_64_A",
        "geometry": [/* puntos de la ruta completa del bus */]
      },
      {
        "type": "CAMINAR",
        "description": "Caminar a destino",
        "duration": 180,
        "distance": 200,
        "from": "stop_2",
        "to": "destination",
        "geometry": [/* puntos de la caminata */]
      }
    ]
  },

  "initialBusPosition": {
    "lat": -34.9020,
    "lng": -56.1660,
    "capturedAt": "2025-01-03T12:00:00.000Z"
  },

  "expectedBehavior": {
    "totalDuration": 1680,
    "stepsExpected": 4,
    "shouldComplete": true,
    "description": "El viaje debe completarse sin problemas"
  }
}
```

## 🚀 Cómo Capturar un Nuevo Viaje

### Paso 1: En la App

1. Busca y selecciona un trip (carousel de opciones)
2. Presiona el botón flotante azul con ícono de "content_copy" (📋)
3. Verás mensaje: "✅ Trip copiado al portapapeles"

### Paso 2: Pegar en Fixture

```bash
# Crear nuevo archivo
cat > test/fixtures/trip_NOMBRE_DESCRIPTIVO.json
# Cmd+V (pegar)
# Ctrl+D (guardar)
```

### Paso 3: Nombrar Descriptivamente

Ejemplos de nombres:
- `trip_casa_trabajo_1bus.json`
- `trip_centro_pocitos_trasbordo.json`
- `trip_universidad_ciudad_vieja_3buses.json`

## 📝 Ejemplos Incluidos

| Archivo | Descripción |
|---------|-------------|
| `trip_example_simple.json` | Ejemplo simple: 1 bus, sin trasbordo |
| `trip_example_trasbordo.json` | Ejemplo con trasbordo: 2 buses |

## 🧪 Usar en Tests

```dart
import 'dart:convert';
import 'dart:io';

void main() {
  test('Viaje casa-trabajo debe completarse', () async {
    // Cargar fixture
    final file = File('test/fixtures/trip_casa_trabajo_1bus.json');
    final json = jsonDecode(await file.readAsString());
    final tripData = TripFixtureData.fromJson(json);

    // ... usar en test ...
  });
}
```

## 💡 Tips

- **Captura casos variados**: 1 bus, 2 buses, 3 buses, sin ETA, con ETA
- **Captura casos problemáticos**: Si encuentras un bug, captura ese trip
- **Nombra descriptivamente**: Que el nombre indique qué testea
- **Documenta lo especial**: Si tiene algo particular, agrégalo en `expectedBehavior.description`

## 🔄 Mantener Actualizado

Si cambias la estructura de datos de la app, actualiza:
1. El formato del JSON capturado (en el botón de captura)
2. Esta documentación
3. La clase `TripFixtureData` que parsea el JSON
