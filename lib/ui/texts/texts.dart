// UI texts in Spanish (Rioplatense, voseo) and English.
//
// The logic never sends text, only data. Everything that is read lives here.
// The language is chosen at the root of the app (`fijarIdioma`) and read with `tx`.

import '../../contract/traces.dart';

enum Language { es, en }

Texts _current = const SpanishTexts();

/// The texts for the current language.
Texts get tx => _current;

void pinLanguage(Language i) =>
    _current = i == Language.en ? const EnglishTexts() : const SpanishTexts();

const _nb = ' ';

abstract class Texts {
  const Texts();
  Language get language;

  // --- formats -------------------------------------------------------------
  String get underOneMin;
  String get now;
  String stops(int n);

  // --- notices ---------------------------------------------------------------
  String get noticeWithoutLocation;
  String get noticeWithoutConnection;
  String get noticeErrorPlanning;
  String get noticeErrorSuggestions;
  String get noticeErrorStop;
  String get noticeMissingDestination;
  String get noticeGetOff;
  String get noticeBusArriving;

  // --- common --------------------------------------------------------------
  String get recenterMap;
  String get seeTheBus;
  String get seeMe;
  String get chooseAPlace;
  String get myLocation;
  String get yourDestination;
  String line(String l);
  String get close;
  String get back;
  String from(String origin);

  // --- home ---------------------------------------------------------------
  String get whereAreYouGoing;
  String get seeTrips;
  String themeLabel(String name);
  String get themeAutomatic;
  String get themeLight;
  String get themeDark;
  String get themeNoticeAutomatic;
  String get themeNoticeLight;
  String get themeNoticeDark;
  String get locationOff;
  String get locationWithoutPermission;
  String get locationNotFound;
  String get activate;
  String stopNumber(String id);
  String get stopErrorArrivals;
  String get stopWithoutInfo;
  String stopWithoutNext(String lines);
  String get live;
  String get schedule;
  String get languageLabel;

  // --- search -------------------------------------------------------------
  String get fromField;
  String get swap;
  String get clear;
  String get placeNotFound;
  String get errorSearchPlaces;
  String get helpSearch;

  // --- options -------------------------------------------------------------
  String get errorPlanTitle;
  String get errorPlanText;
  String get withoutTripsTitle;
  String get withoutTripsText;
  String get searchingTrip;
  String get retry;
  String get changeDestination;
  String get startTrip;
  String optionNofM(int n, int m);
  String get previousOption;
  String get nextOption;
  String boardIn(String stop);
  String walk(String dist);
  String transfers(int n);
  String get recommended;
  String barLegs(List<String> lines);
  String get allOnFoot;
  String passesMaybeNotArrive(String line, String min);
  String passesIn(String line, String min);
  String wouldPassIn(String line, String min);
  String exitsWithoutData(String time);

  // --- trip ----------------------------------------------------------------
  String get arrivedToStop;
  String boardedOn(String line);
  String gotOffLine(String line);
  String stepNofM(int n, int m);
  String arrive(String time);
  String stop(String name);
  String get walksOnDestination;
  String get walksToTheStop;
  String walking(String time);
  String afterWait(String line);
  String passesQuickly(String min);
  String passesInShort(String min, {required bool live});
  String get arrivedYourBus;
  String get arriving;
  String arrivesIn(String min);
  String toDistance(String dist);
  String inApprox(String min);
  String get perSchedule;
  String get withoutDataBus;
  String wait(String line);
  String toward(String destination);
  String get waveAndBoard;
  String get liveUpper;
  String get scheduleUpper;
  String get makeSign;
  String get canVary;
  String busToDistance(String dist);
  String get getOffAtNext;
  String travelsIn(String line);
  String getOffAt(String stop);
  String get ringsTheBell;
  String missing(String stops);
  String get nextUpper;
  String missingToGetOff(String stops);
  String get alreadyArrived;
  String get alreadyAtTheStop;
  String get alreadyBoarded;
  String get alreadyGotOff;
  String get finishTrip;
  String get seeWholeTrip;
  String get finishQuestion;
  String get finishText;
  String get follow;
  String get finish;
  String get arrived;
  String get ready;

  // --- itinerary -----------------------------------------------------------
  String get yourTrip;
  String toDestinationArrive(String destination, String time);
  String walks(String dist);
  String untilDestination(String destination);
  String untilTheStop(String stop);
  String getOffSummary(String stop, String stops, String time);
  String get nowUpper;

  // --- map -----------------------------------------------------------------
  String get yourStop;
  String get youGetOff;
  String get nextStopUpper;
  String boardOn(String line);
  String changeAt(String line);
  String get getOffHere;
  String get youGetOffHere;
  String get ringsTheBellUpper;
  String inStops(String stops);
  String get yourDestinationUpper;
  String get arrivingLower;

  // --- web ------------------------------------------------------------------
  String get webMotto;
  String get webDemo;
  String get webDownload;
  String get webCode;
  String get webThemeToLight;
  String get webThemeToDark;
  String get coreTitle;
  String get coreLayerUi;
  String get coreLayerLogic;
  String get coreLede;
  String get coreNoteDemo;
  String get coreConsole;
  String get coreConsoleMaximize;
  String get coreConsoleRestore;
  String get coreKeyActions;
  String get coreKeyStatus;
  String get coreKeyLocation;
  String get coreKeyBuses;
  String get coreKeyPlan;
  String get coreController;
  String get coreNavigator;
  String get coreTracker;
  String get coreRecommender;
  String coreDetail(Piece p);
  String get coreSeeCode;
  String get noticeApp;
  String get noticeAppDetail;
  String get noticeAppDownload;
  String get noticeAppClose;

  // --- demo -----------------------------------------------------------------
  String get triesOneTrip;
  String get demoExplanation;
}

class SpanishTexts extends Texts {
  const SpanishTexts();
  @override
  Language get language => Language.es;

  @override
  String get underOneMin => 'menos de 1${_nb}min';
  @override
  String get now => 'ya';
  @override
  String stops(int n) => n == 1 ? '1${_nb}parada' : '$n${_nb}paradas';

  @override
  String get noticeWithoutLocation =>
      'No sabemos dónde estás. Activá la ubicación o elegí un punto de partida.';
  @override
  String get noticeWithoutConnection =>
      'Sin conexión. Revisá tus datos o el wifi.';
  @override
  String get noticeErrorPlanning =>
      'No pudimos calcular el viaje. Probá de nuevo en un momento.';
  @override
  String get noticeErrorSuggestions =>
      'No pudimos buscar lugares. Revisá tu conexión.';
  @override
  String get noticeErrorStop =>
      'No pudimos ver los próximos buses de esa parada.';
  @override
  String get noticeMissingDestination => 'Elegí a dónde querés ir.';
  @override
  String get noticeGetOff => '¡Bajate en la próxima parada!';
  @override
  String get noticeBusArriving =>
      '¡Tu bus está llegando! Preparate para subir.';

  @override
  String get recenterMap => 'Volver a centrar el mapa';
  @override
  String get seeTheBus => 'Ver el bus';
  @override
  String get seeMe => 'Verme a mí';
  @override
  String get chooseAPlace => 'Elegí un lugar';
  @override
  String get myLocation => 'Mi ubicación';
  @override
  String get yourDestination => 'Tu destino';
  @override
  String line(String l) => 'Línea $l';
  @override
  String get close => 'Cerrar';
  @override
  String get back => 'Volver';
  @override
  String from(String origin) => 'Desde $origin';

  @override
  String get whereAreYouGoing => '¿A dónde vas?';
  @override
  String get seeTrips => 'Ver viajes';
  @override
  String themeLabel(String name) => 'Tema $name. Tocá para cambiar';
  @override
  String get themeAutomatic => 'automático';
  @override
  String get themeLight => 'claro';
  @override
  String get themeDark => 'oscuro';
  @override
  String get themeNoticeAutomatic => 'Tema automático (como tu teléfono)';
  @override
  String get themeNoticeLight => 'Tema claro';
  @override
  String get themeNoticeDark => 'Tema oscuro';
  @override
  String get locationOff =>
      'Tu ubicación está apagada. Activala para saber dónde estás.';
  @override
  String get locationWithoutPermission =>
      'BondiUY necesita tu ubicación para guiarte en el viaje.';
  @override
  String get locationNotFound => 'No pudimos encontrar tu ubicación.';
  @override
  String get activate => 'Activar';
  @override
  String stopNumber(String id) => 'Parada $id';
  @override
  String get stopErrorArrivals =>
      'No pudimos ver los próximos buses. Probá de nuevo en un rato.';
  @override
  String get stopWithoutInfo => 'No hay información de buses para esta parada.';
  @override
  String stopWithoutNext(String lines) =>
      'No hay buses próximos informados.\nPasan: $lines';
  @override
  String get live => 'en vivo';
  @override
  String get schedule => 'horario';
  @override
  String get languageLabel => 'Idioma: español. Tocá para cambiar a inglés';

  @override
  String get fromField => 'Desde';
  @override
  String get swap => 'Intercambiar origen y destino';
  @override
  String get clear => 'Borrar';
  @override
  String get placeNotFound =>
      'No encontramos ese lugar en Montevideo. Probá con una calle y número, o un lugar conocido.';
  @override
  String get errorSearchPlaces =>
      'No pudimos buscar lugares. Revisá tu conexión e intentá de nuevo.';
  @override
  String get helpSearch =>
      'Escribí una dirección, una esquina o un lugar.\nPor ejemplo: "18 de Julio y Ejido".';

  @override
  String get errorPlanTitle => 'No pudimos calcular el viaje';
  @override
  String get errorPlanText => 'Revisá tu conexión y probá de nuevo.';
  @override
  String get withoutTripsTitle => 'No encontramos viajes en bus';
  @override
  String get withoutTripsText => 'Probá con otro destino o más tarde.';
  @override
  String get searchingTrip => 'Buscando el mejor viaje…';
  @override
  String get retry => 'Reintentar';
  @override
  String get changeDestination => 'Cambiar destino';
  @override
  String get startTrip => 'Empezar viaje';
  @override
  String optionNofM(int n, int m) => 'Opción $n de $m';
  @override
  String get previousOption => 'Opción anterior';
  @override
  String get nextOption => 'Opción siguiente';
  @override
  String boardIn(String stop) => 'Subís en $stop';
  @override
  String walk(String dist) => 'caminás $dist';
  @override
  String transfers(int n) => n == 1 ? '1 trasbordo' : '$n trasbordos';
  @override
  String get recommended => 'Recomendado';
  @override
  String barLegs(List<String> lines) =>
      'Caminás, tomás ${lines.length == 1 ? 'el' : 'los'} ${lines.join(', ')} y caminás hasta el destino';
  @override
  String get allOnFoot => 'Todo el viaje a pie';
  @override
  String passesMaybeNotArrive(String line, String min) =>
      'El $line pasa en $min: quizás no llegues';
  @override
  String passesIn(String line, String min) => 'El $line pasa en $min';
  @override
  String wouldPassIn(String line, String min) =>
      'El $line pasaría en $min (horario)';
  @override
  String exitsWithoutData(String time) => 'Sale $time · sin datos en vivo';

  @override
  String get arrivedToStop => 'Llegaste a la parada';
  @override
  String boardedOn(String line) => 'Subiste al $line. ¡Buen viaje!';
  @override
  String gotOffLine(String line) => 'Te bajaste del $line';
  @override
  String stepNofM(int n, int m) => 'Paso $n de $m';
  @override
  String arrive(String time) => 'Llegás $time';
  @override
  String stop(String name) => 'Parada $name';
  @override
  String get walksOnDestination => 'Caminá hasta tu destino';
  @override
  String get walksToTheStop => 'Caminá hasta la parada';
  @override
  String walking(String time) => '$time caminando';
  @override
  String afterWait(String line) => 'Después: esperá el $line';
  @override
  String passesQuickly(String min) => 'Pasa en $min: apurate un poco';
  @override
  String passesInShort(String min, {required bool live}) =>
      'Pasa en $min${live ? '' : ' (horario)'}';
  @override
  String get arrivedYourBus => '¡Llegó tu bus!';
  @override
  String get arriving => '¡Llegando!';
  @override
  String arrivesIn(String min) => 'Llega en $min';
  @override
  String toDistance(String dist) => 'a $dist';
  @override
  String inApprox(String min) => 'En ~$min';
  @override
  String get perSchedule => 'según horario';
  @override
  String get withoutDataBus =>
      'Sin datos en vivo de este bus. Esperalo en la parada.';
  @override
  String wait(String line) => 'Esperá el $line';
  @override
  String toward(String destination) => 'Hacia $destination';
  @override
  String get waveAndBoard => 'Hacele seña y subí cuando pare.';
  @override
  String get liveUpper => 'EN VIVO';
  @override
  String get scheduleUpper => 'HORARIO';
  @override
  String get makeSign => 'Hacele seña cuando lo veas venir';
  @override
  String get canVary => 'Puede variar unos minutos';
  @override
  String busToDistance(String dist) => 'El bus está a $dist de tu parada';
  @override
  String get getOffAtNext => '¡Bajate en la próxima!';
  @override
  String travelsIn(String line) => 'Viajá en el $line';
  @override
  String getOffAt(String stop) => 'Bajate en $stop';
  @override
  String get ringsTheBell => 'Tocá el timbre para bajar';
  @override
  String missing(String stops) => 'Faltan $stops';
  @override
  String get nextUpper => 'PRÓXIMA';
  @override
  String missingToGetOff(String stops) => 'Faltan $stops para bajarte';
  @override
  String get alreadyArrived => 'Ya llegué';
  @override
  String get alreadyAtTheStop => 'Ya estoy en la parada';
  @override
  String get alreadyBoarded => 'Ya subí al bus';
  @override
  String get alreadyGotOff => 'Ya me bajé';
  @override
  String get finishTrip => 'Terminar viaje';
  @override
  String get seeWholeTrip => 'Ver todo el viaje';
  @override
  String get finishQuestion => '¿Terminar el viaje?';
  @override
  String get finishText =>
      'Dejamos de guiarte. Podés buscar otro viaje cuando quieras.';
  @override
  String get follow => 'Seguir';
  @override
  String get finish => 'Terminar';
  @override
  String get arrived => '¡Llegaste!';
  @override
  String get ready => 'Listo';

  @override
  String get yourTrip => 'Tu viaje';
  @override
  String toDestinationArrive(String destination, String time) =>
      'A $destination · llegás $time';
  @override
  String walks(String dist) => 'Caminá $dist';
  @override
  String untilDestination(String destination) => 'Hasta $destination';
  @override
  String untilTheStop(String stop) => 'Hasta la parada $stop';
  @override
  String getOffSummary(String stop, String stops, String time) =>
      'Bajate en $stop · $stops · $time';
  @override
  String get nowUpper => 'AHORA';

  @override
  String get yourStop => 'Tu parada';
  @override
  String get youGetOff => 'Te bajás';
  @override
  String get nextStopUpper => 'PRÓXIMA PARADA';
  @override
  String boardOn(String line) => 'Subís al $line';
  @override
  String changeAt(String line) => 'Cambiás al $line';
  @override
  String get getOffHere => '¡Bajate en esta!';
  @override
  String get youGetOffHere => 'Te bajás acá';
  @override
  String get ringsTheBellUpper => 'TOCÁ EL TIMBRE';
  @override
  String inStops(String stops) => 'en $stops';
  @override
  String get yourDestinationUpper => 'TU DESTINO';
  @override
  String get arrivingLower => 'llegando';

  @override
  String get webMotto => 'Tu viaje en bondi por Montevideo, paso a paso.';
  @override
  String get webDemo =>
      'Esto es una demo: los viajes son reales, planificados con los horarios y '
      'recorridos de la Intendencia, y grabados. Vos y los buses se mueven '
      'solos, con el tiempo acelerado.';
  @override
  String get webDownload => 'Descargar para Android';
  @override
  String get webCode => 'Código fuente';
  @override
  String get webThemeToLight => 'Modo claro';
  @override
  String get webThemeToDark => 'Modo oscuro';
  @override
  String get coreTitle => 'Por dentro';
  @override
  String get coreLayerUi => 'CAPA DE UI';
  @override
  String get coreLayerLogic => 'CAPA DE LÓGICA';
  @override
  String get coreLede =>
      'Dos capas unidas por una API, la App API. La UI solo lee el estado y le '
      'pide cosas a la lógica; la lógica decide sin saber de pantallas y habla '
      'con el mundo por puertos. Cada pulso es una llamada que la app está '
      'haciendo ahora.';
  @override
  String get coreNoteDemo =>
      'En la demo, los puertos responden con viajes grabados y un mundo '
      'simulado; en el teléfono, con OpenTripPlanner, la API de la '
      'Intendencia y el GPS.';
  @override
  String get coreConsole => 'Llamadas en vivo';
  @override
  String get coreConsoleMaximize => 'Maximizar';
  @override
  String get coreConsoleRestore => 'Restaurar';
  @override
  String get coreKeyActions => 'Acciones';
  @override
  String get coreKeyStatus => 'Estado';
  @override
  String get coreKeyLocation => 'Ubicación';
  @override
  String get coreKeyBuses => 'Buses';
  @override
  String get coreKeyPlan => 'Planificación';
  @override
  String get coreController => 'decide y publica el estado';
  @override
  String get coreNavigator => 'en qué paso vas, con cada lectura';
  @override
  String get coreTracker => 'qué bus viene y por dónde';
  @override
  String get coreRecommender => 'ordena y elige la opción';
  @override
  String coreDetail(Piece p) => switch (p) {
    Piece.interfaceValue =>
      'La frontera entre la UI y la lógica: la UI llama acciones y lee el '
          'estado, y nada más.',
    Piece.controller =>
      'Implementa las acciones, coordina las piezas del núcleo y los puertos, '
          'y publica un AppState nuevo con cada cambio.',
    Piece.navigator =>
      'Con cada lectura del GPS decide en qué paso del viaje estás y cuánto '
          'falta.',
    Piece.tracker =>
      'Entre los buses que llegan a la parada elige el tuyo y lo sigue hasta '
          'que subís.',
    Piece.recommender => 'Ordena los itinerarios y marca el recomendado.',
    Piece.location =>
      'Puerto de ubicación: en el teléfono, el GPS; en la demo, un usuario '
          'simulado.',
    Piece.arrivals =>
      'Puerto de llegadas: la API de transporte de la Intendencia de '
          'Montevideo; en la demo, buses simulados con horario.',
    Piece.planner =>
      'Puerto de planificación: OpenTripPlanner arma los itinerarios; en la '
          'demo, viajes grabados.',
    Piece.catalog =>
      'Puerto de la red: las paradas y los recorridos GTFS que vienen con la '
          'app.',
    Piece.places => 'Puerto de búsqueda: sugiere lugares mientras escribís.',
  };
  @override
  String get coreSeeCode => 'Clic para ver el código';
  @override
  String get noticeApp => 'BondiUY para Android';
  @override
  String get noticeAppDetail => 'La misma demo, instalada en tu teléfono.';
  @override
  String get noticeAppDownload => 'Descargar';
  @override
  String get noticeAppClose => 'Cerrar';

  @override
  String get triesOneTrip => 'Probá un viaje';
  @override
  String get demoExplanation =>
      'Viajes reales en bus por Montevideo, grabados. Vos y los buses se mueven solos.';
}

class EnglishTexts extends Texts {
  const EnglishTexts();
  @override
  Language get language => Language.en;

  @override
  String get underOneMin => 'under 1${_nb}min';
  @override
  String get now => 'now';
  @override
  String stops(int n) => n == 1 ? '1${_nb}stop' : '$n${_nb}stops';

  @override
  String get noticeWithoutLocation =>
      'We don’t know where you are. Turn on location or pick a starting point.';
  @override
  String get noticeWithoutConnection =>
      'No connection. Check your data or wifi.';
  @override
  String get noticeErrorPlanning =>
      'We couldn’t plan the trip. Try again in a moment.';
  @override
  String get noticeErrorSuggestions =>
      'We couldn’t search places. Check your connection.';
  @override
  String get noticeErrorStop => 'We couldn’t get the next buses for that stop.';
  @override
  String get noticeMissingDestination => 'Choose where you want to go.';
  @override
  String get noticeGetOff => 'Get off at the next stop!';
  @override
  String get noticeBusArriving => 'Your bus is coming! Get ready to board.';

  @override
  String get recenterMap => 'Recenter the map';
  @override
  String get seeTheBus => 'Show the bus';
  @override
  String get seeMe => 'Show me';
  @override
  String get chooseAPlace => 'Choose a place';
  @override
  String get myLocation => 'My location';
  @override
  String get yourDestination => 'Your destination';
  @override
  String line(String l) => 'Line $l';
  @override
  String get close => 'Close';
  @override
  String get back => 'Back';
  @override
  String from(String origin) => 'From $origin';

  @override
  String get whereAreYouGoing => 'Where to?';
  @override
  String get seeTrips => 'See trips';
  @override
  String themeLabel(String name) => '$name theme. Tap to change';
  @override
  String get themeAutomatic => 'Automatic';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeNoticeAutomatic => 'Automatic theme (follows your phone)';
  @override
  String get themeNoticeLight => 'Light theme';
  @override
  String get themeNoticeDark => 'Dark theme';
  @override
  String get locationOff =>
      'Your location is off. Turn it on so we know where you are.';
  @override
  String get locationWithoutPermission =>
      'BondiUY needs your location to guide you on the trip.';
  @override
  String get locationNotFound => 'We couldn’t find your location.';
  @override
  String get activate => 'Turn on';
  @override
  String stopNumber(String id) => 'Stop $id';
  @override
  String get stopErrorArrivals =>
      'We couldn’t get the next buses. Try again in a while.';
  @override
  String get stopWithoutInfo => 'No bus information for this stop.';
  @override
  String stopWithoutNext(String lines) =>
      'No upcoming buses reported.\nLines: $lines';
  @override
  String get live => 'live';
  @override
  String get schedule => 'scheduled';
  @override
  String get languageLabel => 'Language: English. Tap to switch to Spanish';

  @override
  String get fromField => 'From';
  @override
  String get swap => 'Swap origin and destination';
  @override
  String get clear => 'Clear';
  @override
  String get placeNotFound =>
      'We couldn’t find that place in Montevideo. Try a street and number, or a well-known place.';
  @override
  String get errorSearchPlaces =>
      'We couldn’t search places. Check your connection and try again.';
  @override
  String get helpSearch =>
      'Type an address, a corner or a place.\nFor example: "18 de Julio y Ejido".';

  @override
  String get errorPlanTitle => 'We couldn’t plan the trip';
  @override
  String get errorPlanText => 'Check your connection and try again.';
  @override
  String get withoutTripsTitle => 'No bus trips found';
  @override
  String get withoutTripsText => 'Try another destination or later.';
  @override
  String get searchingTrip => 'Finding the best trip…';
  @override
  String get retry => 'Try again';
  @override
  String get changeDestination => 'Change destination';
  @override
  String get startTrip => 'Start trip';
  @override
  String optionNofM(int n, int m) => 'Option $n of $m';
  @override
  String get previousOption => 'Previous option';
  @override
  String get nextOption => 'Next option';
  @override
  String boardIn(String stop) => 'Board at $stop';
  @override
  String walk(String dist) => 'walk $dist';
  @override
  String transfers(int n) => n == 1 ? '1 transfer' : '$n transfers';
  @override
  String get recommended => 'Recommended';
  @override
  String barLegs(List<String> lines) =>
      'Walk, take ${lines.join(', ')} and walk to your destination';
  @override
  String get allOnFoot => 'Walk the whole way';
  @override
  String passesMaybeNotArrive(String line, String min) =>
      'The $line comes in $min: you may not make it';
  @override
  String passesIn(String line, String min) => 'The $line comes in $min';
  @override
  String wouldPassIn(String line, String min) =>
      'The $line should come in $min (scheduled)';
  @override
  String exitsWithoutData(String time) => 'Leaves $time · no live data';

  @override
  String get arrivedToStop => 'You’re at the stop';
  @override
  String boardedOn(String line) => 'You’re on the $line. Enjoy the ride!';
  @override
  String gotOffLine(String line) => 'You got off the $line';
  @override
  String stepNofM(int n, int m) => 'Step $n of $m';
  @override
  String arrive(String time) => 'Arrive $time';
  @override
  String stop(String name) => 'Stop $name';
  @override
  String get walksOnDestination => 'Walk to your destination';
  @override
  String get walksToTheStop => 'Walk to the stop';
  @override
  String walking(String time) => '$time walking';
  @override
  String afterWait(String line) => 'Then: wait for the $line';
  @override
  String passesQuickly(String min) => 'Comes in $min: hurry up a little';
  @override
  String passesInShort(String min, {required bool live}) =>
      'Comes in $min${live ? '' : ' (scheduled)'}';
  @override
  String get arrivedYourBus => 'Your bus is here!';
  @override
  String get arriving => 'Arriving!';
  @override
  String arrivesIn(String min) => 'Arrives in $min';
  @override
  String toDistance(String dist) => '$dist away';
  @override
  String inApprox(String min) => 'In ~$min';
  @override
  String get perSchedule => 'per schedule';
  @override
  String get withoutDataBus =>
      'No live data for this bus. Wait for it at the stop.';
  @override
  String wait(String line) => 'Wait for the $line';
  @override
  String toward(String destination) => 'To $destination';
  @override
  String get waveAndBoard => 'Wave it down and board when it stops.';
  @override
  String get liveUpper => 'LIVE';
  @override
  String get scheduleUpper => 'SCHEDULED';
  @override
  String get makeSign => 'Wave when you see it coming';
  @override
  String get canVary => 'May vary by a few minutes';
  @override
  String busToDistance(String dist) => 'The bus is $dist from your stop';
  @override
  String get getOffAtNext => 'Get off at the next stop!';
  @override
  String travelsIn(String line) => 'Ride the $line';
  @override
  String getOffAt(String stop) => 'Get off at $stop';
  @override
  String get ringsTheBell => 'Ring the bell to get off';
  @override
  String missing(String stops) => '$stops to go';
  @override
  String get nextUpper => 'NEXT';
  @override
  String missingToGetOff(String stops) => '$stops until you get off';
  @override
  String get alreadyArrived => 'I’m here';
  @override
  String get alreadyAtTheStop => 'I’m at the stop';
  @override
  String get alreadyBoarded => 'I’m on the bus';
  @override
  String get alreadyGotOff => 'I got off';
  @override
  String get finishTrip => 'End trip';
  @override
  String get seeWholeTrip => 'See the whole trip';
  @override
  String get finishQuestion => 'End the trip?';
  @override
  String get finishText =>
      'We’ll stop guiding you. You can look for another trip any time.';
  @override
  String get follow => 'Keep going';
  @override
  String get finish => 'End';
  @override
  String get arrived => 'You made it!';
  @override
  String get ready => 'Done';

  @override
  String get yourTrip => 'Your trip';
  @override
  String toDestinationArrive(String destination, String time) =>
      'To $destination · arrive $time';
  @override
  String walks(String dist) => 'Walk $dist';
  @override
  String untilDestination(String destination) => 'To $destination';
  @override
  String untilTheStop(String stop) => 'To the stop $stop';
  @override
  String getOffSummary(String stop, String stops, String time) =>
      'Get off at $stop · $stops · $time';
  @override
  String get nowUpper => 'NOW';

  @override
  String get yourStop => 'Your stop';
  @override
  String get youGetOff => 'You get off';
  @override
  String get nextStopUpper => 'NEXT STOP';
  @override
  String boardOn(String line) => 'Board the $line';
  @override
  String changeAt(String line) => 'Change to the $line';
  @override
  String get getOffHere => 'Get off here!';
  @override
  String get youGetOffHere => 'You get off here';
  @override
  String get ringsTheBellUpper => 'RING THE BELL';
  @override
  String inStops(String stops) => 'in $stops';
  @override
  String get yourDestinationUpper => 'YOUR DESTINATION';
  @override
  String get arrivingLower => 'arriving';

  @override
  String get webMotto => 'Your bus trip across Montevideo, step by step.';
  @override
  String get webDemo =>
      'This is a demo: the trips are real, planned with the city’s bus '
      'schedules and routes, and recorded. You and the buses move on their '
      'own, with time sped up.';
  @override
  String get webDownload => 'Download for Android';
  @override
  String get webCode => 'Source code';
  @override
  String get webThemeToLight => 'Light mode';
  @override
  String get webThemeToDark => 'Dark mode';
  @override
  String get coreTitle => 'Inside';
  @override
  String get coreLayerUi => 'UI LAYER';
  @override
  String get coreLayerLogic => 'LOGIC LAYER';
  @override
  String get coreLede =>
      'Two layers joined by an API, the App API. The UI only reads the state and '
      'asks the logic for things; the logic decides without knowing about '
      'screens and talks to the world through ports. Each pulse is a call the '
      'app is making right now.';
  @override
  String get coreNoteDemo =>
      'In the demo, the ports answer with recorded trips and a simulated '
      'world; on the phone, with OpenTripPlanner, the city’s API and the GPS.';
  @override
  String get coreConsole => 'Live calls';
  @override
  String get coreConsoleMaximize => 'Maximize';
  @override
  String get coreConsoleRestore => 'Restore';
  @override
  String get coreKeyActions => 'Actions';
  @override
  String get coreKeyStatus => 'State';
  @override
  String get coreKeyLocation => 'Location';
  @override
  String get coreKeyBuses => 'Buses';
  @override
  String get coreKeyPlan => 'Planning';
  @override
  String get coreController => 'decides and publishes the state';
  @override
  String get coreNavigator => 'which step you are on, per reading';
  @override
  String get coreTracker => 'which bus is coming, and where';
  @override
  String get coreRecommender => 'sorts and picks the option';
  @override
  String coreDetail(Piece p) => switch (p) {
    Piece.interfaceValue =>
      'The boundary between the UI and the logic: the UI calls actions and '
          'reads the state, and nothing else.',
    Piece.controller =>
      'Implements the actions, coordinates the core pieces and the ports, and '
          'publishes a new AppState on every change.',
    Piece.navigator =>
      'With every GPS reading, works out which step of the trip you are on '
          'and how far is left.',
    Piece.tracker =>
      'Picks your bus among the ones arriving at the stop and follows it '
          'until you board.',
    Piece.recommender => 'Sorts the itineraries and marks the recommended one.',
    Piece.location =>
      'Location port: the GPS on the phone; a simulated user in the demo.',
    Piece.arrivals =>
      'Arrivals port: the Montevideo city transit API; scheduled simulated '
          'buses in the demo.',
    Piece.planner =>
      'Planning port: OpenTripPlanner builds the itineraries; recorded trips '
          'in the demo.',
    Piece.catalog =>
      'Network port: the GTFS stops and route shapes bundled with the app.',
    Piece.places => 'Search port: suggests places as you type.',
  };
  @override
  String get coreSeeCode => 'Click to see the code';
  @override
  String get noticeApp => 'BondiUY for Android';
  @override
  String get noticeAppDetail => 'The same demo, installed on your phone.';
  @override
  String get noticeAppDownload => 'Download';
  @override
  String get noticeAppClose => 'Close';

  @override
  String get triesOneTrip => 'Try a trip';
  @override
  String get demoExplanation =>
      'Real bus trips across Montevideo, recorded. You and the buses move on their own.';
}
