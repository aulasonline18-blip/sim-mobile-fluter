import '../school/sim_school_routes.dart';

enum SimOrganismRouteGuard {
  open,
  needsAuth,
  needsLanguage,
  needsObjective,
  serverOnly,
  external,
  unknown,
}

class SimRouteDecision {
  const SimRouteDecision({
    required this.requested,
    required this.destination,
    required this.guard,
  });

  final String requested;
  final String destination;
  final SimOrganismRouteGuard guard;

  bool get allowed => requested == destination && guard == SimOrganismRouteGuard.open;
}

class SimOrganismRouter {
  const SimOrganismRouter();

  SimRouteDecision resolve({
    required String path,
    required bool authed,
    required bool hasLanguage,
    required bool hasObjective,
  }) {
    final route = findSimRoute(path);
    if (route == null) {
      return SimRouteDecision(
        requested: path,
        destination: '/',
        guard: SimOrganismRouteGuard.unknown,
      );
    }
    if (route.serverOnly) {
      return SimRouteDecision(
        requested: path,
        destination: '/',
        guard: SimOrganismRouteGuard.serverOnly,
      );
    }
    if (route.kind == SimRouteKind.external) {
      return SimRouteDecision(
        requested: path,
        destination: path,
        guard: SimOrganismRouteGuard.external,
      );
    }
    if (_requiresAuth(path) && !authed) {
      return SimRouteDecision(
        requested: path,
        destination: '/login',
        guard: SimOrganismRouteGuard.needsAuth,
      );
    }
    if (_requiresLanguage(path) && !hasLanguage) {
      return SimRouteDecision(
        requested: path,
        destination: '/cyber/idioma',
        guard: SimOrganismRouteGuard.needsLanguage,
      );
    }
    if (_requiresObjective(path) && !hasObjective) {
      return SimRouteDecision(
        requested: path,
        destination: '/cyber/objeto',
        guard: SimOrganismRouteGuard.needsObjective,
      );
    }
    return SimRouteDecision(
      requested: path,
      destination: path,
      guard: SimOrganismRouteGuard.open,
    );
  }

  bool _requiresAuth(String path) {
    return switch (path) {
      '/cyber/idioma' ||
      '/cyber/objeto' ||
      '/cyber/curriculo' ||
      '/cyber/placement' ||
      '/cyber/aula' ||
      '/creditos' ||
      '/checkout/return' ||
      '/pai' ||
      '/conta/deletar' =>
        true,
      _ => false,
    };
  }

  bool _requiresLanguage(String path) {
    return switch (path) {
      '/cyber/objeto' ||
      '/cyber/curriculo' ||
      '/cyber/placement' ||
      '/cyber/aula' =>
        true,
      _ => false,
    };
  }

  bool _requiresObjective(String path) {
    return switch (path) {
      '/cyber/curriculo' || '/cyber/placement' || '/cyber/aula' => true,
      _ => false,
    };
  }
}
