import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/school/aula_drawer_contract.dart';
import 'package:sim_mobile/sim/school/sim_school_completeness.dart';
import 'package:sim_mobile/sim/school/sim_school_environment.dart';
import 'package:sim_mobile/sim/school/sim_school_routes.dart';

void main() {
  test('all live school routes from SIM current are represented', () {
    final paths = simLiveRoutes.map((route) => route.path).toSet();

    expect(paths, contains('/'));
    expect(paths, contains('/login'));
    expect(paths, contains('/cyber/idioma'));
    expect(paths, contains('/cyber/objeto'));
    expect(paths, contains('/cyber/curriculo'));
    expect(paths, contains('/cyber/placement'));
    expect(paths, contains('/cyber/aula'));
    expect(paths, contains('/creditos'));
    expect(paths, contains('/checkout/return'));
    expect(paths, contains('/pai'));
    expect(paths, contains('/privacidade'));
    expect(paths, contains('/termos'));
    expect(paths, contains('/conta/deletar'));
    expect(paths, contains('/api/bootstrap-t00'));
    expect(paths, contains('/api/generate-lesson-image'));
    expect(paths, contains('/api/generate-lesson-audio'));
    expect(paths, contains('/api/public/payments/webhook'));
  });

  test('server brain and secrets routes are not app-side rooms', () {
    final serverRoutes = simLiveRoutes.where((route) => route.serverOnly).map((route) => route.path).toSet();

    expect(serverRoutes, contains('/api/bootstrap-t00'));
    expect(serverRoutes, contains('/api/generate-lesson-image'));
    expect(serverRoutes, contains('/api/generate-lesson-audio'));
    expect(serverRoutes, contains('/api/public/payments/webhook'));
  });

  test('school environments include every healthy room and door destination resolves', () {
    final ids = simSchoolEnvironments.map((environment) => environment.id).toSet();

    expect(ids, contains('portal'));
    expect(ids, contains('login'));
    expect(ids, contains('language'));
    expect(ids, contains('objective'));
    expect(ids, contains('preparation'));
    expect(ids, contains('placement'));
    expect(ids, contains('classroom'));
    expect(ids, contains('drawer'));
    expect(ids, contains('credits'));
    expect(ids, contains('checkout_return'));
    expect(ids, contains('father_panel'));
    expect(ids, contains('delete_account'));
    expect(ids, contains('privacy'));
    expect(ids, contains('terms'));
    expect(unresolvedInternalDestinations(), isEmpty);
  });

  test('critical doors preserve live button flow', () {
    final doors = {for (final door in allSimSchoolDoors()) door.id: door};

    expect(doors['portal_start']?.destination, '/cyber/idioma');
    expect(doors['language_known']?.destination, '/cyber/objeto');
    expect(doors['objective_continue']?.destination, '/cyber/curriculo');
    expect(doors['prep_to_placement']?.destination, '/cyber/placement');
    expect(doors['prep_to_classroom']?.destination, '/cyber/aula');
    expect(doors['placement_skip']?.destination, '/cyber/aula');
    expect(doors['class_buy_credits']?.destination, '/creditos');
    expect(doors['drawer_delete_account']?.destination, '/conta/deletar');
    expect(doors['checkout_retry']?.destination, '/creditos');
  });

  test('aula drawer contract preserves menu organs and search behavior', () {
    final actions = {for (final action in aulaDrawerActions) action.id: action};

    expect(aulaDrawerInitialVisible, 30);
    expect(aulaDrawerPageSize, 30);
    expect(actions['new_lesson']?.destination, '/cyber/aula');
    expect(actions['top_up']?.destination, '/creditos');
    expect(actions['logout']?.destination, '/login');
    expect(actions['delete_account']?.destination, '/conta/deletar');
    expect(matchesLessonSearch('bio', ['Matemática', 'Biologia']), true);
    expect(matchesLessonSearch('geo', ['Matemática', 'Biologia']), false);
  });

  test('school completeness report has no unresolved internal doors', () {
    final report = buildSimSchoolCompletenessReport();

    expect(report.complete, true);
    expect(report.environmentCount, greaterThanOrEqualTo(14));
    expect(report.doorCount, greaterThanOrEqualTo(50));
    expect(report.screenRouteCount, 13);
    expect(report.apiRouteCount, 4);
    expect(report.externalRouteCount, 3);
  });
}
