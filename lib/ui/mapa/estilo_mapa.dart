// Estilo cartográfico del mapa en claro y oscuro.
//
// El mapa base es sobrio (grises cálidos / grafito) y queda atrás; lo único
// saturado es el viaje: caminar, bus y bus en vivo.

import 'dart:ui';

class EstiloMapa {
  final Brightness brillo;

  // --- base ---
  final Color tierra;
  final Color manzana;
  final Color comercial;
  final Color educacion;
  final Color pasto;
  final Color bosque;
  final Color arena;
  final Color agua;
  final Color edificio;
  final Color calle;
  final Color calleBorde;
  final Color avenida;
  final Color avenidaBorde;
  final Color autopista;
  final Color autopistaBorde;
  final Color sendero;
  final Color via;
  final Color rotulo;
  final Color rotuloHalo;
  final Color barrio;

  // --- viaje ---
  final Color caminar;
  final Color caminarTenue;
  final Color bus;
  final Color busTenue;
  final Color enVivo;
  final Color programado;
  final Color borde; // contorno de recorridos y marcadores
  final Color marcadorFondo;
  final Color tinta;
  final Color paradaRed;

  const EstiloMapa({
    required this.brillo,
    required this.tierra,
    required this.manzana,
    required this.comercial,
    required this.educacion,
    required this.pasto,
    required this.bosque,
    required this.arena,
    required this.agua,
    required this.edificio,
    required this.calle,
    required this.calleBorde,
    required this.avenida,
    required this.avenidaBorde,
    required this.autopista,
    required this.autopistaBorde,
    required this.sendero,
    required this.via,
    required this.rotulo,
    required this.rotuloHalo,
    required this.barrio,
    required this.caminar,
    required this.caminarTenue,
    required this.bus,
    required this.busTenue,
    required this.enVivo,
    required this.programado,
    required this.borde,
    required this.marcadorFondo,
    required this.tinta,
    required this.paradaRed,
  });

  static const claro = EstiloMapa(
    brillo: Brightness.light,
    tierra: Color(0xFFF4F3EF),
    manzana: Color(0xFFEFEEE9),
    comercial: Color(0xFFF1EDEA),
    educacion: Color(0xFFF2EEE3),
    pasto: Color(0xFFDDEBD3),
    bosque: Color(0xFFD1E4C6),
    arena: Color(0xFFF2EAD5),
    agua: Color(0xFFC9DFF0),
    edificio: Color(0xFFE6E3DC),
    calle: Color(0xFFFFFFFF),
    calleBorde: Color(0xFFE1DED6),
    avenida: Color(0xFFFFFFFF),
    avenidaBorde: Color(0xFFD6D2C8),
    autopista: Color(0xFFFCEFD2),
    autopistaBorde: Color(0xFFE7D2A6),
    sendero: Color(0xFFD5D1C7),
    via: Color(0xFFC4C1BA),
    rotulo: Color(0xFF6A6E76),
    rotuloHalo: Color(0xFFF7F6F3),
    barrio: Color(0xFF8C9098),
    caminar: Color(0xFF2563EB),
    caminarTenue: Color(0xFF9DB7F3),
    bus: Color(0xFFE0412F),
    busTenue: Color(0xFFF0A79D),
    enVivo: Color(0xFF0E9F6B),
    programado: Color(0xFFD48806),
    borde: Color(0xFFFFFFFF),
    marcadorFondo: Color(0xFFFFFFFF),
    tinta: Color(0xFF111318),
    paradaRed: Color(0xFF3B4250),
  );

  static const oscuro = EstiloMapa(
    brillo: Brightness.dark,
    tierra: Color(0xFF181B21),
    manzana: Color(0xFF1C2027),
    comercial: Color(0xFF1E2128),
    educacion: Color(0xFF1F2229),
    pasto: Color(0xFF1B2721),
    bosque: Color(0xFF192A21),
    arena: Color(0xFF26241F),
    agua: Color(0xFF0E2233),
    edificio: Color(0xFF232830),
    calle: Color(0xFF2A303A),
    calleBorde: Color(0xFF15181D),
    avenida: Color(0xFF363D49),
    avenidaBorde: Color(0xFF14171C),
    autopista: Color(0xFF4A4436),
    autopistaBorde: Color(0xFF15171B),
    sendero: Color(0xFF30353E),
    via: Color(0xFF3A3F48),
    rotulo: Color(0xFF9CA4B2),
    rotuloHalo: Color(0xFF181B21),
    barrio: Color(0xFF79818E),
    caminar: Color(0xFF6B9BFF),
    caminarTenue: Color(0xFF34466E),
    bus: Color(0xFFFF6A55),
    busTenue: Color(0xFF6B3A35),
    enVivo: Color(0xFF36D08F),
    programado: Color(0xFFF2A93B),
    borde: Color(0xFF0E1014),
    marcadorFondo: Color(0xFF22262E),
    tinta: Color(0xFFF2F4F7),
    paradaRed: Color(0xFFB9C1CE),
  );

  static EstiloMapa de(Brightness b) => b == Brightness.dark ? oscuro : claro;
}
