// Map cartographic style in light and dark.
//
// The base map is sober (warm greys / graphite) and stays in the background;
// the only saturated thing is the trip: walking, bus and live bus.

import 'dart:ui';

class MapStyle {
  final Brightness glow;

  // --- base ---
  final Color land;
  final Color block;
  final Color commercial;
  final Color education;
  final Color grass;
  final Color forest;
  final Color arena;
  final Color water;
  final Color building;
  final Color street;
  final Color streetBorder;
  final Color avenue;
  final Color avenueBorder;
  final Color motorway;
  final Color motorwayBorder;
  final Color footway;
  final Color via;
  final Color label;
  final Color labelHalo;
  final Color neighborhood;

  // --- trip ---
  final Color walk;
  final Color walkFaint;
  final Color bus;
  final Color busFaint;
  final Color live;
  final Color scheduled;
  final Color border; // outline of routes and markers
  final Color markerBackground;
  final Color ink;
  final Color networkStop;

  const MapStyle({
    required this.glow,
    required this.land,
    required this.block,
    required this.commercial,
    required this.education,
    required this.grass,
    required this.forest,
    required this.arena,
    required this.water,
    required this.building,
    required this.street,
    required this.streetBorder,
    required this.avenue,
    required this.avenueBorder,
    required this.motorway,
    required this.motorwayBorder,
    required this.footway,
    required this.via,
    required this.label,
    required this.labelHalo,
    required this.neighborhood,
    required this.walk,
    required this.walkFaint,
    required this.bus,
    required this.busFaint,
    required this.live,
    required this.scheduled,
    required this.border,
    required this.markerBackground,
    required this.ink,
    required this.networkStop,
  });

  static const light = MapStyle(
    glow: Brightness.light,
    land: Color(0xFFF4F3EF),
    block: Color(0xFFEFEEE9),
    commercial: Color(0xFFF1EDEA),
    education: Color(0xFFF2EEE3),
    grass: Color(0xFFDDEBD3),
    forest: Color(0xFFD1E4C6),
    arena: Color(0xFFF2EAD5),
    water: Color(0xFFC9DFF0),
    building: Color(0xFFE6E3DC),
    street: Color(0xFFFFFFFF),
    streetBorder: Color(0xFFE1DED6),
    avenue: Color(0xFFFFFFFF),
    avenueBorder: Color(0xFFD6D2C8),
    motorway: Color(0xFFFCEFD2),
    motorwayBorder: Color(0xFFE7D2A6),
    footway: Color(0xFFD5D1C7),
    via: Color(0xFFC4C1BA),
    label: Color(0xFF6A6E76),
    labelHalo: Color(0xFFF7F6F3),
    neighborhood: Color(0xFF8C9098),
    walk: Color(0xFF2563EB),
    walkFaint: Color(0xFF9DB7F3),
    bus: Color(0xFFE0412F),
    busFaint: Color(0xFFF0A79D),
    live: Color(0xFF0E9F6B),
    scheduled: Color(0xFFD48806),
    border: Color(0xFFFFFFFF),
    markerBackground: Color(0xFFFFFFFF),
    ink: Color(0xFF111318),
    networkStop: Color(0xFF3B4250),
  );

  static const dark = MapStyle(
    glow: Brightness.dark,
    land: Color(0xFF181B21),
    block: Color(0xFF1C2027),
    commercial: Color(0xFF1E2128),
    education: Color(0xFF1F2229),
    grass: Color(0xFF1B2721),
    forest: Color(0xFF192A21),
    arena: Color(0xFF26241F),
    water: Color(0xFF0E2233),
    building: Color(0xFF232830),
    street: Color(0xFF2A303A),
    streetBorder: Color(0xFF15181D),
    avenue: Color(0xFF363D49),
    avenueBorder: Color(0xFF14171C),
    motorway: Color(0xFF4A4436),
    motorwayBorder: Color(0xFF15171B),
    footway: Color(0xFF30353E),
    via: Color(0xFF3A3F48),
    label: Color(0xFF9CA4B2),
    labelHalo: Color(0xFF181B21),
    neighborhood: Color(0xFF79818E),
    walk: Color(0xFF6B9BFF),
    walkFaint: Color(0xFF34466E),
    bus: Color(0xFFFF6A55),
    busFaint: Color(0xFF6B3A35),
    live: Color(0xFF36D08F),
    scheduled: Color(0xFFF2A93B),
    border: Color(0xFF0E1014),
    markerBackground: Color(0xFF22262E),
    ink: Color(0xFFF2F4F7),
    networkStop: Color(0xFFB9C1CE),
  );

  static MapStyle of(Brightness b) => b == Brightness.dark ? dark : light;
}
