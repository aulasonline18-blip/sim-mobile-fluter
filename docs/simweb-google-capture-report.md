# SimWeb Google Capture Report

Data: 2026-06-30.

Objetivo: usar a conta de teste `ccrfoodgy1@gmail.com` apenas como referencia
visual/funcional do SimWeb para capturar fluxo autenticado com credito infinito.

## Regras Preservadas

- SimWeb nao foi alterado como produto.
- Nao mexi em logica de creditos.
- Nao adicionei credito manualmente.
- Nao mexi em T00.
- Nao mexi em T02.
- Nao mexi no servidor.
- Nao registrei senha, token ou segredo no repositorio.
- A senha provisoria foi usada somente na sessao interativa de login Google.

## Ambiente

- SimWeb publicado usado para captura real:
  `https://gemini-aid-pal.lovable.app`.
- Ferramentas de captura:
  - Playwright temporario fora dos repositorios em `/tmp/sim-capture-tools`.
  - Xvfb para navegador headed durante o login Google.
- Storage autenticado temporario salvo fora do repositorio:
  `/tmp/simweb-google-live-state.json`.

## Resultado Da Autenticacao

Email usado: `ccrfoodgy1@gmail.com`.

Login Google concluido apos confirmacao manual pelo celular do usuario.

URL autenticada confirmada apos login:

- `https://gemini-aid-pal.lovable.app/cyber/idioma`

## Confirmacao De Credito Infinito

Confirmada visualmente no SimWeb autenticado.

Provas:

- `docs/interface-screenshots/simweb-live-google/01-portal-auth-390x844.png`
- `docs/interface-screenshots/simweb-live-google/02-drawer-auth-390x844.png`
- `docs/interface-screenshots/simweb-live-google/03-creditos-390x844.png`
- `docs/interface-screenshots/simweb-live-google/capture-log-sanitized.json`

O saldo exibido no portal/drawer foi `999999`, usado como sinal visual da conta
de credito infinito.

## Prints Capturados

Diretorio principal:

- `docs/interface-screenshots/simweb-live-google/`

Capturas autenticadas principais:

- Portal: `01-portal-auth-390x844.png`
- Drawer: `02-drawer-auth-390x844.png`
- Creditos: `03-creditos-390x844.png`
- Idioma autenticado: `04-idioma-390x844.png`
- Objetivo vazio: `05-objetivo-vazio-390x844.png`
- Anexos base: `06-anexos-base-390x844.png`
- Anexos menu aberto: `06-anexos-menu-390x844.png`
- Objetivo preenchido: `07-objetivo-preenchido-390x844.png`
- Preparacao/curriculo: `08-preparacao-inicio-390x844.png`
- Placement/nivelamento: `14c-placement-choice-390x844.png`
- Aula real: `15c-aula-real-390x844.png`
- Alternativa B selecionada: `16c-alternativa-b-390x844.png`
- Feedback: `17c-feedback-390x844.png`
- Duvida: `18c-duvida-390x844.png`
- Revisao: `20c-revisao-390x844.png`

Captura auxiliar que provou abertura da aula a partir do placement:

- `placement-after-force-click.png`

## Logs Da Captura

Logs sanitizados salvos:

- `docs/interface-screenshots/simweb-live-google/capture-log-sanitized.json`
- `docs/interface-screenshots/simweb-live-google/classroom3-capture-log-sanitized.json`
- `docs/interface-screenshots/simweb-live-google/attachment-capture-log-sanitized.json`

Evidencias registradas:

- `/api/bootstrap-t00` foi chamado e respondeu no fluxo real.
- O primeiro item `FQ01` apareceu no fluxo capturado.
- A rota chegou a `/cyber/curriculo`, `/cyber/placement` e `/cyber/aula`.
- A tela de objetivo expos o botao `Abrir menu de anexos`.
- O Web registrou aviso de `StudentLearningStateMirror`, observado como
  evidencia de runtime do produto publicado, sem alteracao feita.

## Telas Solicitadas

Capturadas com esta conta:

- Portal.
- Drawer.
- Idioma.
- Objetivo vazio.
- Anexos.
- Objetivo preenchido.
- Preparacao.
- Aula real.
- Duvida.
- Revisao.
- Feedback.
- Creditos.

Nao capturadas nesta rodada:

- Recuperacao real.
- Estado de erro natural dentro da aula.
- Loading isolado alem da preparacao/curriculo.
- Comparativos Flutter equivalentes tela por tela.

## Bloqueio Para B

Ainda existe bloqueio para declarar B.

Esta rodada capturou a referencia real autenticada do SimWeb, mas B restante
exige tambem:

- Capturas equivalentes do Flutter.
- Comparacao visual tela por tela.
- Correcao das diferencas encontradas.
- Drawer cloud completo com paridade funcional.
- Testes e build release passando depois das correcoes.

Status atual: a referencia SimWeb autenticada avancou, mas B ainda nao foi
atingido.
