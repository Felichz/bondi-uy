// Textos de la interfaz en español (rioplatense, voseo) e inglés.
//
// La lógica nunca manda texto: solo datos. Todo lo que se lee está acá. El
// idioma se elige en la raíz de la app (`fijarIdioma`) y se lee con `tx`.

enum Idioma { es, en }

Textos _actual = const TextosEs();

/// Los textos del idioma actual.
Textos get tx => _actual;

void fijarIdioma(Idioma i) =>
    _actual = i == Idioma.en ? const TextosEn() : const TextosEs();

const _nb = ' ';

abstract class Textos {
  const Textos();
  Idioma get idioma;

  // --- formatos -------------------------------------------------------------
  String get menosDeUnMin;
  String get ya;
  String paradas(int n);

  // --- avisos ---------------------------------------------------------------
  String get avisoSinUbicacion;
  String get avisoSinConexion;
  String get avisoErrorPlanificacion;
  String get avisoErrorSugerencias;
  String get avisoErrorParada;
  String get avisoFaltaDestino;
  String get avisoBajate;
  String get avisoBusLlegando;

  // --- comunes --------------------------------------------------------------
  String get recentrarMapa;
  String get verElBus;
  String get verme;
  String get elegiUnLugar;
  String get miUbicacion;
  String get tuDestino;
  String linea(String l);
  String get cerrar;
  String get volver;
  String desde(String origen);

  // --- inicio ---------------------------------------------------------------
  String get aDondeVas;
  String get verViajes;
  String temaEtiqueta(String nombre);
  String get temaAutomatico;
  String get temaClaro;
  String get temaOscuro;
  String get temaAvisoAutomatico;
  String get temaAvisoClaro;
  String get temaAvisoOscuro;
  String get ubicacionApagada;
  String get ubicacionSinPermiso;
  String get ubicacionNoEncontrada;
  String get activar;
  String paradaNumero(String id);
  String get paradaErrorLlegadas;
  String get paradaSinInfo;
  String paradaSinProximos(String lineas);
  String get enVivo;
  String get horario;
  String get idiomaEtiqueta;

  // --- búsqueda -------------------------------------------------------------
  String get desdeCampo;
  String get intercambiar;
  String get borrar;
  String get lugarNoEncontrado;
  String get errorBuscarLugares;
  String get ayudaBusqueda;

  // --- opciones -------------------------------------------------------------
  String get errorPlanTitulo;
  String get errorPlanTexto;
  String get sinViajesTitulo;
  String get sinViajesTexto;
  String get buscandoViaje;
  String get reintentar;
  String get cambiarDestino;
  String get empezarViaje;
  String opcionNdeM(int n, int m);
  String get opcionAnterior;
  String get opcionSiguiente;
  String subisEn(String parada);
  String caminas(String dist);
  String trasbordos(int n);
  String get recomendado;
  String barraTramos(List<String> lineas);
  String get todoAPie;
  String pasaQuizasNoLlegues(String linea, String min);
  String pasaEn(String linea, String min);
  String pasariaEn(String linea, String min);
  String saleSinDatos(String hora);

  // --- viaje ----------------------------------------------------------------
  String get llegasteAParada;
  String subisteAl(String linea);
  String tebajasteDel(String linea);
  String pasoNdeM(int n, int m);
  String llegas(String hora);
  String parada(String nombre);
  String get caminaAlDestino;
  String get caminaALaParada;
  String caminando(String tiempo);
  String despuesEspera(String linea);
  String pasaApurate(String min);
  String pasaEnCorto(String min, {required bool enVivo});
  String get llegoTuBus;
  String get llegando;
  String llegaEn(String min);
  String aDistancia(String dist);
  String enAprox(String min);
  String get segunHorario;
  String get sinDatosBus;
  String espera(String linea);
  String hacia(String destino);
  String get hacelSeniaSubi;
  String get enVivoMayus;
  String get horarioMayus;
  String get hacelSenia;
  String get puedeVariar;
  String busADistancia(String dist);
  String get bajateEnLaProxima;
  String viajaEn(String linea);
  String bajateEn(String parada);
  String get tocaElTimbre;
  String faltan(String paradas);
  String get proximaMayus;
  String faltanParaBajarte(String paradas);
  String get yaLlegue;
  String get yaEstoyEnLaParada;
  String get yaSubi;
  String get yaMeBaje;
  String get terminarViaje;
  String get verTodoElViaje;
  String get terminarPregunta;
  String get terminarTexto;
  String get seguir;
  String get terminar;
  String get llegaste;
  String get listo;

  // --- itinerario -----------------------------------------------------------
  String get tuViaje;
  String aDestinoLlegas(String destino, String hora);
  String camina(String dist);
  String hastaDestino(String destino);
  String hastaLaParada(String parada);
  String bajateEnResumen(String parada, String paradas, String tiempo);
  String get ahoraMayus;

  // --- mapa -----------------------------------------------------------------
  String get tuParada;
  String get teBajas;
  String get proximaParadaMayus;
  String subisAl(String linea);
  String cambiasAl(String linea);
  String get bajateEnEsta;
  String get teBajasAca;
  String get tocaElTimbreMayus;
  String enParadas(String paradas);
  String get tuDestinoMayus;
  String get llegandoMinus;

  // --- web ------------------------------------------------------------------
  String get webLema;
  String get webDemo;
  String get webDescargar;
  String get webCodigo;
  String get avisoApp;
  String get avisoAppDetalle;
  String get avisoAppDescargar;
  String get avisoAppCerrar;

  // --- demo -----------------------------------------------------------------
  String get probaUnViaje;
  String get demoExplicacion;
}

class TextosEs extends Textos {
  const TextosEs();
  @override
  Idioma get idioma => Idioma.es;

  @override
  String get menosDeUnMin => 'menos de 1${_nb}min';
  @override
  String get ya => 'ya';
  @override
  String paradas(int n) => n == 1 ? '1${_nb}parada' : '$n${_nb}paradas';

  @override
  String get avisoSinUbicacion =>
      'No sabemos dónde estás. Activá la ubicación o elegí un punto de partida.';
  @override
  String get avisoSinConexion => 'Sin conexión. Revisá tus datos o el wifi.';
  @override
  String get avisoErrorPlanificacion =>
      'No pudimos calcular el viaje. Probá de nuevo en un momento.';
  @override
  String get avisoErrorSugerencias =>
      'No pudimos buscar lugares. Revisá tu conexión.';
  @override
  String get avisoErrorParada =>
      'No pudimos ver los próximos buses de esa parada.';
  @override
  String get avisoFaltaDestino => 'Elegí a dónde querés ir.';
  @override
  String get avisoBajate => '¡Bajate en la próxima parada!';
  @override
  String get avisoBusLlegando => '¡Tu bus está llegando! Preparate para subir.';

  @override
  String get recentrarMapa => 'Volver a centrar el mapa';
  @override
  String get verElBus => 'Ver el bus';
  @override
  String get verme => 'Verme a mí';
  @override
  String get elegiUnLugar => 'Elegí un lugar';
  @override
  String get miUbicacion => 'Mi ubicación';
  @override
  String get tuDestino => 'Tu destino';
  @override
  String linea(String l) => 'Línea $l';
  @override
  String get cerrar => 'Cerrar';
  @override
  String get volver => 'Volver';
  @override
  String desde(String origen) => 'Desde $origen';

  @override
  String get aDondeVas => '¿A dónde vas?';
  @override
  String get verViajes => 'Ver viajes';
  @override
  String temaEtiqueta(String nombre) => 'Tema $nombre. Tocá para cambiar';
  @override
  String get temaAutomatico => 'automático';
  @override
  String get temaClaro => 'claro';
  @override
  String get temaOscuro => 'oscuro';
  @override
  String get temaAvisoAutomatico => 'Tema automático (como tu teléfono)';
  @override
  String get temaAvisoClaro => 'Tema claro';
  @override
  String get temaAvisoOscuro => 'Tema oscuro';
  @override
  String get ubicacionApagada =>
      'Tu ubicación está apagada. Activala para saber dónde estás.';
  @override
  String get ubicacionSinPermiso =>
      'BondiUY necesita tu ubicación para guiarte en el viaje.';
  @override
  String get ubicacionNoEncontrada => 'No pudimos encontrar tu ubicación.';
  @override
  String get activar => 'Activar';
  @override
  String paradaNumero(String id) => 'Parada $id';
  @override
  String get paradaErrorLlegadas =>
      'No pudimos ver los próximos buses. Probá de nuevo en un rato.';
  @override
  String get paradaSinInfo => 'No hay información de buses para esta parada.';
  @override
  String paradaSinProximos(String lineas) =>
      'No hay buses próximos informados.\nPasan: $lineas';
  @override
  String get enVivo => 'en vivo';
  @override
  String get horario => 'horario';
  @override
  String get idiomaEtiqueta => 'Idioma: español. Tocá para cambiar a inglés';

  @override
  String get desdeCampo => 'Desde';
  @override
  String get intercambiar => 'Intercambiar origen y destino';
  @override
  String get borrar => 'Borrar';
  @override
  String get lugarNoEncontrado =>
      'No encontramos ese lugar en Montevideo. Probá con una calle y número, o un lugar conocido.';
  @override
  String get errorBuscarLugares =>
      'No pudimos buscar lugares. Revisá tu conexión e intentá de nuevo.';
  @override
  String get ayudaBusqueda =>
      'Escribí una dirección, una esquina o un lugar.\nPor ejemplo: "18 de Julio y Ejido".';

  @override
  String get errorPlanTitulo => 'No pudimos calcular el viaje';
  @override
  String get errorPlanTexto => 'Revisá tu conexión y probá de nuevo.';
  @override
  String get sinViajesTitulo => 'No encontramos viajes en bus';
  @override
  String get sinViajesTexto => 'Probá con otro destino o más tarde.';
  @override
  String get buscandoViaje => 'Buscando el mejor viaje…';
  @override
  String get reintentar => 'Reintentar';
  @override
  String get cambiarDestino => 'Cambiar destino';
  @override
  String get empezarViaje => 'Empezar viaje';
  @override
  String opcionNdeM(int n, int m) => 'Opción $n de $m';
  @override
  String get opcionAnterior => 'Opción anterior';
  @override
  String get opcionSiguiente => 'Opción siguiente';
  @override
  String subisEn(String parada) => 'Subís en $parada';
  @override
  String caminas(String dist) => 'caminás $dist';
  @override
  String trasbordos(int n) => n == 1 ? '1 trasbordo' : '$n trasbordos';
  @override
  String get recomendado => 'Recomendado';
  @override
  String barraTramos(List<String> lineas) =>
      'Caminás, tomás ${lineas.length == 1 ? 'el' : 'los'} ${lineas.join(', ')} y caminás hasta el destino';
  @override
  String get todoAPie => 'Todo el viaje a pie';
  @override
  String pasaQuizasNoLlegues(String linea, String min) =>
      'El $linea pasa en $min: quizás no llegues';
  @override
  String pasaEn(String linea, String min) => 'El $linea pasa en $min';
  @override
  String pasariaEn(String linea, String min) =>
      'El $linea pasaría en $min (horario)';
  @override
  String saleSinDatos(String hora) => 'Sale $hora · sin datos en vivo';

  @override
  String get llegasteAParada => 'Llegaste a la parada';
  @override
  String subisteAl(String linea) => 'Subiste al $linea. ¡Buen viaje!';
  @override
  String tebajasteDel(String linea) => 'Te bajaste del $linea';
  @override
  String pasoNdeM(int n, int m) => 'Paso $n de $m';
  @override
  String llegas(String hora) => 'Llegás $hora';
  @override
  String parada(String nombre) => 'Parada $nombre';
  @override
  String get caminaAlDestino => 'Caminá hasta tu destino';
  @override
  String get caminaALaParada => 'Caminá hasta la parada';
  @override
  String caminando(String tiempo) => '$tiempo caminando';
  @override
  String despuesEspera(String linea) => 'Después: esperá el $linea';
  @override
  String pasaApurate(String min) => 'Pasa en $min: apurate un poco';
  @override
  String pasaEnCorto(String min, {required bool enVivo}) =>
      'Pasa en $min${enVivo ? '' : ' (horario)'}';
  @override
  String get llegoTuBus => '¡Llegó tu bus!';
  @override
  String get llegando => '¡Llegando!';
  @override
  String llegaEn(String min) => 'Llega en $min';
  @override
  String aDistancia(String dist) => 'a $dist';
  @override
  String enAprox(String min) => 'En ~$min';
  @override
  String get segunHorario => 'según horario';
  @override
  String get sinDatosBus =>
      'Sin datos en vivo de este bus. Esperalo en la parada.';
  @override
  String espera(String linea) => 'Esperá el $linea';
  @override
  String hacia(String destino) => 'Hacia $destino';
  @override
  String get hacelSeniaSubi => 'Hacele seña y subí cuando pare.';
  @override
  String get enVivoMayus => 'EN VIVO';
  @override
  String get horarioMayus => 'HORARIO';
  @override
  String get hacelSenia => 'Hacele seña cuando lo veas venir';
  @override
  String get puedeVariar => 'Puede variar unos minutos';
  @override
  String busADistancia(String dist) => 'El bus está a $dist de tu parada';
  @override
  String get bajateEnLaProxima => '¡Bajate en la próxima!';
  @override
  String viajaEn(String linea) => 'Viajá en el $linea';
  @override
  String bajateEn(String parada) => 'Bajate en $parada';
  @override
  String get tocaElTimbre => 'Tocá el timbre para bajar';
  @override
  String faltan(String paradas) => 'Faltan $paradas';
  @override
  String get proximaMayus => 'PRÓXIMA';
  @override
  String faltanParaBajarte(String paradas) => 'Faltan $paradas para bajarte';
  @override
  String get yaLlegue => 'Ya llegué';
  @override
  String get yaEstoyEnLaParada => 'Ya estoy en la parada';
  @override
  String get yaSubi => 'Ya subí al bus';
  @override
  String get yaMeBaje => 'Ya me bajé';
  @override
  String get terminarViaje => 'Terminar viaje';
  @override
  String get verTodoElViaje => 'Ver todo el viaje';
  @override
  String get terminarPregunta => '¿Terminar el viaje?';
  @override
  String get terminarTexto =>
      'Dejamos de guiarte. Podés buscar otro viaje cuando quieras.';
  @override
  String get seguir => 'Seguir';
  @override
  String get terminar => 'Terminar';
  @override
  String get llegaste => '¡Llegaste!';
  @override
  String get listo => 'Listo';

  @override
  String get tuViaje => 'Tu viaje';
  @override
  String aDestinoLlegas(String destino, String hora) =>
      'A $destino · llegás $hora';
  @override
  String camina(String dist) => 'Caminá $dist';
  @override
  String hastaDestino(String destino) => 'Hasta $destino';
  @override
  String hastaLaParada(String parada) => 'Hasta la parada $parada';
  @override
  String bajateEnResumen(String parada, String paradas, String tiempo) =>
      'Bajate en $parada · $paradas · $tiempo';
  @override
  String get ahoraMayus => 'AHORA';

  @override
  String get tuParada => 'Tu parada';
  @override
  String get teBajas => 'Te bajás';
  @override
  String get proximaParadaMayus => 'PRÓXIMA PARADA';
  @override
  String subisAl(String linea) => 'Subís al $linea';
  @override
  String cambiasAl(String linea) => 'Cambiás al $linea';
  @override
  String get bajateEnEsta => '¡Bajate en esta!';
  @override
  String get teBajasAca => 'Te bajás acá';
  @override
  String get tocaElTimbreMayus => 'TOCÁ EL TIMBRE';
  @override
  String enParadas(String paradas) => 'en $paradas';
  @override
  String get tuDestinoMayus => 'TU DESTINO';
  @override
  String get llegandoMinus => 'llegando';

  @override
  String get webLema => 'Tu viaje en bondi por Montevideo, paso a paso.';
  @override
  String get webDemo =>
      'Esto es una demo: los viajes son reales, planificados con los horarios y '
      'recorridos de la Intendencia, y grabados. Vos y los buses se mueven '
      'solos, con el tiempo acelerado.';
  @override
  String get webDescargar => 'Descargar para Android';
  @override
  String get webCodigo => 'Código fuente';
  @override
  String get avisoApp => 'BondiUY para Android';
  @override
  String get avisoAppDetalle => 'La misma demo, instalada en tu teléfono.';
  @override
  String get avisoAppDescargar => 'Descargar';
  @override
  String get avisoAppCerrar => 'Cerrar';

  @override
  String get probaUnViaje => 'Probá un viaje';
  @override
  String get demoExplicacion =>
      'Viajes reales en bus por Montevideo, grabados. Vos y los buses se mueven solos.';
}

class TextosEn extends Textos {
  const TextosEn();
  @override
  Idioma get idioma => Idioma.en;

  @override
  String get menosDeUnMin => 'under 1${_nb}min';
  @override
  String get ya => 'now';
  @override
  String paradas(int n) => n == 1 ? '1${_nb}stop' : '$n${_nb}stops';

  @override
  String get avisoSinUbicacion =>
      'We don’t know where you are. Turn on location or pick a starting point.';
  @override
  String get avisoSinConexion => 'No connection. Check your data or wifi.';
  @override
  String get avisoErrorPlanificacion =>
      'We couldn’t plan the trip. Try again in a moment.';
  @override
  String get avisoErrorSugerencias =>
      'We couldn’t search places. Check your connection.';
  @override
  String get avisoErrorParada =>
      'We couldn’t get the next buses for that stop.';
  @override
  String get avisoFaltaDestino => 'Choose where you want to go.';
  @override
  String get avisoBajate => 'Get off at the next stop!';
  @override
  String get avisoBusLlegando => 'Your bus is coming! Get ready to board.';

  @override
  String get recentrarMapa => 'Recenter the map';
  @override
  String get verElBus => 'Show the bus';
  @override
  String get verme => 'Show me';
  @override
  String get elegiUnLugar => 'Choose a place';
  @override
  String get miUbicacion => 'My location';
  @override
  String get tuDestino => 'Your destination';
  @override
  String linea(String l) => 'Line $l';
  @override
  String get cerrar => 'Close';
  @override
  String get volver => 'Back';
  @override
  String desde(String origen) => 'From $origen';

  @override
  String get aDondeVas => 'Where to?';
  @override
  String get verViajes => 'See trips';
  @override
  String temaEtiqueta(String nombre) => '$nombre theme. Tap to change';
  @override
  String get temaAutomatico => 'Automatic';
  @override
  String get temaClaro => 'Light';
  @override
  String get temaOscuro => 'Dark';
  @override
  String get temaAvisoAutomatico => 'Automatic theme (follows your phone)';
  @override
  String get temaAvisoClaro => 'Light theme';
  @override
  String get temaAvisoOscuro => 'Dark theme';
  @override
  String get ubicacionApagada =>
      'Your location is off. Turn it on so we know where you are.';
  @override
  String get ubicacionSinPermiso =>
      'BondiUY needs your location to guide you on the trip.';
  @override
  String get ubicacionNoEncontrada => 'We couldn’t find your location.';
  @override
  String get activar => 'Turn on';
  @override
  String paradaNumero(String id) => 'Stop $id';
  @override
  String get paradaErrorLlegadas =>
      'We couldn’t get the next buses. Try again in a while.';
  @override
  String get paradaSinInfo => 'No bus information for this stop.';
  @override
  String paradaSinProximos(String lineas) =>
      'No upcoming buses reported.\nLines: $lineas';
  @override
  String get enVivo => 'live';
  @override
  String get horario => 'scheduled';
  @override
  String get idiomaEtiqueta => 'Language: English. Tap to switch to Spanish';

  @override
  String get desdeCampo => 'From';
  @override
  String get intercambiar => 'Swap origin and destination';
  @override
  String get borrar => 'Clear';
  @override
  String get lugarNoEncontrado =>
      'We couldn’t find that place in Montevideo. Try a street and number, or a well-known place.';
  @override
  String get errorBuscarLugares =>
      'We couldn’t search places. Check your connection and try again.';
  @override
  String get ayudaBusqueda =>
      'Type an address, a corner or a place.\nFor example: "18 de Julio y Ejido".';

  @override
  String get errorPlanTitulo => 'We couldn’t plan the trip';
  @override
  String get errorPlanTexto => 'Check your connection and try again.';
  @override
  String get sinViajesTitulo => 'No bus trips found';
  @override
  String get sinViajesTexto => 'Try another destination or later.';
  @override
  String get buscandoViaje => 'Finding the best trip…';
  @override
  String get reintentar => 'Try again';
  @override
  String get cambiarDestino => 'Change destination';
  @override
  String get empezarViaje => 'Start trip';
  @override
  String opcionNdeM(int n, int m) => 'Option $n of $m';
  @override
  String get opcionAnterior => 'Previous option';
  @override
  String get opcionSiguiente => 'Next option';
  @override
  String subisEn(String parada) => 'Board at $parada';
  @override
  String caminas(String dist) => 'walk $dist';
  @override
  String trasbordos(int n) => n == 1 ? '1 transfer' : '$n transfers';
  @override
  String get recomendado => 'Recommended';
  @override
  String barraTramos(List<String> lineas) =>
      'Walk, take ${lineas.join(', ')} and walk to your destination';
  @override
  String get todoAPie => 'Walk the whole way';
  @override
  String pasaQuizasNoLlegues(String linea, String min) =>
      'The $linea comes in $min: you may not make it';
  @override
  String pasaEn(String linea, String min) => 'The $linea comes in $min';
  @override
  String pasariaEn(String linea, String min) =>
      'The $linea should come in $min (scheduled)';
  @override
  String saleSinDatos(String hora) => 'Leaves $hora · no live data';

  @override
  String get llegasteAParada => 'You’re at the stop';
  @override
  String subisteAl(String linea) => 'You’re on the $linea. Enjoy the ride!';
  @override
  String tebajasteDel(String linea) => 'You got off the $linea';
  @override
  String pasoNdeM(int n, int m) => 'Step $n of $m';
  @override
  String llegas(String hora) => 'Arrive $hora';
  @override
  String parada(String nombre) => 'Stop $nombre';
  @override
  String get caminaAlDestino => 'Walk to your destination';
  @override
  String get caminaALaParada => 'Walk to the stop';
  @override
  String caminando(String tiempo) => '$tiempo walking';
  @override
  String despuesEspera(String linea) => 'Then: wait for the $linea';
  @override
  String pasaApurate(String min) => 'Comes in $min: hurry up a little';
  @override
  String pasaEnCorto(String min, {required bool enVivo}) =>
      'Comes in $min${enVivo ? '' : ' (scheduled)'}';
  @override
  String get llegoTuBus => 'Your bus is here!';
  @override
  String get llegando => 'Arriving!';
  @override
  String llegaEn(String min) => 'Arrives in $min';
  @override
  String aDistancia(String dist) => '$dist away';
  @override
  String enAprox(String min) => 'In ~$min';
  @override
  String get segunHorario => 'per schedule';
  @override
  String get sinDatosBus =>
      'No live data for this bus. Wait for it at the stop.';
  @override
  String espera(String linea) => 'Wait for the $linea';
  @override
  String hacia(String destino) => 'To $destino';
  @override
  String get hacelSeniaSubi => 'Wave it down and board when it stops.';
  @override
  String get enVivoMayus => 'LIVE';
  @override
  String get horarioMayus => 'SCHEDULED';
  @override
  String get hacelSenia => 'Wave when you see it coming';
  @override
  String get puedeVariar => 'May vary by a few minutes';
  @override
  String busADistancia(String dist) => 'The bus is $dist from your stop';
  @override
  String get bajateEnLaProxima => 'Get off at the next stop!';
  @override
  String viajaEn(String linea) => 'Ride the $linea';
  @override
  String bajateEn(String parada) => 'Get off at $parada';
  @override
  String get tocaElTimbre => 'Ring the bell to get off';
  @override
  String faltan(String paradas) => '$paradas to go';
  @override
  String get proximaMayus => 'NEXT';
  @override
  String faltanParaBajarte(String paradas) => '$paradas until you get off';
  @override
  String get yaLlegue => 'I’m here';
  @override
  String get yaEstoyEnLaParada => 'I’m at the stop';
  @override
  String get yaSubi => 'I’m on the bus';
  @override
  String get yaMeBaje => 'I got off';
  @override
  String get terminarViaje => 'End trip';
  @override
  String get verTodoElViaje => 'See the whole trip';
  @override
  String get terminarPregunta => 'End the trip?';
  @override
  String get terminarTexto =>
      'We’ll stop guiding you. You can look for another trip any time.';
  @override
  String get seguir => 'Keep going';
  @override
  String get terminar => 'End';
  @override
  String get llegaste => 'You made it!';
  @override
  String get listo => 'Done';

  @override
  String get tuViaje => 'Your trip';
  @override
  String aDestinoLlegas(String destino, String hora) =>
      'To $destino · arrive $hora';
  @override
  String camina(String dist) => 'Walk $dist';
  @override
  String hastaDestino(String destino) => 'To $destino';
  @override
  String hastaLaParada(String parada) => 'To the stop $parada';
  @override
  String bajateEnResumen(String parada, String paradas, String tiempo) =>
      'Get off at $parada · $paradas · $tiempo';
  @override
  String get ahoraMayus => 'NOW';

  @override
  String get tuParada => 'Your stop';
  @override
  String get teBajas => 'You get off';
  @override
  String get proximaParadaMayus => 'NEXT STOP';
  @override
  String subisAl(String linea) => 'Board the $linea';
  @override
  String cambiasAl(String linea) => 'Change to the $linea';
  @override
  String get bajateEnEsta => 'Get off here!';
  @override
  String get teBajasAca => 'You get off here';
  @override
  String get tocaElTimbreMayus => 'RING THE BELL';
  @override
  String enParadas(String paradas) => 'in $paradas';
  @override
  String get tuDestinoMayus => 'YOUR DESTINATION';
  @override
  String get llegandoMinus => 'arriving';

  @override
  String get webLema => 'Your bus trip across Montevideo, step by step.';
  @override
  String get webDemo =>
      'This is a demo: the trips are real, planned with the city’s bus '
      'schedules and routes, and recorded. You and the buses move on their '
      'own, with time sped up.';
  @override
  String get webDescargar => 'Download for Android';
  @override
  String get webCodigo => 'Source code';
  @override
  String get avisoApp => 'BondiUY for Android';
  @override
  String get avisoAppDetalle => 'The same demo, installed on your phone.';
  @override
  String get avisoAppDescargar => 'Download';
  @override
  String get avisoAppCerrar => 'Close';

  @override
  String get probaUnViaje => 'Try a trip';
  @override
  String get demoExplicacion =>
      'Real bus trips across Montevideo, recorded. You and the buses move on their own.';
}
