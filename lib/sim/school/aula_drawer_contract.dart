class AulaDrawerAction {
  const AulaDrawerAction({
    required this.id,
    required this.label,
    required this.effect,
    this.destination,
    this.requiresAuth = false,
  });

  final String id;
  final String label;
  final String effect;
  final String? destination;
  final bool requiresAuth;
}

const aulaDrawerInitialVisible = 30;
const aulaDrawerPageSize = 30;

const aulaDrawerActions = <AulaDrawerAction>[
  AulaDrawerAction(
    id: 'new_lesson',
    label: 'Nova aula',
    effect: 'freezeActive, clearOnboarding, clearCurriculo',
    destination: '/cyber/aula',
  ),
  AulaDrawerAction(
    id: 'top_up',
    label: 'Recarregar créditos',
    effect: 'save returnTo and open credits',
    destination: '/creditos',
    requiresAuth: true,
  ),
  AulaDrawerAction(
    id: 'search_history',
    label: 'Buscar histórico',
    effect: 'filter cloud and local lessons by tema, idioma, nivel or id',
  ),
  AulaDrawerAction(
    id: 'open_cloud_lesson',
    label: 'Abrir aula da conta',
    effect: 'hydrate StudentLearningState from cloud and set active',
    destination: '/cyber/aula',
    requiresAuth: true,
  ),
  AulaDrawerAction(
    id: 'open_local_lesson',
    label: 'Abrir aula local',
    effect: 'restore cyber lesson to session',
    destination: '/cyber/aula',
  ),
  AulaDrawerAction(
    id: 'rename',
    label: 'Renomear',
    effect: 'rename local/cloud lesson and enqueue sync',
  ),
  AulaDrawerAction(
    id: 'delete',
    label: 'Apagar',
    effect: 'local-first tombstone and cloud delete when authenticated',
  ),
  AulaDrawerAction(
    id: 'export_backup',
    label: 'Exportar',
    effect: 'download sim-backup-YYYY-MM-DD.txt',
  ),
  AulaDrawerAction(
    id: 'import_backup',
    label: 'Importar',
    effect: 'parse backup, import lessons, enqueue sync and pull cloud',
  ),
  AulaDrawerAction(
    id: 'export_status',
    label: 'Status',
    effect: 'download sim-status-YYYY-MM-DD.txt from fatherPanel report',
  ),
  AulaDrawerAction(
    id: 'logout',
    label: 'Sair',
    effect: 'signOut, clear local session, open login',
    destination: '/login',
    requiresAuth: true,
  ),
  AulaDrawerAction(
    id: 'delete_account',
    label: 'Solicitar exclusão da conta',
    effect: 'open account deletion route',
    destination: '/conta/deletar',
    requiresAuth: true,
  ),
];

bool matchesLessonSearch(String query, List<Object?> parts) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return parts.any((part) => (part ?? '').toString().toLowerCase().contains(needle));
}
