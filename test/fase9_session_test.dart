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

  test('LessonUiState.toggleDoubt alterna e advanceAulaVisual fecha dúvida', () {
    final ui = LessonUiState();

    ui.toggleDoubt();
    expect(ui.doubtOpen, isTrue);

    ui.advanceAulaVisual();
    expect(ui.doubtOpen, isFalse);
    expect(ui.imageStatus, 'idle');
  });
}
