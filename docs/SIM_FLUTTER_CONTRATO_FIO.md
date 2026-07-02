# SIM Flutter - Contrato-Fio Waves 1 e 2

Este documento registra o contrato que o Flutter deve preservar ao consumir o SIM-API.

## T00

- O SSE `type=start` pode trazer `model` e `prompt_sha`.
- O Flutter deve manter esses campos na telemetria/diagnostico quando recebidos.
- O bootstrap deve enviar, quando existirem no onboarding/perfil:
  - `nivel`;
  - `official_curriculum_reference`;
  - `prior_knowledge`;
  - `known_weaknesses`;
  - `subject`;
  - `target_topic`;
  - `free_text`;
  - `stableLang`/`language`.

## Fatal SSE

O evento fatal pode trazer `code`.

Codigos esperados:

- `T00_MODEL_UNAVAILABLE`;
- `T00_TIMEOUT`;
- `T00_TRUNCATED`;
- `T00_UNKNOWN`.

O Flutter nao deve tratar todos como erro generico se houver `code`.

## Imagem

- O Flutter deve tentar software antes de imagem paga.
- A cascata correta e:
  - SVG inline;
  - math template;
  - N2 local;
  - `/api/visual-route` N3;
  - oferta paga somente se software nao resolver.
- O Flutter nao deve gerar imagem paga em prefetch/background.
- `acceptedOfferId` e obrigatorio para imagem paga.
- `idempotencyKey` deve ser estavel por oferta aceita.
- `lessonKey`/item/layer precisam continuar estaveis para cache e replay.

## Creditos

- O servidor pode retornar `X-Credits-Balance`.
- O Flutter deve atualizar o saldo local quando esse header existir.
- Em 429, o servidor pode retornar `Retry-After`.
- O Flutter deve respeitar `Retry-After` e nao entrar em loop de retry.

## Audio

- O endpoint de audio continua JSON.
- Enviar `language`, `voice`, `speed`, `lessonKey` e `text`.
- Se a preferencia de audio estiver desligada, nao chamar API.
- Falha de API nao pode deixar bolha/avatar em estado falso.
