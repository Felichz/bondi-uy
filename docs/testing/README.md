# Pruebas de BondiUY

Todo corre con `flutter test`, sin emulador ni red. Las pruebas usan datos
reales de Montevideo grabados y un mundo simulado determinista.

## Datos

| Fuente | Qué es |
|---|---|
| `test/fixtures/trip_saldanha_plaza_otp_v2.json` | Respuesta real de OTP (12 itinerarios) Saldanha da Gama 3941 → Plaza Independencia, GPS sintético cada 5 s y sondeos reales de la API de la IM (D1 directo; 526 → 109 con trasbordo). |
| `test/fixtures/teselas/{z}/{x}/{y}.pbf` | Teselas vectoriales OSM (z10–14) de la zona, para dibujar el mapa real sin red. |
| `assets/data/shapes.geojson`, `stops.geojson` | GTFS empaquetado (shapes para la aproximación del bus; paradas con líneas). |

## Capas

1. **Lógica pura** (`test/logica/`)
   - `navegador_test.dart`: reproduce el GPS grabado y exige avance estricto
     paso a paso (4 pasos en D1, 7 con trasbordo), progreso de caminata,
     paradas que faltan en el bus, que esperar quieto no dispare la subida,
     respaldo manual y salto si el GPS se perdió la subida.
   - `seguidor_bus_test.dart`: cada sondeo real produce una aproximación que
     sigue la calle (nunca una recta), mismo vehículo entre sondeos, un bus que
     ya pasó no "viene", el que llegó a la parada se informa "llegado" (no el
     siguiente) por unos sondeos, sin shape no se inventa geometría.
   - `app_controller_test.dart`: debounce de sugerencias, planificación con una
     sola recomendada, ETAs, sondeo según el paso, parada consultada, permisos.

2. **App completa headless** (`test/ui/`): monta `BondiApp` con la lógica real,
   el mapa real (teselas en memoria), el plan OTP grabado y el mundo
   simulado con tiempo falso. Toca la UI como un usuario.
   - `flujo_principal_test.dart`: buscar → opciones → empezar → caminar →
     esperar → bus → caminar → ¡Llegaste! → inicio; también con "quitar
     animaciones" del sistema activado y en tema oscuro.
   - `viaje_mapa_test.dart`: la cámara sigue al usuario (camina decenas de
     metros y en pantalla no se mueve), globos de las paradas relevantes
     (subida, próxima, "¡Bajate en esta!", destino), la cámara vuelve sola
     si movés el mapa, el itinerario completo, capitalización de destinos, y
     la subida al bus cuadro a cuadro (60 fps): un solo movimiento, sin
     saltos ni tirones, sin "sin datos" ni el bus siguiente en la tarjeta.
   - `movimiento_test.dart`: con lecturas cada 5 s el marcador avanza sin
     frenar ni saltar y dobla por la calle; quieto no tiembla; saltos grandes
     directos.
   - `rotulos_test.dart`: los nombres de calles se colocan en vistas cercanas
     (centro y Malvín), dentro de la zona visible.
   - `flujos_secundarios_test.dart`: trasbordo, volver desde opciones,
     terminar viaje, respaldo manual, parada tocada, intercambiar origen y
     destino, error de planificación con reintento, sin resultados, sin permiso
     de ubicación.
   - Cada checkpoint guarda una captura en `build/capturas/<flujo>_NN_<paso>.png`
     (fuentes reales cargadas), para revisión humana.

3. **Sonda visual** (`test/ui/render_tesela_probe_test.dart`): renderiza
   teselas en claro y oscuro a `build/sondas/` para ajustar el estilo del mapa.

## En el emulador

Modo `simulado` para recorrer todos los flujos con OTP real y movimiento
acelerado; modo `grabado` para hacerlo sin servidor. Ver el README.

## Grabar un viaje nuevo

`dart run tool/capture_trip.dart --help` (necesita OTP local; opcionalmente las
credenciales de la IM para grabar sondeos reales de buses).
