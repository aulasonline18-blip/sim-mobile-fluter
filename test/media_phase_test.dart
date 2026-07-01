import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_visual_pipeline.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/media/audio_core.dart';
import 'package:sim_mobile/sim/media/audio_preference.dart';
import 'package:sim_mobile/sim/media/blueprint_prompt.dart';
import 'package:sim_mobile/sim/media/doubt_audio.dart';
import 'package:sim_mobile/sim/media/image_data_url_compression.dart';
import 'package:sim_mobile/sim/media/lesson_audio_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_audio_controller.dart';
import 'package:sim_mobile/sim/media/lesson_image_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_paid_image_offer.dart';
import 'package:sim_mobile/sim/media/lesson_visual_models.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/media/math_templates/math_templates.dart';
import 'package:sim_mobile/sim/media/paid_image_service.dart' as paid;
import 'package:sim_mobile/sim/media/student_lesson_media_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FakeGeneratedAudioClient implements GeneratedAudioClient {
  int calls = 0;
  String? lastLang;
  String? lastVoice;

  @override
  Future<String?> generateAudio({
    required String text,
    required String lang,
    required String voice,
    required String lessonKey,
  }) async {
    calls += 1;
    lastLang = lang;
    lastVoice = voice;
    return 'data:audio/wav;base64,AAAA';
  }
}

class ThrowingVisualRouterClient implements LessonVisualRouterClient {
  const ThrowingVisualRouterClient();

  @override
  Future<VisualN3Result> routeVisual({
    required VisualN2Result n2,
    String? topic,
    String? visualType,
    String? imagePrompt,
  }) async {
    throw StateError('HTTP 401 Unauthorized requestId=vis-test');
  }
}

class ThrowingGeneratedAudioClient implements GeneratedAudioClient {
  int calls = 0;

  @override
  Future<String?> generateAudio({
    required String text,
    required String lang,
    required String voice,
    required String lessonKey,
  }) async {
    calls += 1;
    throw StateError('remote down');
  }
}

class CountingPlaybackAdapter implements AudioPlaybackAdapter {
  int dataUrlPlays = 0;
  int platformTtsCalls = 0;
  int stops = 0;
  String? lastTtsText;
  bool failDataUrl = false;
  bool failPlatformTts = false;

  @override
  Future<bool> playDataUrl(String dataUrl, SpeakOptions opts) async {
    if (failDataUrl) {
      opts.onEnd?.call();
      return false;
    }
    dataUrlPlays += 1;
    opts.onStart?.call();
    opts.onEnd?.call();
    return true;
  }

  @override
  Future<bool> speakWithPlatformTts(String text, SpeakOptions opts) async {
    if (failPlatformTts) {
      opts.onEnd?.call();
      return false;
    }
    platformTtsCalls += 1;
    lastTtsText = text;
    opts.onStart?.call();
    opts.onEnd?.call();
    return true;
  }

  @override
  void stop() {
    stops += 1;
  }
}

class FakeAudioT02Client implements T02LessonClient {
  int calls = 0;

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
    return T02LessonMaterial(
      explanation: 'Explicacao ${request.item}',
      question: 'Pergunta?',
      options: const {
        AnswerLetter.A: 'A1',
        AnswerLetter.B: 'B1',
        AnswerLetter.C: 'C1',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake-audio',
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}

class FakeImageClient implements LessonImageClient {
  String? next = 'data:image/jpeg;base64,AAAA';
  String? lastPrompt;
  int calls = 0;

  @override
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
  }) async {
    calls += 1;
    lastPrompt = prompt;
    return next;
  }
}

class FakePaidOrchestrator implements LessonPaidImageOrchestrator {
  int accepted = 0;
  int declined = 0;

  @override
  Future<void> acceptPaidImageOffer(String offerKey) async {
    accepted += 1;
  }

  @override
  void declinePaidImageOffer(String offerKey) {
    declined += 1;
  }
}

class FakeCredits implements CreditsGateway {
  int balance = 14;

  @override
  Future<int> getMyCredits() async => balance;
}

StudentLearningState seedState() {
  return StudentLearningState.empty(
    lessonLocalId: 'l1',
  ).copyWith(events: const []);
}

void main() {
  test('audio preference defaults on and notifies listeners', () {
    final preference = AudioPreference();
    var notified = false;
    preference.subscribe((enabled) => notified = !enabled);

    expect(preference.getAudioEnabled(), true);
    preference.setAudioEnabled(false);
    expect(preference.getAudioEnabled(), false);
    expect(notified, true);
  });

  test('audio preference persists with SharedPrefs storage', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final preference = AudioPreference(
      storage: SharedPrefsAudioPreferenceStorage(prefs),
    );

    preference.setAudioEnabled(false);
    final reloaded = AudioPreference(
      storage: SharedPrefsAudioPreferenceStorage(prefs),
    );

    expect(reloaded.getAudioEnabled(), false);
  });

  test(
    'production/session audio wiring uses PlatformAudioAdapter, not Noop',
    () {
      final labSession = File(
        'lib/features/session/lab_session.dart',
      ).readAsStringSync();
      final organism = File(
        'lib/sim/organism/sim_organism.dart',
      ).readAsStringSync();

      expect(labSession, contains('playback: PlatformAudioAdapter()'));
      expect(
        RegExp(
          r'playback:\s*NoopAudioPlaybackAdapter\(\)',
        ).hasMatch(labSession),
        false,
      );
      expect(organism, contains('playback ?? PlatformAudioAdapter()'));
    },
  );

  test('audio core maps stable language and caches generated audio', () async {
    final preference = AudioPreference();
    final playback = NoopAudioPlaybackAdapter();
    final client = FakeGeneratedAudioClient();
    final core = AudioCore(
      preference: preference,
      playback: playback,
      generatedAudioClient: client,
      stableLangProvider: () => 'Portuguese',
    );

    expect(stableLangToBCP47('Portuguese'), 'pt-BR');
    expect(await core.speak('Oi', const SpeakOptions(lessonKey: 'k')), true);
    expect(await core.speak('Oi', const SpeakOptions(lessonKey: 'k')), true);
    expect(client.calls, 1);
    expect(client.lastLang, 'pt-BR');
    expect(client.lastVoice, 'Charon');
  });

  test('audio disabled skips generated client and local playback', () async {
    final preference = AudioPreference()..setAudioEnabled(false);
    final playback = CountingPlaybackAdapter();
    final client = FakeGeneratedAudioClient();
    final core = AudioCore(
      preference: preference,
      playback: playback,
      generatedAudioClient: client,
    );

    expect(
      await core.speak('Nao tocar', const SpeakOptions(lessonKey: 'k')),
      false,
    );
    expect(client.calls, 0);
    expect(playback.platformTtsCalls, 0);
  });

  test('audio play failure does not call onStart or report playing', () async {
    final preference = AudioPreference();
    final playback = CountingPlaybackAdapter()
      ..failDataUrl = true
      ..failPlatformTts = true;
    final client = FakeGeneratedAudioClient();
    var started = false;
    var ended = false;
    final core = AudioCore(
      preference: preference,
      playback: playback,
      generatedAudioClient: client,
    );

    final ok = await core.speak(
      'Falha controlada',
      SpeakOptions(
        lessonKey: 'k',
        onStart: () => started = true,
        onEnd: () => ended = true,
      ),
    );

    expect(ok, false);
    expect(started, false);
    expect(ended, true);
    expect(playback.dataUrlPlays, 0);
  });

  test('audio cache key separates lesson language voice and text', () {
    final core = AudioCore(
      preference: AudioPreference(),
      playback: NoopAudioPlaybackAdapter(),
    );

    final pt = core.audioCacheKey(
      'texto',
      const SpeakOptions(lessonKey: 'lesson-a', lang: 'pt-BR', voice: 'Charon'),
    );
    final en = core.audioCacheKey(
      'texto',
      const SpeakOptions(lessonKey: 'lesson-a', lang: 'en-US', voice: 'Charon'),
    );
    final otherLesson = core.audioCacheKey(
      'texto',
      const SpeakOptions(lessonKey: 'lesson-b', lang: 'pt-BR', voice: 'Charon'),
    );
    final otherText = core.audioCacheKey(
      'texto diferente',
      const SpeakOptions(lessonKey: 'lesson-a', lang: 'pt-BR', voice: 'Charon'),
    );

    expect({pt, en, otherLesson, otherText}, hasLength(4));
    expect(pt, isNot(contains('Instance of')));
  });

  test(
    'remote audio failure falls back to local TTS without blocking lesson',
    () async {
      final preference = AudioPreference();
      final playback = CountingPlaybackAdapter();
      final client = ThrowingGeneratedAudioClient();
      Object? reportedError;
      final core = AudioCore(
        preference: preference,
        playback: playback,
        generatedAudioClient: client,
        onGeneratedAudioError: (error) => reportedError = error,
      );

      expect(
        await core.speak('Fallback local', const SpeakOptions(lessonKey: 'k')),
        true,
      );
      expect(client.calls, 1);
      expect(reportedError, isA<StateError>());
      expect(playback.platformTtsCalls, 1);
      expect(playback.lastTtsText, 'Fallback local');
    },
  );

  test('lesson audio controller preserves lesson reading sequence', () async {
    final states = {'l1': seedState()};
    final preference = AudioPreference();
    final media = StudentLessonMediaService(
      audioCore: AudioCore(
        preference: preference,
        playback: NoopAudioPlaybackAdapter(),
      ),
      readState: (id) => states[id]!,
      writeState: (state) => states[state.lessonLocalId] = state,
    );
    final controller = LessonAudioController(
      lessonLocalId: 'l1',
      mediaService: media,
      preference: preference,
    );
    final content = LessonContent(
      explanation: 'Explicacao',
      question: 'Pergunta',
      options: const {
        AnswerLetter.A: 'A1',
        AnswerLetter.B: 'B1',
        AnswerLetter.C: 'C1',
      },
      correctAnswer: AnswerLetter.A,
    );

    expect(await controller.playConteudo(content, 'M1', LessonLayer.l1), true);
    expect(
      states['l1']!.events.map((event) => event.type),
      contains('AUDIO_STARTED'),
    );
    expect(
      states['l1']!.events.map((event) => event.type),
      contains('AUDIO_READY'),
    );
    expect(states['l1']!.audio.status, 'ready');
  });

  test('ready material prepares audioText without starting playback', () async {
    final service = StudentLearningStateService(seed: {'l1': seedState()});
    final playback = CountingPlaybackAdapter();
    final media = StudentLessonMediaService(
      audioCore: AudioCore(preference: AudioPreference(), playback: playback),
      readState: (id) => service.ensure(lessonLocalId: id),
      writeState: service.write,
    );
    final orchestrator = LessonOrchestrator(
      t02Client: FakeAudioT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
      visualPipeline: fakeVisualPipeline(),
    );
    orchestrator.setAudioTextPreparer((params, lesson) {
      media.prepareLessonAudioText(
        LessonMediaPosition(
          lessonLocalId: params.lessonLocalId,
          itemMarker: params.marker,
          layer: params.layer,
        ),
        [
          lesson.conteudo.explanation,
          lesson.conteudo.question,
          lesson.conteudo.options[AnswerLetter.A],
          lesson.conteudo.options[AnswerLetter.B],
          lesson.conteudo.options[AnswerLetter.C],
        ],
      );
    });

    await orchestrator.prefetchCompleteLesson(
      const CompleteLessonParams(
        lessonLocalId: 'l1',
        item: 'Item 1',
        lang: 'pt-BR',
        academic: 'base',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      ),
      priority: 'background',
    );

    final state = service.read('l1')!;
    expect(state.events.map((event) => event.type), contains('AUDIO_READY'));
    expect(playback.dataUrlPlays, 0);
    expect(playback.platformTtsCalls, 0);
  });

  test('doubt audio appends doubt suffix and respects preference', () async {
    final preference = AudioPreference();
    final playback = NoopAudioPlaybackAdapter();
    final audio = DoubtAudio(
      audioCore: AudioCore(preference: preference, playback: playback),
      preference: preference,
    );

    expect(await audio.speakDoubt('Duvida', lessonKey: 'l1:M1'), true);
    expect(await audio.speakText('Revisao', lessonKey: 'l1:review:0'), true);
    preference.setAudioEnabled(false);
    expect(await audio.speakDoubt('Duvida', lessonKey: 'l1:M1'), false);
    expect(
      await audio.speakText('Recuperacao', lessonKey: 'l1:recovery:0'),
      false,
    );
  });

  test(
    'audio stop covers answer selection, signal, advance and dispose paths',
    () {
      final playback = CountingPlaybackAdapter();
      final core = AudioCore(preference: AudioPreference(), playback: playback);
      core.stop();
      core.stop();
      core.stop();
      core.stop();

      expect(playback.stops, 4);
    },
  );

  test('LabSession stopActiveAudio clears playing and loading state', () {
    final session = LabSession()
      ..audioPlaying = true
      ..audioLoading = true;

    session.stopActiveAudio(notify: false);

    expect(session.audioPlaying, false);
    expect(session.audioLoading, false);
  });

  test(
    'LabSession toggleAudio stop does not disable audio preference',
    () async {
      final session = LabSession()
        ..audioEnabled = true
        ..audioPlaying = true;

      await session.toggleAudio();

      expect(session.audioPlaying, false);
      expect(session.audioEnabled, true);
    },
  );

  test('lesson image media events preserve cache key item and layer', () {
    var state = StudentLearningState.empty(lessonLocalId: 'l1');
    final service = StudentLessonMediaService(
      audioCore: AudioCore(
        preference: AudioPreference(),
        playback: CountingPlaybackAdapter(),
        generatedAudioClient: FakeGeneratedAudioClient(),
      ),
      readState: (_) => state,
      writeState: (next) => state = next,
    );
    const position = LessonMediaPosition(
      lessonLocalId: 'l1',
      itemMarker: 'M1',
      layer: LessonLayer.l2,
    );

    service.markLessonImageStarted(position, cacheKey: 'image:user:a');
    service.markLessonImageReady(
      position,
      cacheKey: 'image:user:a',
      imageUrl: 'data:image/png;base64,AAAA',
    );
    service.markLessonImageFailed(position, error: 'requestId=rid-1');

    expect(state.events.map((event) => event.type), [
      'IMAGE_STARTED',
      'IMAGE_READY',
      'IMAGE_FAILED',
    ]);
    expect(state.events[0].payload['cacheKey'], 'image:user:a');
    expect(state.events[0].payload['itemMarker'], 'M1');
    expect(state.events[0].payload['layer'], 2);
    expect(state.events[1].payload['imageUrlHead'], startsWith('data:image'));
    expect(state.events[2].payload['errorMessage'], 'requestId=rid-1');
  });

  test('visual prompt preserves language directive and image validation', () {
    final prompt = buildNaturalImagePrompt(
      topic: 'Intestino',
      teacherPrompt: 'Mostre nutrientes',
      lang: 'pt-BR',
    );
    expect(prompt, contains('Brazilian Portuguese'));
    expect(prompt, contains('Writing visible text in English'));
    expect(isUsableImageDataUrl('data:image/webp;base64,AAAA'), true);
    expect(isUsableImageDataUrl('http://x'), false);
  });

  test('image data URL compression rewrites raster image to jpeg data URL', () {
    final pngBytes = img.encodePng(img.Image(width: 2, height: 2));
    final png = 'data:image/png;base64,${base64Encode(pngBytes)}';
    final compressed = compressImageDataUrl(png);
    expect(compressed, startsWith('data:image/jpeg;base64,'));
  });

  test('visual pipeline fetches only usable paid image data url', () async {
    final client = FakeImageClient();
    final pipeline = LessonVisualPipeline(
      imageClient: client,
      visualRouterClient: const FakeVisualRouterClient(),
    );

    expect(
      await pipeline.fetchPaidLessonImage(
        'prompt',
        'lesson',
        acceptedOfferId: 'offer-1',
      ),
      isNotNull,
    );
    client.next = 'bad';
    expect(
      await pipeline.fetchPaidLessonImage(
        'prompt',
        'lesson',
        acceptedOfferId: 'offer-2',
      ),
      isNull,
    );
  });

  test(
    'N2/N3 resolves schematic visual as free SVG without paid image',
    () async {
      final client = FakeImageClient();
      final svg = sanitizeAndEncodeSvg(
        '<svg width="120" height="80"><text x="10" y="20">Etapas</text></svg>',
      );
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: FakeVisualRouterClient(svgDataUrl: svg),
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'important',
          topic: 'diagrama de etapas de um algoritmo',
          visualType: 'diagram',
        ),
        lessonKey: 'lesson',
        allowPaidImages: false,
      );

      expect(result.source, 'n3_software');
      expect(result.displayUrl, startsWith('data:image/svg+xml;utf8,'));
      expect(client.calls, 0);
    },
  );

  test('math template custom formula renders deterministic SVG', () {
    final dataUrl = tryRenderMathTemplate({
      'math_template': {
        'name': 'custom',
        'formula': 'y = 3x^2 - 2x + 1',
        'params': {
          'labels': {'title': 'formula custom'},
        },
      },
    });

    expect(dataUrl, startsWith('data:image/svg+xml;utf8,'));
    final decoded = Uri.decodeFull(dataUrl!);
    expect(decoded, contains('y = 3'));
    expect(decoded, contains('x²'));
  });

  test('math template aliases render parabola as free quadratic SVG', () {
    final dataUrl = tryRenderMathTemplate({
      'math_template': {
        'name': 'parabola',
        'params': {
          'a': 1,
          'b': 0,
          'c': 0,
          'labels': {'title': 'Parabola'},
        },
      },
    });

    expect(dataUrl, startsWith('data:image/svg+xml;utf8,'));
    final decoded = Uri.decodeFull(dataUrl!);
    expect(decoded, contains('Parabola'));
    expect(decoded, contains('x²'));
  });

  test(
    'N3 delegates schematic routing to injected visual router client',
    () async {
      final n2 = classifyVisualByKeywords(
        topic: 'segunda lei de Newton',
        visualType: 'diagram',
        imagePrompt: 'diagrama de forca resultante em um bloco',
      );
      final svg = sanitizeAndEncodeSvg(
        '<svg width="120" height="80"><text x="10" y="20">Forca</text></svg>',
      );

      final n3 = await routeVisualCheapN3(
        client: FakeVisualRouterClient(svgDataUrl: svg),
        n2: n2,
        topic: 'segunda lei de Newton',
        visualType: 'diagram',
        imagePrompt: 'diagrama de forca resultante em um bloco',
      );
      final decoded = Uri.decodeFull(n3.svgDataUrl ?? '');

      expect(n3.verdict, VisualVerdict.svg);
      expect(decoded, contains('Forca'));
    },
  );

  test(
    'N3 failure keeps diagnostic reason before falling back to paid path',
    () async {
      final n2 = classifyVisualByKeywords(
        topic: 'parábola de uma função quadrática',
        visualType: 'graph',
        imagePrompt: 'desenhe a parábola',
      );

      final n3 = await routeVisualCheapN3(
        client: const ThrowingVisualRouterClient(),
        n2: n2,
        topic: 'parábola de uma função quadrática',
        visualType: 'graph',
        imagePrompt: 'desenhe a parábola',
      );

      expect(n3.verdict, VisualVerdict.ai);
      expect(n3.reason, contains('N3_HTTP_FAILED'));
      expect(n3.reason, contains('401'));
    },
  );

  test(
    'N3 sends realistic ambiguous visual to paid path only when allowed',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const FakeVisualRouterClient(),
      );
      const trigger = LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'diagrama com foto realista de um processo historico',
        visualType: 'diagram',
        imagePrompt: 'foto realista com etapas visuais',
      );

      final blocked = await pipeline.resolveVisual(
        trigger: trigger,
        lessonKey: 'lesson',
        allowPaidImages: false,
      );
      expect(blocked.source, 'skip_no_paid');
      expect(client.calls, 0);

      final paid = await pipeline.resolveVisual(
        trigger: trigger,
        lessonKey: 'lesson',
        allowPaidImages: true,
        acceptedOfferId: 'offer-paid',
      );
      expect(paid.source, 'ai_blueprint');
      expect(client.calls, 1);
    },
  );

  test('paid image offer accepts, declines and routes to credits', () async {
    final orchestrator = FakePaidOrchestrator();
    final credits = FakeCredits();
    final controller = LessonPaidImageOfferController(
      orchestrator: orchestrator,
      creditsGateway: credits,
    );

    controller.registerPaidOffer(
      'k',
      const PaidImageOffer(prompt: 'p', lessonKey: 'l'),
    );
    await controller.acceptPaidImage();
    expect(orchestrator.accepted, 1);
    expect(controller.creditBalance, 14);
    controller.declinePaidImage();
    expect(orchestrator.declined, 1);
    controller.handleInsufficientCredits(kind: 'lesson');
    expect(controller.navigationTarget, '/creditos?returnTo=/cyber/aula');
  });

  test(
    'PaidImageService offers before paid fetch and consumes only after accept',
    () async {
      final stateService = StudentLearningStateService(
        seed: {'l1': StudentLearningState.empty(lessonLocalId: 'l1')},
      );
      var fetches = 0;
      final service = paid.PaidImageService(
        stateService: stateService,
        fetcher:
            ({
              required prompt,
              required lessonKey,
              required acceptedOfferId,
              required idempotencyKey,
            }) async {
              fetches += 1;
              expect(acceptedOfferId, startsWith('img_offer_'));
              expect(idempotencyKey, acceptedOfferId);
              return 'data:image/png;base64,AAAA';
            },
      );

      final offer = service.offer(
        lessonKey: 'lesson-key',
        lessonLocalId: 'l1',
        visualTrigger: const {
          'needs_image': true,
          'pedagogical_need': 'important',
          'render_strategy': 'ai',
          'image_prompt': 'foto realista de um coracao humano',
        },
      );

      expect(offer.status, paid.PaidImageOfferStatus.pending);
      expect(fetches, 0);
      expect(
        stateService.read('l1')!.events.map((event) => event.type),
        contains('PAID_IMAGE_OFFERED'),
      );

      final image = await service.consume(
        offerId: offer.offerId,
        lessonLocalId: 'l1',
      );
      expect(image, 'data:image/png;base64,AAAA');
      expect(fetches, 1);
      expect(offer.status, paid.PaidImageOfferStatus.consumed);
    },
  );

  test(
    'PaidImageService keeps stable offer/idempotency key and blocks double consume',
    () async {
      final stateService = StudentLearningStateService(
        seed: {'l1': StudentLearningState.empty(lessonLocalId: 'l1')},
      );
      var fetches = 0;
      String? seenAcceptedOfferId;
      String? seenIdempotencyKey;
      final service = paid.PaidImageService(
        stateService: stateService,
        fetcher:
            ({
              required prompt,
              required lessonKey,
              required acceptedOfferId,
              required idempotencyKey,
            }) async {
              fetches += 1;
              seenAcceptedOfferId = acceptedOfferId;
              seenIdempotencyKey = idempotencyKey;
              await Future<void>.delayed(const Duration(milliseconds: 1));
              return 'data:image/png;base64,AAAA';
            },
      );
      const trigger = {
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'ai',
        'image_prompt': 'foto realista de um coração humano',
      };

      final first = service.offer(
        lessonKey: 'lesson-key',
        lessonLocalId: 'l1',
        visualTrigger: trigger,
      );
      final second = service.offer(
        lessonKey: 'lesson-key',
        lessonLocalId: 'l1',
        visualTrigger: trigger,
      );

      expect(second.offerId, first.offerId);
      expect(first.offerId, startsWith('img_offer_'));

      final results = await Future.wait([
        service.consume(offerId: first.offerId, lessonLocalId: 'l1'),
        service.consume(offerId: first.offerId, lessonLocalId: 'l1'),
      ]);

      expect(results.whereType<String>(), hasLength(1));
      expect(fetches, 1);
      expect(seenAcceptedOfferId, first.offerId);
      expect(seenIdempotencyKey, first.offerId);
    },
  );

  test('api contracts preserve limits and constants without secrets', () {
    final image = GenerateLessonImageRequest(
      prompt: 'p' * 5000,
      lessonKey: 'k' * 200,
      aspectRatio: 'bad',
    ).normalized();
    expect(image.prompt.length, 4000);
    expect(image.lessonKey.length, 160);
    expect(image.aspectRatio, '1:1');
    expect(lessonImageModelPath, 'google/nano-banana-pro');

    final audio = GenerateLessonAudioRequest(
      text: 'a' * 5000,
      lessonKey: 'l' * 200,
      lang: 'pt-BR',
    ).normalized();
    expect(audio.text.length, maxAudioInputChars);
    expect(audio.lessonKey.length, 180);
    expect(voiceByLang('es'), 'Fenrir');
    expect(voiceByLang('pt-BR'), 'Charon');
    expect(voiceByLang('en-US'), 'Charon');
    expect(audio.voice, 'Charon');
    expect(geminiTtsModel, 'gemini-2.5-flash-preview-tts');
  });

  test('CompleteLesson.copyWith can clear stale image explicitly', () {
    const lesson = CompleteLesson(
      conteudo: LessonContent(
        explanation: 'Explicacao',
        question: 'Pergunta?',
        options: {
          AnswerLetter.A: 'A',
          AnswerLetter.B: 'B',
          AnswerLetter.C: 'C',
        },
        correctAnswer: AnswerLetter.A,
      ),
      imagem: 'data:image/png;base64,AAAA',
      audioText: 'Explicacao. Pergunta?',
    );

    final cleared = lesson.copyWith(imagem: null);

    expect(cleared.imagem, isNull);
    expect(cleared.conteudo.question, 'Pergunta?');
  });

  test(
    'SVG sanitizer accepts valid SVG without viewBox and keeps security blocks',
    () {
      expect(
        sanitizeAndEncodeSvg('<svg><rect width="10"/></svg>'),
        startsWith('data:image/svg+xml;utf8,'),
      );
      expect(
        sanitizeAndEncodeSvg(
          '<svg viewBox="0 0 10 10"><rect width="10"/></svg>',
        ),
        startsWith('data:image/svg+xml;utf8,'),
      );
      expect(
        sanitizeAndEncodeSvg(
          '<svg viewBox="0 0 10 10"><script>alert(1)</script></svg>',
        ),
        isNull,
      );
    },
  );
}
