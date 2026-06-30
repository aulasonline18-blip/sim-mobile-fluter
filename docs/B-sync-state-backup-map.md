# B Sync, State, Backup Map

Data: 2026-06-30.

## Fontes Consultadas

- Planta-Mae: `PLANTA-MÃE DO SIM IDEAL.txt`, linhas de Camada 9, S02, S13 e High Water Mark.
- Flutter: `lib/sim/state/student_learning_state.dart`, `student_state_store.dart`, `lib/sim/cloud/*`, `lib/shared/widgets/shared_widgets.dart`.
- API: `/root/sim-work/sim-api/src/app/router.js`, `src/student-state/student-state-controller.js`.
- SimWeb: `/root/sim-work/sim-web/src/cyber/state-director.ts`, `src/sim/state/studentLearningState.types.ts`.

## Planta-Mae

| Orgao | Responsabilidade |
|---|---|
| Camada 9 | Exportar/importar progresso, gerar snapshot, migrar dispositivo, sincronizar e proteger contra perda. |
| S02 State Store | Guardar estado critico, salvar depois de escolhas/respostas e gerar snapshots. |
| S13 Backup Manager | Backup minimo com versao, idioma, perfil, objetivo, curriculo, item atual, conquistas, fraquezas, revisoes, aula atual e checksum. |
| High Water Mark | Local nunca apaga remoto mais avancado; remoto nunca apaga local mais avancado sem comparacao. |

## Inventario Do StudentLearningState

| Campo | Existe | Salvo | Restaurado | Backup | Nuvem | SimWeb | Migracao/Teste |
|---|---:|---:|---:|---:|---:|---:|---|
| `stateVersion` | Sim | Sim | Sim | Sim | Sim | `stateVersion` | roundtrip |
| `lessonLocalId` | Sim | Sim | Sim | Sim | Sim | `lessonLocalId` | Web import |
| `lessonCloudId` | Sim | Sim | Sim | Sim | Sim | `lessonCloudId` | roundtrip |
| `userId` | Sim | Sim | Sim | Sim | Sim | `userId` | sync/API |
| `profile` | Sim | Sim | Sim | Sim | Sim | `profile` | Web import |
| `curriculum`/itens/markers | Sim | Sim | Sim | Sim | Sim | `curriculum`, `lessons.curriculo` | Web import |
| `curriculumStatus` | Sim | Sim | Sim | Sim | Sim | `curriculumStatus` | migracao camel/snake parcial |
| `current` item/layer | Sim | Sim | Sim | Sim | Sim | `current` | Web import |
| `progress` | Sim | Sim | Sim | Sim | Sim | `progress` | roundtrip/sync |
| `attempts` | Sim | Sim | Sim | Sim | Sim | `attempts` | roundtrip/Web import |
| sinais | Sim, em `attempts.sinal` | Sim | Sim | Sim | Sim | `attempts.sinal` | roundtrip/Web import |
| qualificadores | Sim, em `truth_typed` e legado `truth` | Sim | Sim | Sim | Sim | `truth`/eventos | roundtrip/Web import |
| pendencias | Sim, `progress.pendentesMarkers` e `auxRooms.pendingMap` | Sim | Sim | Sim | Sim | `auxRooms.pendingMap` | roundtrip/Web import |
| conclusao | Sim, `progress.itemIdx/mainAdvances/pctAvanco`, eventos | Sim | Sim | Sim | Sim | `progress`, eventos | B normal flow |
| revisao/recuperacao | Sim, `auxRooms` | Sim | Sim | Sim | Sim | `auxRooms` | testes auxiliares existentes |
| historico/eventos | Sim, `events` e Event Log canonico | Sim | Sim | Sim | Sim | `events` | backup roundtrip |
| aula/material atual | Sim, `currentLessonMaterial` | Sim | Sim | Sim | Sim | `current_lesson_material` | alias Web |
| aulas prontas | Sim, `readyLessonMaterials` | Sim | Sim | Sim | Sim | `ready_lesson_materials` | alias Web |
| fila | Sim, `queuedActions`/`inflightJobs` | Sim | Sim | Sim | Sim | `queued_actions`/`inflight_jobs` | alias Web |
| sync status | Sim, `sync_status_typed`, legado `syncInfo` | Sim | Sim | Sim | Sim | `syncInfo` | Web import |
| tombstone | Sim, `deletedAt`/`syncInfo.deletedAt` em extra | Sim | Sim | Sim | Sim | `deletedAt`, `syncInfo` | drawer/API |

## Backup SimWeb

Formato real:

- Texto com cabecalho `SIM - BACKUP DE AULA`.
- Bloco `SIM_CYBER_V1_BEGIN` / `SIM_CYBER_V1_END`.
- Conteudo base64 de JSON.
- JSON: `{ magic: "SIM_CYBER_BACKUP_V1", exportedAt, lessons, studentLearningStates }`.

| Campo backup SimWeb | Significado | Existe no Flutter | Mapeamento |
|---|---|---:|---|
| `magic` | Identificador do backup | Sim | `StudentStateStore.importBackup` detecta |
| `exportedAt` | Timestamp de exportacao | Sim | metadado, nao governa estado |
| `lessons[].id` | id local da aula | Sim | `lessonLocalId` |
| `lessons[].onboarding` | objetivo/idioma/nivel | Sim | `StudentProfile.extra` + campos tipados |
| `lessons[].curriculo` | curriculo legado | Sim | `StudentCurriculum` quando nao ha snapshot |
| `studentLearningStates[id]` | snapshot canonico Web | Sim | `StudentLearningState.fromJson` |
| `current_lesson_material` | aula atual Web | Sim | `currentLessonMaterial` |
| `ready_lesson_materials` | materiais preparados | Sim | `readyLessonMaterials` |
| `queued_actions` | fila Web | Sim | `queuedActions` |
| `inflight_jobs` | jobs ativos Web | Sim | `inflightJobs` |
| `syncInfo` | estado sync/tombstone Web | Sim | preservado em `extra` |

## Backup SimApp

Formato atual:

```json
{
  "kind": "sim-student-learning-backup",
  "schema_version": 1,
  "exported_at": 0,
  "state": {},
  "events": []
}
```

O SimApp exporta e reimporta o proprio formato. A diferenca para o Web esta documentada: o Web exporta multiplas aulas em um envelope `SIM_CYBER_BACKUP_V1`; o Flutter agora importa esse envelope, mas ainda exporta uma aula por vez pelo drawer.

## API/Synapse

| Endpoint | Status | Funcao |
|---|---|---|
| `POST /api/student-state/persist` | Implementado | Salva snapshot por usuario, rejeita regressao por high-water mark. |
| `POST /api/student-state/get` | Implementado | Busca aula por `lessonLocalId` do usuario autenticado. |
| `POST /api/student-state/list` | Implementado | Lista snapshots do usuario. |
| `POST /api/student-state/summaries` | Implementado | Lista resumos para drawer cloud. |
| `POST /api/student-state/delete` | Implementado | Tombstone seguro por usuario. |

## Testes De Cobertura

- `student_state_roundtrip_test`.
- `simweb_backup_import_test`.
- `simapp_backup_roundtrip_test`.
- `multi_device_state_sync_test`.
- Testes existentes de drawer local/cloud em `widget_test.dart`.
- Teste API em `/root/sim-work/sim-api/test/server-contract.test.js`.
