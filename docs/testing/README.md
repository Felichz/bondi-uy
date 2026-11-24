# BondiUY Tests

Everything runs with `flutter test`, without an emulator or network. The tests use real
recorded Montevideo data and a deterministic simulated world.

## Data

| Source | What it is |
|---|---|
| `test/fixtures/trip_saldanha_plaza_otp_v2.json` | Real OTP response (12 itineraries) Saldanha da Gama 3941 → Plaza Independencia, synthetic GPS every 5 s and real polls from the IM bus API (D1 direct; 526 → 109 with a transfer). |
| `test/fixtures/teselas/{z}/{x}/{y}.pbf` | OSM vector tiles (z10–14) of the area, to draw the real map without a network. |
| `assets/data/shapes.geojson`, `stops.geojson` | Bundled GTFS (shapes for the bus approach; stops with lines). |

## Layers

1. **Pure logic** (`test/logic/`)
   - `trip_navigator_test.dart`: replays the recorded GPS and requires strict step-by-step
     progress (4 steps on D1, 7 with a transfer), walk progress,
     stops missing from the bus, that waiting still does not trigger boarding,
     manual fallback, and a jump if the GPS lost the boarding.
   - `bus_tracker_test.dart`: each real poll produces an approach that
     follows the street (never a straight line), same vehicle between polls, a bus that
     has already passed does not "come", the one that arrived at the stop is reported as "llegado" ("arrived") (not the next one) for a few polls, without a shape no geometry is invented.
   - `app_controller_test.dart`: suggestion debounce, planning with a single
     recommended option, ETAs, polling according to the step, stop queried, permissions.

2. **Full app headless** (`test/ui/`): mounts `BondiApp` with the real logic, the real
   map (tiles in memory), the recorded OTP plan and the
   simulated world with fake time. It interacts with the UI like a user.
   - `main_flow_test.dart`: search → options → start → walk →
     wait → bus → walk → "You arrived!" → home; also with the system's "reduce motion" enabled and in dark theme.
   - `trip_map_test.dart`: the camera follows the user (walks tens of meters and on screen it does not
     move), bubbles for the relevant stops (boarding, next, "Get off at this one!", destination), the camera returns
     on its own if you move the map, the full itinerary, capitalization of destinations, and
     boarding the bus frame by frame (60 fps): a single movement, without
     jumps or jerks, without "no data" or the next bus in the card.
   - `movement_test.dart`: with readings every 5 s the marker advances without
     braking or jumping and turns along the street; standing still does not tremble; large jumps
     are shown directly.
   - `labels_test.dart`: street names are placed in close views
     (center and Malvín), within the visible area.
   - `secondary_flows_test.dart`: transfer, going back from options, ending the trip, manual fallback, tapped stop, swapping origin and
     destination, planning error with retry, no results, no location permission.
   - Each checkpoint saves a screenshot to `build/capturas/<flujo>_NN_<step>.png`
     (real fonts loaded), for human review.

3. **Visual probe** (`test/ui/render_tesela_probe_test.dart`): renders tiles in light and dark to `build/sondas/` to tune the map style.

## On the emulator

`simulated` mode to go through all the flows with real OTP and accelerated movement; `recorded` mode to do it
without a server. See the README.

## Recording a new trip

`dart run tool/capture_trip.dart --help` (requires a local OTP; optionally the IM credentials to record real bus polls).
