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
- Nao registrei senha, token ou segredo.
- Logs OAuth brutos foram removidos porque continham URLs longas de estado OAuth.

## Ambiente

- SimWeb local: `/root/sim-work/sim-web`, branch `main`, commit `d113cf4`.
- SimWeb local foi iniciado com Node 22 temporario:
  `PATH="$(dirname $(npx -y -p node@22 which node)):$PATH" npx bun run dev --host 0.0.0.0 --port 4177`.
- O login Google no SimWeb local caiu em `404` na rota `~oauth/initiate`, porque a rota OAuth Lovable Cloud nao existe no dev local.
- SimWeb publicado usado para tentativa OAuth real:
  `https://gemini-aid-pal.lovable.app/login?returnTo=%2Fcyber%2Fidioma`.
- Ferramentas de captura:
  - Playwright temporario em `/tmp/sim-capture-tools`.
  - `xvfb` instalado na VM para tentar navegador headed.

## Resultado Da Autenticacao

Email usado: `ccrfoodgy1@gmail.com`.

Nao consegui concluir login.

Tentativas:

1. SimWeb local, Playwright headless:
   - Login renderizou.
   - Clique em Google abriu `~oauth/initiate`.
   - Resultado: `404 Page not found`.

2. SimWeb publicado, Playwright headless:
   - Google abriu.
   - Email foi preenchido.
   - Resultado: Google recusou com `This browser or app may not be secure`.

3. SimWeb publicado, Playwright headed via Xvfb:
   - Google abriu.
   - Email foi preenchido.
   - Resultado: Google pediu senha.
   - Nao usei senha.

4. SimWeb publicado, `Try another way`:
   - Google mostrou opcoes `Enter your password`, `Use your passkey`, `Try another way`.
   - `Use your passkey` ficou em `Complete sign-in using your passkey`, sem concluir.
   - Nova tentativa em `Try another way` terminou em bloqueio:
     `You're trying to sign in on a device Google doesn't recognize... you can't sign in here right now.`

## Confirmacao De Credito Infinito

Nao confirmada nesta rodada.

Motivo: o login Google da conta de teste nao foi concluido na VM, entao nao foi
possivel abrir `/creditos` autenticado nem iniciar aula real com essa conta.

## Prints Capturados

Tentativa local:

- `docs/interface-screenshots/simweb-google-auth/01-login-390x844.png`
- `docs/interface-screenshots/simweb-google-auth/02-google-start-390x844.png`

Tentativa publicada headless:

- `docs/interface-screenshots/simweb-google-prod/01-login-390x844.png`
- `docs/interface-screenshots/simweb-google-prod/02-google-start-390x844.png`
- `docs/interface-screenshots/simweb-google-prod/03-after-email-390x844.png`

Tentativa publicada headed:

- `docs/interface-screenshots/simweb-google-prod-headed/01-login-390x844.png`
- `docs/interface-screenshots/simweb-google-prod-headed/02-google-start-390x844.png`
- `docs/interface-screenshots/simweb-google-prod-headed/03-after-email-390x844.png`

Tentativa `Try another way`:

- `docs/interface-screenshots/simweb-google-prod-headed-alt/01-login-390x844.png`
- `docs/interface-screenshots/simweb-google-prod-headed-alt/02-google-start-390x844.png`
- `docs/interface-screenshots/simweb-google-prod-headed-alt/03-password-390x844.png`
- `docs/interface-screenshots/simweb-google-prod-headed-alt/04-try-another-way-390x844.png`

Tentativa passkey:

- `docs/interface-screenshots/simweb-google-prod-passkey/01-selection-390x844.png`
- `docs/interface-screenshots/simweb-google-prod-passkey/02-passkey-390x844.png`

Tentativa final de mais metodos:

- `docs/interface-screenshots/simweb-google-prod-moreways/01-selection-390x844.png`
- `docs/interface-screenshots/simweb-google-prod-moreways/02-moreways-390x844.png`

## Telas Solicitadas

Capturadas com esta conta:

- Login publico do SimWeb.
- Fluxo Google ate selecao/desafio de autenticacao.
- Bloqueios Google.

Nao capturadas com esta conta:

- Portal autenticado.
- Drawer autenticado.
- Idioma autenticado.
- Objetivo vazio autenticado.
- Anexos autenticado.
- Objetivo preenchido autenticado.
- Preparacao.
- Aula real.
- Duvida.
- Revisao.
- Recuperacao.
- Feedback.
- Creditos autenticado.
- Estados reais de erro/loading dentro da aula.

## Bloqueio Para B

Ainda existe bloqueio para B.

Para capturar as telas reais autenticadas do SimWeb com essa conta, falta uma
forma de concluir a autenticacao Google na VM. O Google recusou o ambiente novo
e nao ofereceu confirmacao por celular suficiente para concluir login; pediu
senha/passkey ou bloqueou por dispositivo desconhecido.

Opcoes seguras para continuar:

1. Fornecer uma sessao ja autenticada/exportada do navegador autorizado.
2. Logar manualmente essa conta em um navegador persistente da VM via VNC/noVNC
   ou outro acesso visual aprovado.
3. Usar outro metodo oficial de teste que nao exija senha nem manipule credito.

