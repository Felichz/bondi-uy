// Acciones que la UI puede pedirle a la lógica. Es la ÚNICA salida de la UI.
//
// Cada acción expresa una intención del usuario, no un detalle de
// implementación. La lógica decide cómo cumplirla y responde cambiando el
// AppState.

import 'app_state.dart';

abstract interface class AppActions {
  // --- Arranque y ubicación ---

  /// La UI está lista (mapa montado). Pide ubicación y carga la red de paradas.
  void arrancar();

  /// Reintenta obtener la ubicación (p.ej. después de conceder el permiso).
  void reintentarUbicacion();

  // --- Búsqueda ---

  /// El usuario escribió en un campo. Dispara sugerencias (con debounce).
  void escribirConsulta(CampoBusqueda campo, String texto);

  void elegirLugar(CampoBusqueda campo, Lugar lugar);

  /// Usa "Mi ubicación" en el campo.
  void usarMiUbicacion(CampoBusqueda campo);

  /// Vacía el campo (el origen vuelve a "Mi ubicación").
  void limpiarCampo(CampoBusqueda campo);

  void intercambiarOrigenYDestino();

  /// Cierra el desplegable de sugerencias sin elegir.
  void cancelarConsulta();

  /// Planifica origen -> destino y pasa a la fase de opciones.
  void buscarViajes();

  // --- Opciones ---

  /// La UI está mostrando esta opción: seguir en vivo su primer bus.
  void enfocarOpcion(String idOpcion);

  /// Vuelve a explorar conservando origen y destino.
  void cerrarOpciones();

  void iniciarViaje(String idOpcion);

  // --- Viaje activo ---

  /// Respaldo manual: el usuario confirma que completó el paso actual
  /// ("Ya llegué a la parada", "Ya subí", "Ya me bajé", "Ya llegué").
  void confirmarPasoActual();

  /// Abandona el viaje en curso.
  void terminarViaje();

  /// Cierra la confirmación de llegada y vuelve a explorar.
  void cerrarLlegada();

  // --- Paradas ---

  void consultarParada(String idParada);
  void cerrarParada();

  // --- Avisos ---
  void descartarAviso(int idAviso);
}
