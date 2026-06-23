class LegalSection {
  const LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}

class LegalPageContent {
  const LegalPageContent({
    required this.route,
    required this.title,
    required this.metaTitle,
    required this.description,
    required this.headerLines,
    required this.sections,
    this.robots = 'index,follow',
  });

  final String route;
  final String title;
  final String metaTitle;
  final String description;
  final String robots;
  final List<String> headerLines;
  final List<LegalSection> sections;
}

const privacyPageContent = LegalPageContent(
  route: '/privacidade',
  title: 'Politica de Privacidade',
  metaTitle: 'Politica de Privacidade - SIM AI Tutor',
  description: 'Politica de privacidade do SIM AI Tutor.',
  headerLines: [
    'App: SIM AI Tutor',
    'Responsavel: pessoa fisica',
    'Contato: smarttutorbr@gmail.com',
    'Foro: Juscimeira, Mato Grosso, Brasil',
    'Data: 21/06/2026',
  ],
  sections: [
    LegalSection(
      title: 'Dados coletados',
      body:
          'O SIM AI Tutor pode coletar email, nome preferido, progresso de estudo, historico de aulas e sinais de resposta por item.',
    ),
    LegalSection(
      title: 'Como os dados sao usados',
      body:
          'Os dados sao usados para personalizacao de aulas por IA e sincronizacao entre dispositivos.',
    ),
    LegalSection(
      title: 'Terceiros',
      body:
          'O SIM AI Tutor pode usar Supabase para banco de dados nos EUA, Google Gemini para IA nos EUA, Stripe e Google Play para pagamentos.',
    ),
    LegalSection(
      title: 'Menores de idade',
      body:
          'Para menores de idade, a coleta de dados ocorre somente com consentimento expresso dos pais ou responsaveis, conforme LGPD Art. 14 e COPPA.',
    ),
    LegalSection(
      title: 'Direitos do usuario',
      body:
          'Voce pode solicitar acesso, correcao e exclusao dos seus dados pelo contato smarttutorbr@gmail.com.',
    ),
    LegalSection(
      title: 'Historico financeiro',
      body:
          'O historico financeiro sera mantido pelo prazo legal obrigatorio mesmo apos exclusao da conta.',
    ),
  ],
);

const termsPageContent = LegalPageContent(
  route: '/termos',
  title: 'Termos de Uso',
  metaTitle: 'Termos de Uso - SIM AI Tutor',
  description: 'Termos de uso do SIM AI Tutor.',
  headerLines: [
    'App: SIM AI Tutor',
    'Contato: smarttutorbr@gmail.com',
    'Lei aplicavel: Brasil',
    'Foro: Juscimeira, Mato Grosso',
    'Data: 21/06/2026',
  ],
  sections: [
    LegalSection(
      title: 'Servico',
      body:
          'O SIM AI Tutor e um servico educacional com aulas guiadas por inteligencia artificial, destinado a estudantes que desejam estudar com acompanhamento personalizado.',
    ),
    LegalSection(
      title: 'Creditos',
      body:
          'Os creditos permitem o uso de recursos do SIM AI Tutor e podem ser consumidos por uso de IA, incluindo geracao de aulas, explicacoes e recursos associados.',
    ),
    LegalSection(
      title: 'Reembolsos',
      body:
          'Reembolsos, quando aplicaveis, seguirao a legislacao vigente e as regras da plataforma de pagamento utilizada.',
    ),
    LegalSection(
      title: 'Conduta do usuario',
      body:
          'O usuario deve usar o servico de forma licita, respeitosa e compativel com finalidade educacional, sem tentar fraudar contas, pagamentos, creditos ou sistemas do app.',
    ),
    LegalSection(
      title: 'Limitacao de responsabilidade',
      body:
          'O SIM AI Tutor busca apoiar o aprendizado, mas nao substitui professores, responsaveis, instituicoes de ensino ou acompanhamento profissional quando necessario.',
    ),
    LegalSection(
      title: 'Contato',
      body: 'Para suporte ou solicitacoes, entre em contato pelo email smarttutorbr@gmail.com.',
    ),
  ],
);
