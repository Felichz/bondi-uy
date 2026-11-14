# BondiUY

Tu viaje en bondi por Montevideo, paso a paso. Una app "abuelita first": una
opción recomendada, un mapa que narra el viaje (claro u oscuro), y un asistente que
avanza solo con el GPS (caminar → esperar el bus en vivo → viajar → caminar →
¡Llegaste!).

Producto y visión: [PRODUCT.md](PRODUCT.md) · Lenguaje visual: [DESIGN.md](DESIGN.md) ·
Flujos: [docs/flujos/flujo-principal](docs/flujos/flujo-principal/1-flujo-de-usuario.txt)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/readme/01-wait-dark.webp">
  <img src="docs/readme/01-wait-light.webp" width="100%" alt="BondiUY, screenshot on a phone. The bus trip, one step at a time. BondiUY plans a trip across Montevideo, follows the bus you are waiting for and tells you when to board and when to get off.">
</picture>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/readme/02-trip-dark.webp">
  <img src="docs/readme/02-trip-light.webp" width="100%" alt="BondiUY, three phone screenshots. From the map to your stop. The demo replays trips recorded from the real network, so it needs no GPS and no server. 1, Pick where you’re going. 2, Choose a trip. 3, Ride, and get off at the right stop.">
</picture>

## Arquitectura

```
lib/
  contract/   ÚNICO punto de contacto UI <-> lógica
    app_state.dart      estado (fases explorar / opciones / viaje), datos crudos
    app_actions.dart    intenciones del usuario
    proveedores.dart    appStateProvider + appActionsProvider (la raíz los conecta)
  logic/      "chef" de datos: no conoce widgets, mapas, colores ni textos
    app_controller.dart   implementa AppActions
    viaje/navegador.dart  detecta el paso actual por GPS (puro, determinista)
    viaje/seguidor_bus.dart  bus en vivo + aproximación por el shape GTFS
    viaje/recomendador.dart  deduplica y elige la recomendada
    servicios/   OTP, API de Montevideo, geocoding (Photon/Mapbox), GPS, GTFS
    simulacion/  mundo simulado (GPS y buses sintéticos) y fuentes grabadas
  ui/         presentación: formatea, anima, dibuja el mapa, decide la cámara
    mapa/        renderer de mapa propio (teselas vectoriales OSM, claro/oscuro)
    tema/        colores, material (láminas), insignias, preferencia de tema
    explorar/ busqueda/ opciones/ viaje/   paneles por fase
  main.dart   raíz de composición
```

Reglas: la UI solo lee `AppState` e invoca `AppActions` (nunca importa
`lib/logic`); la lógica manda números/enums y nombres propios, nunca texto de
presentación; Mapbox/mapa/cámara son de la UI. El código anterior quedó en
`old/v2/` como referencia (fuera de compilación).

## Correr la app

Requisitos: Flutter 3.29 (en `../bondi-uy-flutter/flutter`), Android SDK, JDK 21.

```bash
flutter run -d emulator-5554 --dart-define=BONDI_MODO=simulado
```

| `BONDI_MODO` | Planificación | GPS y buses | Red |
|---|---|---|---|
| `real` (defecto en el teléfono) | OTP | teléfono + API de Montevideo | sí |
| `demo` (defecto en la web) | 5 viajes reales grabados desde Malvín (`assets/demo/`) | simulados, velocidad 1×–30× | solo teselas |
| `simulado` | OTP real | se mueven solos (6×) por calles y shapes reales | sí |
| `grabado` | plan OTP grabado (Saldanha da Gama → Plaza Independencia) | simulados | solo teselas |

Credenciales (no van en git): copiá `config/dev.example.json` a
`config/dev.json`, completalo y corré con
`--dart-define-from-file=config/dev.json`. Sin credenciales de la IM la app
funciona, pero sin buses en vivo. El geocoding usa Photon (OSM, sin clave)
salvo que definas `MAPBOX_TOKEN`.

### Demo pública (web y APK)

La demo no necesita ningún servidor propio: los viajes se planificaron con el
OTP local y se grabaron (`tool/capture_trip.dart`), y el usuario y los buses
se simulan. Inglés y español (según el dispositivo, `?lang=en|es` en la web, o
el botón ES/EN).

```bash
scripts/bondi.ps1 web                     # build/web, la demo pública en bondiuy.medanolabs.com
npm run deploy                            # compila build/web y lo publica (Cloudflare Worker, wrangler.jsonc)
scripts/bondi.ps1 web -Base /apps/bondiuy/  # para embeber en el portfolio
scripts/bondi.ps1 apk                     # dist/BondiUY-demo.apk
```

En una pantalla ancha la web muestra la app dentro de un teléfono, con una
presentación al lado; `?marco=0` la muestra a pantalla completa (iframes).

### Servidor OTP local

En `C:\Users\felix\otp` (OTP 2.7 + GTFS de Montevideo + OSM de Uruguay):

```bash
java -Xmx6G -jar otp-shaded-2.7.0.jar --build --save .
```

```bash
java -Xmx3G -jar otp-shaded-2.7.0.jar --load --serve .
```

El emulador lo ve en `http://10.0.2.2:8080` (por defecto). En un teléfono
físico, usá `--dart-define=OTP_URL=http://<ip-de-tu-pc>:8080/otp/routers/default/index/graphql`.

## Pruebas

```bash
flutter test
```

Ver [docs/testing/README.md](docs/testing/README.md): lógica contra datos
grabados reales, y la app entera headless (mapa incluido, en claro y oscuro) con capturas en
`build/capturas/`.

## Herramientas

- `tool/capture_trip.dart`: captura un viaje de OTP + sondeos reales de la IM como fixture.
- `tool/generate_shapes_geojson.dart`: shapes GTFS → `assets/data/shapes.geojson`.
- `tool/generar_paradas_geojson.py`: paradas + líneas del GTFS → `assets/data/stops.geojson`.
- `tool/generar_iconos.py`: íconos de Android y web.

Datos del mapa: © OpenStreetMap (vía OpenFreeMap).
