# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

(Flutter app; Android is the verified target — emulator `bondi_api35`. The iOS
folder exists but has not been validated. Mapbox Maps only renders on
Android/iOS; Windows desktop is used for headless widget tests only.)

## Users

People in Montevideo who need to get from A to B by bus, including people who
are not comfortable with technology ("abuelita first"). They use the app on the
street, often standing, in daylight, one hand busy, sometimes anxious about
missing the bus or the stop. The job: know which bus to take, where to get on,
when it arrives, and when to get off — without having to understand a transit
map.

## Product Purpose

A personal, calm assistant for one trip at a time. It plans a route from the
user's location (or another origin) to a destination, recommends one option,
and then guides the trip step by step, advancing automatically with GPS:
walk to the stop → wait for the bus (live position and ETA when available) →
ride (the bus is drawn where the user is) → walk to the destination → arrival.

Success: the user arrives without stress and never has to interpret the
interface. The "test de la abuelita" is the acceptance criterion.

## Positioning

The opposite of Moovit-style transit apps: no encyclopedia of lines, no dense
option lists. One recommended trip, a map that narrates it, and live bus
tracking from the Intendencia de Montevideo API fused with the user's own GPS
(once aboard, the user's location *is* the bus).

## Operating Context

- Search: origin defaults to "Mi ubicación" and is editable; destination via
  place suggestions (Mapbox geocoding, Uruguay). Origin/destination can be swapped.
- Options: a carousel with the recommended option preselected; moving through
  the carousel previews each trip on the map, including the live approaching
  bus and its green approach path when an ETA exists.
- Active trip: automatic step navigation (GPS every ~5 s, bus polling every
  ~10 s), with a discreet manual fallback on each step ("Ya subí",
  "Ya llegué") for when detection fails.
- Arrival: a brief "¡Llegaste!" confirmation, then back to search with a clean map.
- Explore (no trip): bus stops on the map; tapping one shows its upcoming arrivals.
- Data sources: OTP 2.7 (GraphQL, local server with the MVD GTFS + Uruguay OSM),
  Montevideo `transporteRest/siguientesParada/{stop}` for ETAs and bus
  positions, GTFS shapes/stops bundled as GeoJSON assets.

## Capabilities and Constraints

- Strict two-layer architecture: a presentational UI layer and a logic layer
  joined by one contract (state in, actions out). The logic layer never knows
  about Mapbox, widgets, colors or text; it sends raw numbers/enums and the UI
  formats them. Mapbox (layers, camera, gestures) is a UI concern.
- UI languages: Spanish (Uruguay, voseo) and English (2026-10-31, for the
  portfolio audience); device language by default, `?lang=` on the web, and
  an ES/EN toggle. All copy lives in the UI layer (`lib/ui/textos/`).
- Demo mode (`BONDI_MODO=demo`, default on the web): five real OTP trips
  recorded from Malvín, simulated user and buses, adjustable time speed. No
  backend needed, so anyone can try it (web demo and APK).
- Must be testable without a device: deterministic replays of recorded or
  synthetic trips (OTP responses, GPS streams, ETA snapshots) with real
  Montevideo addresses.
- Undecided / later: recent & favorite places, push notifications for
  "your bus is arriving" / "get off at the next stop", analytics.

## Brand Commitments

- Name: BondiUY. "Bondi" is the rioplatense word for bus.
- Visual direction (pinned by the user, 2026-09-27; replaces the earlier
  pixel-art direction, which read as "too comic"): **professional, elegant
  white** — opaque panels with subtle, modern gradients (2026-09-28: the
  translucent-glass variant was tried and dropped to keep text contrast),
  over a sober vector map; with a first-class **dark theme** (follows the system by
  default, manual toggle). Craft bar: Apple Maps / Google Maps / Citymapper.

## Evidence on Hand

- Recorded fixture: Saldanha da Gama 3941 → Plaza Independencia
  (`test/fixtures/trip_saldanha_plaza_otp_v2.json`): 12 OTP options, synthetic
  GPS, real ETA polls for D1 (direct) and 526 → 109 (transfer).
- No testimonials, ratings or usage numbers exist; none may be invented.

## Product Principles

1. One trip, one recommendation. Alternatives are available, never pushed.
2. The map narrates; the panel instructs. Every step has one instruction a
   person can follow without reading twice.
3. Automatic first, never stuck: the app advances by itself, and the user can
   always nudge it forward.
4. Show only truthful live information. No invented bus paths, no stale ETAs
   presented as live.
5. Calm under stress: big targets, big numbers, no clutter, no jargon.

## Accessibility & Inclusion

Older and non-technical users: large tap targets (≥48 dp, primary actions
larger), large numerals for time/distance, high contrast legible outdoors in
sunlight, meaning never carried by color alone, support for system font scaling.
