import 'package:flutter/material.dart';
import '../../sim/config/sim_environment.dart';
const simSupabaseUrl = 'https://qxzwcldfowyqhyikyxcy.supabase.co';

// JetBrains Mono font family name â€” used instead of kMono
// so TextStyle objects can remain const.
const String kMono = 'JetBrains Mono';
const simSupabaseAnonKey = 'sb_publishable_-b8arZ8aKEbwU6FEpXAhqg_6bXycrgQ';
const simAuthRedirectUrl = 'sim-mobile://login-callback';
const simApiBaseUrl = SimEnvironment.apiBaseUrl;

const simDark = Color(0xFF111827); // foreground / primary
const simMid = Color(0xFF374151); // success / primary_glow
const simLight = Color(0xFFF3F4F6); // secondary / muted / accent
const simCard = Color(0xFFF9FAFB); // card background
const simMuted = Color(0xFF6B7280); // muted_foreground / warn
const simBorder = Color(0xFFD1D5DB); // border / input
const simDestructive = Color(0xFF000000); // destructive (preto)
const simDestructiveFg = Color(0xFFFFFFFF); // destructive_fg
const simSuccess = Color(0xFF374151); // success = #374151 (cinza-escuro)
const simWarn = Color(0xFF6B7280); // warn = #6B7280 (cinza-mÃ©dio)

// gradient_primary: LinearGradient 135Â° #FFFFFF â†’ #F3F4F6 ("papel premium")
const simGradientPrimary = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
);
// gradient_bg: LinearGradient 180Â° #FFFFFF â†’ #F3F4F6
const simGradientBg = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
);

// shadow helpers
const simShadowGlow = [
  BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(0, 1), blurRadius: 0),
  BoxShadow(
    color: Color(0x2E111827),
    offset: Offset(0, 6),
    blurRadius: 18,
    spreadRadius: -10,
  ),
];
const simShadowFloat = [
  BoxShadow(
    color: Color(0x40111827),
    offset: Offset(0, 10),
    blurRadius: 30,
    spreadRadius: -18,
  ),
];

const maxFreeText = 1500;
const maxAttachments = 3;
const maxAttachmentBytes = 10 * 1024 * 1024;
const minExtractedChars = 20;
const audioNotSupportedMessage =
    'Ãudio ainda nÃ£o estÃ¡ disponÃ­vel. Envie texto, foto ou arquivo.';
const videoNotSupportedMessage =
    'VÃ­deo ainda nÃ£o estÃ¡ disponÃ­vel. Envie texto, foto ou arquivo.';
const objectiveRequiredMessage =
    'Campo obrigatÃ³rio. Escreva o que vocÃª quer estudar.';
const objectiveRequiredWithAttachmentMessage =
    'Você anexou um arquivo. Agora escreva o que deseja estudar com ele.';



