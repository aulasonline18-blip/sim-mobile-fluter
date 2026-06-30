# Matriz combinada de paridade do menu sanduiche da aula

Escopo: menu sanduiche da sala de aula, comparando SimWeb e Flutter.

Provas de implementacao:
- Flutter: `lib/shared/widgets/shared_widgets.dart`
- Sessao/estado/cloud: `lib/features/session/lab_session.dart`
- Web referencia: `/root/sim-work/sim-web/src/cyber/AulaDrawer.tsx`
- Testes: `test/widget_test.dart`

## Tabela combinada

| # | Linha auditada | Prova principal no Flutter | Diferenca |
|---:|---|---|---|
| 1 | Fechar drawer por `X` | `showAulaMenu`, `_AulaDrawerContent` | 100% igual |
| 2 | Fechar drawer por backdrop | `showGeneralDialog(barrierDismissible: true)` | 100% igual |
| 3 | Nova aula inicia fluxo em `/cyber/aula` | `LabSession.startNewLessonFromDrawer()` | 100% igual |
| 4 | Nova aula limpa objetivo/curriculo visual ativo | `startNewLessonFromDrawer()` reseta entry/lesson UI | 100% igual |
| 5 | Nova aula preserva arquitetura fora do widget | widget chama metodo da sessao | 100% igual |
| 6 | Recarregar creditos autenticado | `openCreditsFromDrawer()` | 100% igual |
| 7 | Recarregar creditos preserva `returnTo=/cyber/aula` | `navigationState.openRoute('/creditos?returnTo=/cyber/aula')` | 100% igual |
| 8 | Busca por historico cloud/local | `matchesLessonSearch` | 100% igual |
| 9 | Busca por tema/titulo/idioma/nivel/id | `_matchesStateSearch`, `_matchesCloudSearch` | 100% igual |
| 10 | Contador visivel/total | `shownRows/totalRows` | 100% igual |
| 11 | Loading de aulas da conta | `_cloudLoading`, `searching_account` | 100% igual |
| 12 | Estado historico vazio logado | `no_account_lessons` | 100% igual |
| 13 | Estado historico vazio deslogado | `historico_vazio` | 100% igual |
| 14 | Estado busca vazia | `drawer_search_empty` | 100% igual |
| 15 | Abrir aula cloud | `openDrawerCloudLesson` | 100% igual |
| 16 | Abrir aula local | `openDrawerLocalLesson` | 100% igual |
| 17 | Fallback cloud ao abrir local | `openDrawerLocalLesson` chama `openDrawerCloudLesson` | 100% igual |
| 18 | Renomear local inline | `_startRename`, `_confirmRename` | 100% igual |
| 19 | Renomear cloud inline | `_startRenameCloud`, `renameDrawerCloudLesson` | 100% igual |
| 20 | Apagar local com tombstone | `deleteDrawerLocalLesson` | 100% igual |
| 21 | Apagar local tambem tenta cloud quando logado | `deleteDrawerLocalLesson` chama `deleteDrawerCloudLesson` | 100% igual |
| 22 | Apagar cloud | `deleteDrawerCloudLesson` | 100% igual |
| 23 | Carregar mais pagina 30+30 | `aulaDrawerInitialVisible`, `aulaDrawerPageSize` | 100% igual |
| 24 | Exportar backup em formato Web | `buildDrawerBackupText` | 100% igual |
| 25 | Importar backup Web/Flutter | `importDrawerBackup`, `StudentStateStore.parseBackupText` | 100% igual |
| 26 | Exportar status | `buildDrawerStatusText`, `writeDrawerStatusFile` | 100% igual |
| 27 | Logout so autenticado | bloco `if (session.authed)` | 100% igual |
| 28 | Solicitar exclusao da conta so autenticado | bloco `if (session.authed)` | 100% igual |
| 29 | Abrir menu sanduiche | `showAulaMenu` | 100% igual |
| 30 | Fechar `X` nao altera aula | `Navigator.pop` | 100% igual |
| 31 | Fechar backdrop nao altera aula | `barrierDismissible` | 100% igual |
| 32 | Nova aula remove aula ativa da UI | `lessonLocalId = null` | 100% igual |
| 33 | Nova aula reseta status de entrada | `entryStatus = 'idle'` | 100% igual |
| 34 | Nova aula reseta erros de entrada | `entryError = null` | 100% igual |
| 35 | Nova aula reseta placement | `placementStarted=false`, `placementDone=false` | 100% igual |
| 36 | Nova aula fecha duvida/revisao/recuperacao | `doubtOpen=false`, rooms null | 100% igual |
| 37 | Nova aula limpa anexos | `entryForm.clearAttachments()` | 100% igual |
| 38 | Nova aula limpa idioma | `entryForm.resetLanguage()` | 100% igual |
| 39 | Nova aula navega sem T00/T02 | rota apenas `/cyber/aula` | 100% igual |
| 40 | Creditos deslogado vai login | `goLogin(target: '/cyber/aula')` | 100% igual |
| 41 | Creditos logado salva retorno | `returnTo='/cyber/aula'` | 100% igual |
| 42 | Creditos abre tela de creditos com query | `/creditos?returnTo=/cyber/aula` | 100% igual |
| 43 | Busca reseta paginacao | `_visibleLessonCount = aulaDrawerInitialVisible` | 100% igual |
| 44 | Busca inclui marker atual | `_matchesStateSearch` | 100% igual |
| 45 | Busca inclui cloud id | `_matchesCloudSearch` | 100% igual |
| 46 | Lista cloud filtra deletadas | `rows.where((row) => !row.deleted)` | 100% igual |
| 47 | Lista local filtra tombstone | `listLocalStates()` | 100% igual |
| 48 | Cloud aparece antes de local | `visibleCloud` antes de `visibleStates` | 100% igual |
| 49 | Dedupe cloud/local por lessonLocalId | `cloudOnly.where(!localIds.contains(...))` | 100% igual |
| 50 | Linha cloud mostra titulo | `_DrawerCloudLessonRow` | 100% igual |
| 51 | Linha cloud mostra progresso | `_DrawerCloudLessonRow pct/adv/total` | 100% igual |
| 52 | Linha local mostra titulo | `_DrawerLessonRow` | 100% igual |
| 53 | Linha local mostra progresso | `_DrawerLessonRow pct/adv/total/pend` | 100% igual |
| 54 | Abrir cloud hidrata store | `canonicalStore?.writeState(state)` | 100% igual |
| 55 | Abrir cloud seta aula ativa | `lessonLocalId = state.lessonLocalId` | 100% igual |
| 56 | Abrir cloud abre runtime | `openAulaRuntime()` | 100% igual |
| 57 | Abrir cloud falha com erro claro | retorna false e flash `curriculo_nao_encontrado` | 100% igual |
| 58 | Abrir local le estado local | `_readExistingLocalState` | 100% igual |
| 59 | Abrir local ignora deletado | `_stateDeleted(local)` | 100% igual |
| 60 | Abrir local abre runtime | `openAulaRuntime()` | 100% igual |
| 61 | Abrir local fallback cloud | `return openDrawerCloudLesson(lessonLocalId)` | 100% igual |
| 62 | Renomear local nao aceita vazio | `renameLesson` preserva estado se vazio | 100% igual |
| 63 | Renomear local atualiza profile | `StudentStateStore.renameLesson` | 100% igual |
| 64 | Renomear local marca `renamedAt` | `extra['renamedAt']` | 100% igual |
| 65 | Renomear cloud nao aceita vazio | `renameDrawerCloudLesson` | 100% igual |
| 66 | Renomear cloud atualiza profile | `profile.copyWith(...)` | 100% igual |
| 67 | Renomear cloud persiste servidor | `persistStudentState` | 100% igual |
| 68 | Renomear cloud refaz lista | `_refreshCloudLessons()` | 100% igual |
| 69 | Cancelar rename local | `_renamingLessonId = null` | 100% igual |
| 70 | Cancelar rename cloud | `_renamingCloudId = null` | 100% igual |
| 71 | Apagar local confirma antes | `AlertDialog(confirmar_apagar)` | 100% igual |
| 72 | Apagar local faz tombstone | `canonicalStore.tombstoneLesson` | 100% igual |
| 73 | Apagar local ativo volta portal | `navigationState.goPortal()` | 100% igual |
| 74 | Apagar local logado chama cloud delete | `deleteDrawerCloudLesson` | 100% igual |
| 75 | Apagar cloud confirma antes | `AlertDialog(drawer_delete_account_confirm)` | 100% igual |
| 76 | Apagar cloud chama API cloud | `deleteStudentStateByLesson` | 100% igual |
| 77 | Apagar cloud tomba local se houver | `_readExistingLocalState` + `tombstoneLesson` | 100% igual |
| 78 | Apagar cloud ativo volta portal | `navigationState.goPortal()` | 100% igual |
| 79 | Apagar falho mostra erro | `drawer_delete_error/cloud_error` | 100% igual |
| 80 | Carregar mais preserva aula ativa | so altera `_visibleLessonCount` | 100% igual |
| 81 | Exportar gera `SIM_CYBER_BACKUP_V1` | `buildDrawerBackupText` | 100% igual |
| 82 | Exportar usa bloco `SIM_CYBER_V1_BEGIN` | `buildDrawerBackupText` | 100% igual |
| 83 | Exportar usa bloco `SIM_CYBER_V1_END` | `buildDrawerBackupText` | 100% igual |
| 84 | Exportar inclui `exportedAt` | `file['exportedAt']` | 100% igual |
| 85 | Exportar inclui `lessons` | `_cyberLessonFromState` | 100% igual |
| 86 | Exportar inclui `studentLearningStates` | `snapshots[state.lessonLocalId]` | 100% igual |
| 87 | Exportar gera arquivo `.txt` | `writeDrawerBackupFile` | 100% igual |
| 88 | Exportar nomeia `sim-backup-YYYY-MM-DD.txt` | `writeDrawerBackupFile` | 100% igual |
| 89 | Exportar tambem copia conteudo | `Clipboard.setData` no drawer | 100% igual |
| 90 | Importar aceita envelope Web | `parseBackupText` | 100% igual |
| 91 | Importar aceita JSON Flutter antigo | `importBackup` caminho `state/events` | 100% igual |
| 92 | Importar aceita base64 | `parseBackupText` | 100% igual |
| 93 | Importar mergeia backup Web | `_importCyberBackup` | 100% igual |
| 94 | Importar deduplica eventos | `_dedupeEvents` no store | 100% igual |
| 95 | Importar define aula ativa | `lessonLocalId = state.lessonLocalId` | 100% igual |
| 96 | Importar logado persiste cloud | `persistStudentState` loop ids | 100% igual |
| 97 | Importar atualiza lista cloud | `_refreshCloudLessons` | 100% igual |
| 98 | Importar invalido mostra erro | `backup_invalido` | 100% igual |
| 99 | Status gera texto pedagogico | `buildDrawerStatusText` | 100% igual |
| 100 | Status gera arquivo `.txt` | `writeDrawerStatusFile` | 100% igual |
| 101 | Status nomeia `sim-status-YYYY-MM-DD.txt` | `writeDrawerStatusFile` | 100% igual |
| 102 | Status copia conteudo | `Clipboard.setData` no drawer | 100% igual |
| 103 | Status inclui objetivo | `Objetivo:` | 100% igual |
| 104 | Status inclui topico | `Topico:` | 100% igual |
| 105 | Status inclui item | `Item:` | 100% igual |
| 106 | Status inclui camada | `Camada:` | 100% igual |
| 107 | Status inclui progresso | `Progresso:` | 100% igual |
| 108 | Status inclui tentativas | `Tentativas:` | 100% igual |
| 109 | Footer mostra progresso ativo | `drawer_progress` | 100% igual |
| 110 | Footer mostra concluidos ok | `concluidos.length ok` | 100% igual |
| 111 | Footer mostra pendentes | `pendentesMarkers.length pend.` | 100% igual |
| 112 | Feedback some apos 2,2s | `_flash` | 100% igual |
| 113 | Logout aparece so logado | `if (session.authed)` | 100% igual |
| 114 | Logout chama sign out real | `_handleLogout -> signOutReal` | 100% igual |
| 115 | Logout fecha drawer | `widget.onClose()` | 100% igual |
| 116 | Logout nao mexe T00/T02 | somente auth/session | 100% igual |
| 117 | Excluir conta aparece so logado | `if (session.authed)` | 100% igual |
| 118 | Excluir conta abre rota dedicada | `/conta/deletar` | 100% igual |
| 119 | Excluir conta nao apaga direto | so navega para fluxo formal | 100% igual |
| 120 | Botao TOP UP mantem label | `TOP UP` | 100% igual |
| 121 | Icone rename | `_DrawerIconButton` => `✎` | 100% igual |
| 122 | Icone delete | `_DrawerIconButton` => `🗑` | 100% igual |
| 123 | Confirmar rename | `_DrawerIconButton` => `✓` | 100% igual |
| 124 | Cancelar rename | `_DrawerIconButton` => `✕` | 100% igual |
| 125 | Erro cloud loading | `_refreshCloudLessons` flash erro | 100% igual |
| 126 | Arquitetura sem logica no main | nenhum edit em `lib/main.dart` | 100% igual |
| 127 | Sem T00/T02 alterado | nenhum edit em adapters/AI | 100% igual |
| 128 | Teste cobre contrato do drawer | `widget_test.dart` drawer tests | 100% igual |

