import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
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
import 'package:sim_mobile/sim/media/paid_image_service.dart' as paid;
import 'package:sim_mobile/sim/media/student_lesson_media_service.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FakeGeneratedAudioClient implements GeneratedAudioClient {
  int calls = 0;

  @override
  Future<String?> generateAudio({
    required String text,
    required String lang,
    required String voice,
    required String lessonKey,
  }) async {
    calls += 1;
    return 'data:audio/wav;base64,AAAA';
  }
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
  });

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

  test('doubt audio appends doubt suffix and respects preference', () async {
    final preference = AudioPreference();
    final playback = NoopAudioPlaybackAdapter();
    final audio = DoubtAudio(
      audioCore: AudioCore(preference: preference, playback: playback),
      preference: preference,
    );

    expect(await audio.speakDoubt('Duvida', lessonKey: 'l1:M1'), true);
    preference.setAudioEnabled(false);
    expect(await audio.speakDoubt('Duvida', lessonKey: 'l1:M1'), false);
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
    final pipeline = LessonVisualPipeline(imageClient: client);

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
      final pipeline = LessonVisualPipeline(imageClient: client);

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

  test(
    'N3 sends realistic ambiguous visual to paid path only when allowed',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(imageClient: client);
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
    expect(geminiTtsModel, 'gemini-2.5-flash-preview-tts');
  });
}
