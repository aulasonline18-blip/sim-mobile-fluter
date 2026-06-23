import 'sim_school_environment.dart';
import 'sim_school_routes.dart';

class SimSchoolCompletenessReport {
  const SimSchoolCompletenessReport({
    required this.environmentCount,
    required this.doorCount,
    required this.screenRouteCount,
    required this.apiRouteCount,
    required this.externalRouteCount,
    required this.unresolvedInternalDestinations,
    required this.serverOnlyRoutes,
  });

  final int environmentCount;
  final int doorCount;
  final int screenRouteCount;
  final int apiRouteCount;
  final int externalRouteCount;
  final List<String> unresolvedInternalDestinations;
  final List<String> serverOnlyRoutes;

  bool get complete => unresolvedInternalDestinations.isEmpty;
}

SimSchoolCompletenessReport buildSimSchoolCompletenessReport() {
  return SimSchoolCompletenessReport(
    environmentCount: simSchoolEnvironments.length,
    doorCount: allSimSchoolDoors().length,
    screenRouteCount: simLiveRoutes.where((route) => route.kind == SimRouteKind.screen).length,
    apiRouteCount: simLiveRoutes.where((route) => route.kind == SimRouteKind.api).length,
    externalRouteCount: simLiveRoutes.where((route) => route.kind == SimRouteKind.external).length,
    unresolvedInternalDestinations: unresolvedInternalDestinations(),
    serverOnlyRoutes: simLiveRoutes
        .where((route) => route.serverOnly)
        .map((route) => route.path)
        .toList(growable: false),
  );
}
