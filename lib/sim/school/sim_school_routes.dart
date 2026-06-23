enum SimRouteKind { screen, api, external }

class SimSchoolRoute {
  const SimSchoolRoute({
    required this.path,
    required this.kind,
    required this.environmentId,
    this.serverOnly = false,
  });

  final String path;
  final SimRouteKind kind;
  final String environmentId;
  final bool serverOnly;
}

const simLiveRoutes = <SimSchoolRoute>[
  SimSchoolRoute(path: '/', kind: SimRouteKind.screen, environmentId: 'portal'),
  SimSchoolRoute(path: '/login', kind: SimRouteKind.screen, environmentId: 'login'),
  SimSchoolRoute(path: '/cyber/idioma', kind: SimRouteKind.screen, environmentId: 'language'),
  SimSchoolRoute(path: '/cyber/objeto', kind: SimRouteKind.screen, environmentId: 'objective'),
  SimSchoolRoute(path: '/cyber/curriculo', kind: SimRouteKind.screen, environmentId: 'preparation'),
  SimSchoolRoute(path: '/cyber/placement', kind: SimRouteKind.screen, environmentId: 'placement'),
  SimSchoolRoute(path: '/cyber/aula', kind: SimRouteKind.screen, environmentId: 'classroom'),
  SimSchoolRoute(path: '/creditos', kind: SimRouteKind.screen, environmentId: 'credits'),
  SimSchoolRoute(path: '/checkout/return', kind: SimRouteKind.screen, environmentId: 'checkout_return'),
  SimSchoolRoute(path: '/pai', kind: SimRouteKind.screen, environmentId: 'father_panel'),
  SimSchoolRoute(path: '/privacidade', kind: SimRouteKind.screen, environmentId: 'privacy'),
  SimSchoolRoute(path: '/termos', kind: SimRouteKind.screen, environmentId: 'terms'),
  SimSchoolRoute(path: '/conta/deletar', kind: SimRouteKind.screen, environmentId: 'delete_account'),
  SimSchoolRoute(
    path: '/api/bootstrap-t00',
    kind: SimRouteKind.api,
    environmentId: 'server_t00',
    serverOnly: true,
  ),
  SimSchoolRoute(
    path: '/api/generate-lesson-image',
    kind: SimRouteKind.api,
    environmentId: 'server_image',
    serverOnly: true,
  ),
  SimSchoolRoute(
    path: '/api/generate-lesson-audio',
    kind: SimRouteKind.api,
    environmentId: 'server_audio',
    serverOnly: true,
  ),
  SimSchoolRoute(
    path: '/api/public/payments/webhook',
    kind: SimRouteKind.api,
    environmentId: 'server_stripe_webhook',
    serverOnly: true,
  ),
  SimSchoolRoute(
    path: 'https://wa.me/message/RLCYEXAYFUIIA1',
    kind: SimRouteKind.external,
    environmentId: 'developer_whatsapp',
  ),
  SimSchoolRoute(
    path: 'https://m.me/61557707493807',
    kind: SimRouteKind.external,
    environmentId: 'developer_messenger',
  ),
  SimSchoolRoute(
    path: 'https://checkout.stripe.com/',
    kind: SimRouteKind.external,
    environmentId: 'stripe_checkout',
  ),
];

SimSchoolRoute? findSimRoute(String path) {
  for (final route in simLiveRoutes) {
    if (route.path == path) return route;
  }
  return null;
}

bool isLiveSimRoute(String path) => findSimRoute(path) != null;
