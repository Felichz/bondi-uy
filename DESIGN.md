# Design

BondiUY's visual language, documented from what is built (`lib/ui`).

## World

**Elegant white with subtle gradient sheets, and its graphite counterpart in dark mode.** The map
is the protagonist: sober OpenStreetMap cartography drawn by a custom
renderer (vector tiles, smoothing, continuous zoom). Floating on top are opaque sheets with a
barely perceptible gradient, a rim that catches light at the top, and a long, clean
shadow: depth without sacrificing contrast.

Theme: automatic (follows the system) with a manual light / dark option, from the
round button on the home screen. The preference is saved on the
phone.

## Material: sheets (`lib/ui/theme/sheet.dart`)

Opaque panels with a subtle gradient (decision of 2026-09-28: translucent glass was tried
and dropped; contrast between the UI and the text wins).

- Fill: barely perceptible gradient, lighter at the top — white
  `#FFFFFF` → `#F4F6F9` (light), graphite `#2B2F38` → `#1E2128` (dark).
- 1 px rim: catches light at the top and settles at the bottom (in light, a
  barely dark line at the bottom; in dark, a white glow at the top).
- Two-layer shadow: one long, diffuse shadow that curves inward (leaves no gray band
  underneath) and one contact shadow that defines the edge against the map.
- Inner layers (rows, leg cards): `#F1F3F7` with a fine rim
  (graphite `#343944`).
- Radii: panels 24–30, main button 20, buttons 16, pills 26–28.
- With the system's "high contrast" setting: flat sheet, no gradient or rim.
- The bubbles and edge indicators of the map (painted on the canvas) use the same
  family: subtle gradient and a rim that catches light at the top.

## Color (`lib/ui/theme/app_theme.dart`, `lib/ui/map/map_style.dart`)

Only the trip is saturated; everything else stays in the background.

| Role | Light | Dark |
|---|---|---|
| Text | `#111318` | `#F2F4F7` |
| Soft text | `#5C616C` | `#A7AEBA` |
| Main action (button) | ink `#111318` | white `#F2F4F7` |
| Walking / your location | `#2563EB` | `#6B9BFF` |
| Bus / line | `#E0412F` | `#FF6A55` |
| Live | `#0B8A5C` | `#36D08F` |
| Schedule / alert | `#B86E00` | `#F2A93B` |
| Map: land / water / green | `#F4F3EF` / `#C9DFF0` / `#DDEBD3` | `#181B21` / `#0E2233` / `#1B2721` |

Color is never the only signal: live carries a pulsing dot and the word "en vivo" ("live");
schedule says "horario" ("scheduled").

## Typography

Between a number and its unit, a non-breaking space ("580 m", "6 min"): they are never
split across two lines.

Roboto (system), tabular figures for every number. Instruction 24 sp w700,
hero figure 34 sp w700 (tracking −1), body 16–17 sp. On the map:
street names 11.5–12.5 sp along the street (never upside down), neighborhoods in
spaced small caps.

## Map

- Routes: walking as blue dots with a ring; bus as a red stroke with a border
  (above the bus, what has already been traveled is gray); live bus → stop as
  green dashes that advance toward the stop.
- Vector markers: your location (blue dot with white ring, a pulsing halo and a soft
  beam toward where you're walking), the incoming bus (red disc with a green ring
  when live / amber when scheduled, and a heading arrow), you on top of the
  bus (line badge with blue ring), boarding stop (red ring, ↑ arrow)
  and alighting stop (ink ring, ↓ arrow; red fill when it is "get off at this one"),
  destination pin. The arrows of the active stop float outward, in sync.
- Stops: those of the bus route as beads on the line (the ones already passed are dimmed; the
  next one is larger and pulsing). Network stops are faintly visible up close during the trip and,
  when exploring, tappable (with a bus icon at zoom 17+).
- Bubbles: white labels (graphite in dark) with a pointer toward their marker.
  "Board the D1 / Transfer to the 109", "Arrives in 3 min · EN VIVO · 800 m away" (floats
  gently), the next stop ("PRÓXIMA PARADA"), "Get off here" / "Get off at this one!" (red),
  "Arrive 18:33" and the destination. They are placed by priority: above, further above,
  below or at the sides; if they don't fit without covering something, secondary ones are hidden. In the
  preview, leg chips ("🚶 5 min", the line) when there is room.
- Edge indicators: sheet pills with a pointer toward what is out of view.
  - The incoming bus: "🚌 D1 · 5 min" (green when live, amber when scheduled).
  - Your target: "➤ Tu parada · 260 m" (the arrow turns toward it); on the bus, only if
    you moved the map.
  - If they coincide, they are offset along the edge so they don't overlap.
- Camera: each moment focuses on a **group** of elements (specification
  inherited from `old/v2/test/devtools/CAMERA_BEHAVIOR_SPEC.md`), recalculated
  frame by frame with the predicted positions:
  - Options: the whole trip (and the live bus if it appears).
  - Walking to the stop: you + the remaining walk + the stop; once within 60 m
    of the stop, also the bus if it arrives in ≤ 5 min and the group stays
    legible (zoom ≥ 14). Before that, the bus is pointed out at the edge.
  - Waiting: the stop + the bus + you; the zoom tightens as the bus gets closer.
  - On the bus: you + the next stop and the one after; with ≤ 3 stops left, the
    alighting stop. Never the entire route.
  - Walking to the destination: you + the remaining walk + the destination.
  - If not even the essentials fit at a legible zoom, the user takes precedence: the camera
    zooms in to the minimum and moves toward the group without leaving it out.
  - Continuous movement (`map/movement.dart`): the GPS and the bus API give
    isolated positions every few seconds; the map estimates the speed
    and the marker keeps moving between readings **along the street** (the
    walk, the bus route), turning at corners. Each new reading fixes the trajectory and the error from where it
    was seen is absorbed in ~0.5 s (e^-t/0.5): no jumps or braking; standing still does not
    tremble; a jump of more than 400 m is shown directly. It is kept with "quitar animaciones" (reduce motion) (it is the real
    position, not decoration).
  - If you move the map, a "volver a centrar" ("re-center") button appears; during the trip, the camera returns
    on its own after 12 s without touching it, and always when changing step.
  - Transitions between steps: the camera travels toward the new framing while chasing the user (who keeps
    moving), smoothing the jumps of the target (e.g. when the height of the card changes); on arrival it
    locks in without a jolt. While waiting, the framing already includes the start of the bus
    route, so boarding is a single movement.
  - Boarding: your bus, on reaching the stop, is marked "llegado" ("arrived") (the next one is not announced while
    you board). The prediction of its movement never passes your stop: only a real reading from the
    bus's GPS on the other side takes it further. As soon as you move 25 m away
    with it, it is shown on top of the bus (without waiting for the logic to confirm it at 60 m): the bus fades out at the stop and your dot
    merges into the bus badge (0.45 s).

## Composition by phase

- **Start**: "¿A dónde vas?" ("Where are you going?") pill at the top; round buttons to re-center and
  theme at the bottom right; stop sheet when one is tapped (with its bubble on the map).
- **Search**: solid full screen, rounded fields, "Mi ubicación" ("My location") in blue.
- **Options**: origin → destination header; sheet whose height adjusts to the content (the map frames
  just above it). Each option fills the sheet, with no frame: large duration + "18:01 – 18:33" + a
  Recomendado ("Recommended") stamp; a **leg bar** proportional to the duration (walks
  as chips with 🚶 and minutes, buses in red with the line); the
  live bus ("● El D1 pasa en 6 min" — "The D1 passes in 6 min"); where you board, how much you walk and the
  transfers. Below, "‹ • • • ›" (arrows for those who don't discover the swipe) and "Empezar viaje"
  ("Start trip") in ink, 58 dp, with a soft shadow.
- **Trip**: step card at the top — "Paso 2 de 4" ("Step 2 of 4") and "Llegás
  18:33" ("You arrive 18:33"), a strip of steps (the current one fills with its progress), instruction,
  a large figure and what is specific to each step:
  - walking: circular progress, when your bus passes or what comes next;
  - waiting: "Llega en 2 min · a 930 m" ("Arrives in 2 min · 930 m away"), a hint with the bus approaching
    your stop, EN VIVO / HORARIO label;
  - on the bus: "Faltan 12 paradas" ("12 stops left"), a strip of stops (the passed ones, where you are going,
    yours at the end) and "PRÓXIMA · name"; at the last one, the card is framed in a pulsing red
    border and says "Tocá el timbre para bajar" ("Press the bell to get off").
  Below: close, full itinerary ("Tu viaje" — "Your trip": all the steps with the done ones struck through and AHORA
  ("NOW") on the current one) and the manual fallback. Each advance is confirmed with a brief pill
  ("✓ Subiste al D1. ¡Buen viaje!" — "You boarded the D1. Have a good trip!") and a vibration.
- **Arrival**: green check that appears with a bounce, destination, and the summary
  (duration, distance walked, lines); it closes on its own.

## Motion

Round and action buttons sink slightly when touched (scale 0.94, 140 ms).
Large figures that change ("Faltan 9 paradas" → "8") rise with a short
fade, only when they change; the small data next to it (km) updates
without motion.

Panels 220–280 ms (fade + short slide); camera transitions 500–1100 ms ease-in-out and, when following, a soft
inertia (constant ~0.35 s); pulses, dashes and bubbles that float in a 3.2 s cycle, only if there is something
live on the map. Vibration when advancing a step (medium), on arrival and on
"bajate en la próxima" ("get off at the next one") (strong). With "quitar animaciones" (reduce motion) everything changes
instantly.
