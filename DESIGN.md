# Design

Lenguaje visual de BondiUY, documentado desde lo construido (`lib/ui`).

## Mundo

**Blanco elegante con láminas de degradé sutil, y su par grafito en oscuro.** El mapa
es el protagonista: cartografía sobria de OpenStreetMap dibujada por un
renderer propio (teselas vectoriales, suavizado, zoom continuo). Encima
flotan láminas opacas con un degradé apenas perceptible, un filo que brilla
arriba y una sombra larga y limpia: profundidad sin sacrificar contraste.

Tema: automático (sigue al sistema) con opción manual claro / oscuro, desde el
botón redondo en la pantalla de inicio. La preferencia se guarda en el
teléfono.

## Material: láminas (`lib/ui/tema/lamina.dart`)

Paneles opacos con degradé sutil (decisión del 2026-09-28: se probó vidrio
translúcido y se descartó; el contraste entre la UI y el texto manda).

- Relleno: degradé apenas perceptible, más luminoso arriba — blanco
  `#FFFFFF` → `#F4F6F9` (claro), grafito `#2B2F38` → `#1E2128` (oscuro).
- Filo de 1 px: brilla arriba y se asienta abajo (en claro, una línea
  apenas oscura abajo; en oscuro, un brillo blanco arriba).
- Sombra en dos capas: una larga y difusa recogida hacia adentro (no deja
  franja gris debajo) y una de contacto que define el borde contra el mapa.
- Capas internas (filas, fichas de tramo): `#F1F3F7` con filo fino
  (grafito `#343944`).
- Radios: paneles 24–30, botón principal 20, botones 16, píldoras 26–28.
- Con "alto contraste" del sistema: lámina plana, sin degradé ni filo.
- Los globos y los indicadores de borde del mapa (pintados en el lienzo)
  usan la misma familia: degradé sutil y filo que brilla arriba.

## Color (`lib/ui/tema/tema.dart`, `lib/ui/mapa/estilo_mapa.dart`)

Solo el viaje es saturado; todo lo demás queda atrás.

| Rol | Claro | Oscuro |
|---|---|---|
| Texto | `#111318` | `#F2F4F7` |
| Texto suave | `#5C616C` | `#A7AEBA` |
| Acción principal (botón) | tinta `#111318` | blanco `#F2F4F7` |
| Caminar / tu ubicación | `#2563EB` | `#6B9BFF` |
| Bus / línea | `#E0412F` | `#FF6A55` |
| En vivo | `#0B8A5C` | `#36D08F` |
| Horario / alerta | `#B86E00` | `#F2A93B` |
| Mapa: tierra / agua / verde | `#F4F3EF` / `#C9DFF0` / `#DDEBD3` | `#181B21` / `#0E2233` / `#1B2721` |

El color nunca es la única señal: en vivo lleva punto que late y la palabra
"en vivo"; horario dice "horario".

## Tipografía

Entre número y unidad, espacio no separable ("580 m", "6 min"): nunca se
parten en dos renglones.

Roboto (sistema), cifras tabulares en todo número. Instrucción 24 sp w700,
cifra protagonista 34 sp w700 (tracking −1), cuerpo 16–17 sp. En el mapa:
calles 11.5–12.5 sp a lo largo de la calle (nunca cabeza abajo), barrios en
versalitas espaciadas.

## Mapa

- Recorridos: caminata en puntos azules con aro; bus en trazo rojo con borde
  (arriba del bus, lo ya recorrido queda gris); bus en vivo → parada en
  guiones verdes que avanzan hacia la parada.
- Marcadores vectoriales: tu ubicación (punto azul con aro blanco, halo que
  late y un haz suave hacia donde caminás), el bus que viene (disco rojo con
  aro verde en vivo / ámbar por horario y flecha de rumbo), vos arriba del
  bus (insignia de la línea con aro azul), parada de subida (aro rojo, flecha
  ↑) y de bajada (aro tinta, flecha ↓; relleno rojo cuando es "bajate en
  esta"), pin de destino. Las flechas de la parada activa flotan hacia
  afuera, en sincronía.
- Paradas: las del recorrido del bus como cuentas sobre la línea (las que ya
  pasaron, apagadas; la próxima, más grande y latiendo). Las de la red se ven
  tenues de cerca durante el viaje y, al explorar, tocables (con ícono de bus
  a zoom 17+).
- Globos: rótulos blancos (grafito en oscuro) con punta hacia su marcador.
  "Subís al D1 / Cambiás al 109", "Llega en 3 min · EN VIVO · a 800 m" (flota
  suavemente), la próxima parada ("PRÓXIMA PARADA"), "Te bajás acá" /
  "¡Bajate en esta!" (rojo), "Llegás 18:33" y el destino. Se ubican por
  prioridad: arriba, más arriba, abajo o a los costados; si no entran sin
  tapar algo, los secundarios se ocultan. En la vista previa, chips de tramo
  ("🚶 5 min", línea) cuando hay lugar.
- Indicadores de borde: píldoras de lámina con una punta hacia lo que quedó
  fuera de la vista.
  - El bus que viene: "🚌 D1 · 5 min" (verde en vivo, ámbar por horario).
  - Tu objetivo: "➤ Tu parada · 260 m" (la flecha gira hacia allá); en el
    bus, solo si moviste el mapa.
  - Si coinciden, se corren a lo largo del borde para no pisarse.
- Cámara: cada momento enfoca un **grupo** de elementos (especificación
  heredada de `old/v2/test/devtools/CAMERA_BEHAVIOR_SPEC.md`), recalculado
  cuadro a cuadro con las posiciones predichas:
  - Opciones: el viaje entero (y el bus en vivo si aparece).
  - Caminar a la parada: vos + lo que falta caminar + la parada; ya a 60 m
    de la parada, también el bus si llega en ≤ 5 min y el conjunto sigue
    legible (zoom ≥ 14). Antes, el bus se señala en el borde.
  - Esperar: la parada + el bus + vos; el zoom se cierra a medida que el bus
    se acerca.
  - En el bus: vos + la próxima parada y la siguiente; con ≤ 3 paradas, la
    bajada. Nunca el recorrido entero.
  - Caminar al destino: vos + lo que falta caminar + el destino.
  - Si ni lo esencial entra con un zoom legible, manda el usuario: la cámara
    se acerca al mínimo y se corre hacia el grupo sin dejarlo afuera.
  - Movimiento continuo (`mapa/movimiento.dart`): el GPS y la API de buses
    dan posiciones sueltas cada varios segundos; el mapa estima la velocidad
    y el marcador sigue avanzando entre lecturas **por la calle** (la
    caminata, el recorrido del bus), doblando en las esquinas. Cada lectura
    nueva fija la trayectoria y el error de donde se lo veía se absorbe en
    ~0,5 s (e^-t/0,5): sin saltos ni frenadas; quieto no tiembla; un salto de
    más de 400 m se muestra directo. Se mantiene con "quitar animaciones" (es la
    posición real, no un adorno).
  - Si movés el mapa aparece "volver a centrar"; en viaje, la cámara vuelve
    sola a los 12 s sin tocarlo, y al cambiar de paso siempre.
  - Transiciones entre pasos: la cámara viaja hacia el encuadre nuevo
    persiguiendo al usuario (que sigue moviéndose), suavizando los saltos
    del objetivo (p. ej. cuando cambia el alto de la tarjeta); al llegar se
    engancha sin tirón. Al esperar, el encuadre ya incluye el comienzo del
    recorrido del bus, así la subida es un solo movimiento.
  - La subida: tu bus, al llegar a la parada, queda "llegado" (no se
    anuncia el siguiente mientras subís). La predicción de su movimiento
    nunca pasa tu parada: solo una lectura real del GPS del bus del otro
    lado lo lleva más allá. En cuanto te alejás
    25 m con él, ya se te muestra arriba del bus (sin esperar a que la
    lógica lo confirme a los 60 m): el bus se desvanece en la parada y tu
    punto se funde en la insignia del bus (0,45 s).

## Composición por fase

- **Inicio**: píldora "¿A dónde vas?" arriba; botones redondos de recentrar y
  tema abajo a la derecha; hoja de parada al tocar una (con su globo en el
  mapa).
- **Buscar**: pantalla completa sólida, campos redondeados, "Mi ubicación" en azul.
- **Opciones**: encabezado origen → destino; hoja de lámina cuya altura
  se ajusta al contenido (el mapa encuadra justo encima). Cada opción ocupa
  la hoja entera, sin marco: duración grande + "18:01 – 18:33" + sello
  Recomendado; una **barra de tramos** proporcional a la duración (caminatas
  como fichas con 🚶 y minutos, buses en rojo con la línea); el
  bus en vivo ("● El D1 pasa en 6 min"); dónde subís, cuánto caminás y los
  trasbordos. Debajo, "‹ • • • ›" (flechas para quien no descubre el
  deslizamiento) y "Empezar viaje" en tinta, 58 dp, con sombra suave.
- **Viaje**: tarjeta de paso arriba — "Paso 2 de 4" y "Llegás
  18:33", tira de pasos (el actual se llena con su avance), instrucción,
  cifra grande y lo propio de cada paso:
  - caminar: progreso circular, cuándo pasa tu bus o qué viene después;
  - esperar: "Llega en 2 min · a 930 m", una pista con el bus acercándose a
    tu parada, etiqueta EN VIVO / HORARIO;
  - en el bus: "Faltan 12 paradas", tira de paradas (las pasadas, dónde vas,
    la tuya al final) y "PRÓXIMA · nombre"; en la última, la tarjeta se
    enmarca en rojo que late y dice "Tocá el timbre para bajar".
  Abajo: cerrar, itinerario completo ("Tu viaje": todos los pasos con lo
  hecho tachado y AHORA en el actual) y el respaldo manual. Cada avance se
  confirma con una píldora breve ("✓ Subiste al D1. ¡Buen viaje!") y una
  vibración.
- **Llegada**: check verde que aparece con rebote, destino, y el resumen
  (duración, lo caminado, líneas); se cierra sola.

## Movimiento

Los botones redondos y de acción se hunden apenas al tocarlos (escala 0,94, 140 ms).
Las cifras grandes que cambian ("Faltan 9 paradas" → "8") suben con un
fundido corto, solo cuando cambian; el dato chico de al lado (km) se
actualiza quieto.

Paneles 220–280 ms (fade + deslizamiento corto); transiciones de cámara
500–1100 ms ease-in-out y, al seguir, inercia suave (constante ~0,35 s);
pulsos, guiones y globos que flotan en un ciclo de 3,2 s, solo si hay algo
vivo en el mapa. Vibración al avanzar de paso (media), al llegar y en
"bajate en la próxima" (fuerte). Con "quitar animaciones" todo cambia al
instante.
