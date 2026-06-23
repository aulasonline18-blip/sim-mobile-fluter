import '../school/aula_drawer_contract.dart';
import '../school/sim_school_completeness.dart';
import '../school/sim_school_routes.dart';

class SimOrganismHealthReport {
  const SimOrganismHealthReport({
    required this.healthyOrgans,
    required this.serverOnlyOrgans,
    required this.unresolvedDoors,
    required this.promptsStayOnServer,
    required this.secretsStayOnServer,
    required this.hasCompleteSchoolMap,
  });

  final List<String> healthyOrgans;
  final List<String> serverOnlyOrgans;
  final List<String> unresolvedDoors;
  final bool promptsStayOnServer;
  final bool secretsStayOnServer;
  final bool hasCompleteSchoolMap;

  bool get alive =>
      healthyOrgans.isNotEmpty &&
      unresolvedDoors.isEmpty &&
      promptsStayOnServer &&
      secretsStayOnServer &&
      hasCompleteSchoolMap;
}

SimOrganismHealthReport buildSimOrganismHealthReport() {
  final school = buildSimSchoolCompletenessReport();
  return SimOrganismHealthReport(
    healthyOrgans: const [
      'portal',
      'login',
      'idioma',
      'objetivo',
      'preparo_t00_contract',
      'primeira_aula_t02_contract',
      'janela_pronta',
      'nivelamento',
      'sala_de_aula',
      'duvida',
      'revisao',
      'recuperacao',
      'midia',
      'nuvem_sync',
      'creditos_pagamento',
      'pai',
      'apoio',
      'drawer_historico',
    ],
    serverOnlyOrgans: school.serverOnlyRoutes,
    unresolvedDoors: school.unresolvedInternalDestinations,
    promptsStayOnServer: school.serverOnlyRoutes.contains('/api/bootstrap-t00'),
    secretsStayOnServer: school.serverOnlyRoutes.contains('/api/public/payments/webhook'),
    hasCompleteSchoolMap: school.complete &&
        simLiveRoutes.isNotEmpty &&
        aulaDrawerActions.isNotEmpty,
  );
}
