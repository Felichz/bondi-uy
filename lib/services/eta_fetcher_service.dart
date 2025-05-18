import '../models/bus_arrival_info.dart';

abstract class ETAFetcherService {
  Future<List<BusArrivalInfo>> getUpcomingBusesForStop(String stopId);
}
