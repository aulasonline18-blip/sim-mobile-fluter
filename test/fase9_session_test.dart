import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/session/auth_session.dart';
import 'package:sim_mobile/session/entry_form_state.dart';
import 'package:sim_mobile/session/lesson_ui_state.dart';
import 'package:sim_mobile/session/navigation_state.dart';

void main() {
  test('EntryFormState notifica ao mudar freeText', () {
    final form = EntryFormState();
    var notified = false;
    form.addListener(() => notified = true);

    form.updateFreeText('teste');

    expect(notified, isTrue);
    expect(form.freeText, 'teste');
  });

  test('AuthSession começa com authed=false', () {
    final auth = AuthSession(navigation: NavigationState());

    expect(auth.authed, isFalse);
    expect(auth.authReady, isFalse);
  });

  test('NavigationState preserva retorno seguro', () {
    final nav = NavigationState();

    nav.goLogin(target: '/cyber/aula');

    expect(nav.route, '/login');
    expect(nav.returnTo, '/cyber/aula');
  });

  test('LessonUiState mantém estado visual legado de aula isolado', () {
    final ui = LessonUiState();

    ui.chooseAulaAnswer('B');
    expect(ui.selectedAnswer, 'B');
    expect(ui.aulaMessage, contains('revisão'));

    ui.advanceAulaVisual();
    expect(ui.aulaStep, 1);
    expect(ui.selectedAnswer, isEmpty);
    expect(ui.aulaMessage, isEmpty);
  });
}
