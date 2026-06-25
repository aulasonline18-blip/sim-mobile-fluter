# FASE 14 - Paridade Visual Web x Android

Data: 2026-06-26

## Escopo executado

- Referencia Web lida em `C:\Users\ADMIN\Documents\GitHub\gemini-aid-pal`.
- Flutter alterado apenas em `C:\Users\ADMIN\Documents\GitHub\sim-mobile-fluter`.
- O caminho solicitado `C:\sim_mobile` nao existe neste computador.
- O SIM Web nao foi alterado.
- Nao houve commit.
- Nao houve push.

## Screenshots

Gerados:

- `web_portal.png`
- `web_login.png`

Bloqueios:

- Android/tablet/emulador nao foi detectado por `flutter devices`.
- O projeto Flutter nao possui plataforma Web configurada.
- O projeto Flutter nao possui plataforma Windows configurada.
- Por isso, nao foi possivel gerar screenshots Android/Flutter lado a lado neste ambiente sem adicionar plataforma nova ao projeto, o que ficaria fora do escopo visual.

## Telas auditadas por codigo

- Portal inicial
- Login
- Idioma
- Objetivo com anexos
- Preparo/robo
- Escolha/nivelamento
- Aula
- Duvida/revisao/recuperacao/amparo como paineis presentes no arquivo principal
- Creditos
- Drawer/Historico
- Painel do Pai
- Termos/Privacidade

## Diferencas encontradas

- Textos visiveis do Flutter continham mojibake (`Ã`, `Â`, sequencias quebradas de setas, acentos e emojis).
- A tela de idioma do Flutter divergia do Web em textos principais: Web usa `Choose your language` e descricao em ingles.
- Alguns rotulos de aula, preparo, creditos, painel do pai e anexos apareciam corrompidos.
- Bandeiras do seletor de idioma estavam corrompidas.
- Algumas telas citadas ainda nao puderam ser comparadas visualmente por screenshot Android real.

## Correcoes feitas

Arquivo alterado:

- `lib/main.dart`

Correcoes:

- Removidos textos corrompidos nas telas principais.
- Corrigidos textos de Portal/Login/Idioma/Objetivo/Preparo/Aula/Creditos/Painel do Pai/Termos/Privacidade.
- Corrigidos rotulos de audio, duvida, revisao, recuperacao, curriculo, checkout e mensagens de erro.
- Corrigido texto do botao principal do portal para `Entrar para começar`.
- Substituidos simbolos quebrados de anexos por rotulos limpos (`foto`, `pdf`, `doc`, `x`).
- Substituidas bandeiras quebradas por rotulos limpos (`US`, `BR`, `ES`, `FR`, `JP`).

## Validacao

- `flutter analyze lib\main.dart`: passou, sem issues.
- `flutter test`: falhou com 4 falhas no total.
  - Uma falha de texto do portal foi corrigida depois.
  - Falha restante conhecida em `finish_phase_test.dart`: espera o texto antigo `Imagem da aula`, que nao aparece mais.
  - Falhas restantes em `widget_test.dart`: dois `pumpAndSettle timed out`.
- `flutter test test\widget_test.dart`: 2 passaram, 2 falharam por `pumpAndSettle timed out`.
- Busca por mojibake em `lib/main.dart`: sem ocorrencias para os padroes `Ã`, `Â`, `â`, `ð`, `œ`, `•`.

## Status por tela

- Portal inicial: quase identica por estrutura; texto corrompido corrigido.
- Login: parcialmente auditada com screenshot Web; texto corrompido corrigido.
- Idioma: texto principal alinhado ao Web; screenshot Android bloqueado.
- Objetivo: texto corrompido corrigido; screenshot Android bloqueado.
- Preparo/robo: texto corrompido corrigido; screenshot Android bloqueado.
- Escolha/nivelamento: texto corrompido corrigido; screenshot Android bloqueado.
- Aula: texto corrompido corrigido; screenshot Android bloqueado.
- Duvida: painel existe; screenshot Android bloqueado.
- Revisao: painel existe; screenshot Android bloqueado.
- Recuperacao: painel existe; screenshot Android bloqueado.
- Creditos: texto corrompido corrigido; screenshot Android bloqueado.
- Drawer/Historico: texto corrompido corrigido; screenshot Android bloqueado.
- Painel do Pai: texto corrompido corrigido; screenshot Android bloqueado.
- Termos/Privacidade: texto corrompido corrigido; screenshot Android bloqueado.

## Seguranca

- Nenhum prompt foi adicionado ao Flutter.
- Nenhuma chave secreta foi adicionada ao Flutter.
- Apenas a chave publishable/anon existente do Supabase permanece no app.

## Proxima verificacao necessaria

Para concluir a Fase 14 em nivel visual real, conectar um tablet/emulador Android ou configurar o projeto para uma plataforma de renderizacao controlada. A comparacao lado a lado completa precisa de screenshots Flutter reais, nao apenas leitura de codigo.
