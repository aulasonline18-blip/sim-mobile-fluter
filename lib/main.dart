import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sim/billing/payments_functions.dart';
import 'sim/billing/sim_pricing.dart';
import 'sim/billing/sim_server_billing_clients.dart';
import 'sim/external_ai/sim_ai_server_config.dart';
import 'sim/external_ai/sim_server_attachment_client.dart';
import 'sim/classroom/classroom_models.dart';
import 'sim/classroom/lesson_runtime_engine.dart';
import 'sim/lesson/lesson_models.dart';
import 'sim/organism/sim_organism.dart';
import 'sim/organism/sim_organism_controller.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const simSupabaseUrl = 'https://qxzwcldfowyqhyikyxcy.supabase.co';
const simSupabaseAnonKey = 'sb_publishable_-b8arZ8aKEbwU6FEpXAhqg_6bXycrgQ';
const simAuthRedirectUrl = 'sim-mobile://login-callback';
const simServerBaseUrl = 'http://167.179.109.137:3000';
const simLovableBaseUrl = 'https://gemini-aid-pal.lovable.app';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: simSupabaseUrl,
    anonKey: simSupabaseAnonKey,
  );
  runApp(const SimMobileApp());
}
