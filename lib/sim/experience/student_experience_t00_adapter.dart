import 'dart:async';

import 'package:flutter/foundation.dart';

import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'curriculum_utils.dart';
import 'partial_curriculum_writer.dart';
import 'student_experience_store.dart';
import 'student_experience_types.dart';
import 't00_profile_writer.dart';

class StudentExperienceT00Adapter {
  StudentExperienceT00Adapter({
    required this.service,
    required this.client,
  });

  final StudentLearningStateService service;
  final T00BootstrapClient client;

  Future<FirstCurriculumItem> startT00UntilFirstItem(
    StudentExperienceArgs args,
  ) async {
    final topic = (args.onboarding['objetivo'] ?? '').toString().trim();
    final existing = service.read(args.lessonLocalId)?.curriculum;
    if (existing != null &&
        existing.items.isNotEmpty &&
        normalizeStudyKey(existing.topic) == normalizeStudyKey(topic)) {
      return _firstItemFrom(existing)!;
    }

    final partialItems = <CurriculumItem>[];
    final bootStartedAt = DateTime.now().millisecondsSinceEpoch;

    args.onStage?.call(StudentExperienceRouteStage.profile);
    writeStudentExperienceSnapshot(
      service,
      lessonLocalId: args.lessonLocalId,
      state: StudentExperienceState.t00Streaming,
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.objectiveSubmittedAt,
      {'at': bootStartedAt, 'topic': topic},
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.t00Started,
      {'topic': topic},
    );
    debugPrint('[SIM] T00_STARTED lessonLocalId=${args.lessonLocalId}');

    service.mutate(args.lessonLocalId, (state) {
      return state.copyWith(
        profile: state.profile.copyWith(
          objetivo: topic,
          extra: {
            ...state.profile.extra,
            'lessonLocalId': args.lessonLocalId,
            'bootstrap_engine': 'StudentExperienceEngineV2:T00',
            'bootstrap_status': 'running',
          },
        ),
      );
    });

    // Completer liberado no primeiro item; stream T00 continua em background.
    final completer = Completer<FirstCurriculumItem>();
    unawaited(
      _drainT00Stream(
        args: args,
        topic: topic,
        bootStartedAt: bootStartedAt,
        partialItems: partialItems,
        completer: completer,
      ),
    );
    return completer.future;
  }

  Future<void> _drainT00Stream({
    required StudentExperienceArgs args,
    required String topic,
    required int bootStartedAt,
    required List<CurriculumItem> partialItems,
    required Completer<FirstCurriculumItem> completer,
  }) async {
    FirstCurriculumItem? first;
    try {
      await for (final chunk in client.runBootstrap(
        T00BootstrapRequest(
          lessonLocalId: args.lessonLocalId,
          onboarding: args.onboarding,
          lang: args.idioma,
          academic: args.academic,
        ),
      )) {
        switch (chunk.type) {
          case 't00_profile':
            persistT00ProfileEvent(
              service: service,
              lessonLocalId: args.lessonLocalId,
              event: T00ProfileEvent(
                profile: chunk.payload['profile'] as String?,
                fichaForNext: chunk.payload['ficha_for_next'] is Map
                    ? JsonMap.from(chunk.payload['ficha_for_next'] as Map)
                    : null,
              ),
              data: args.onboarding,
            );
            publishStudentExperienceEvent(
              service,
              args.lessonLocalId,
              StudentExperienceEventType.t00ProfilePartialReceived,
              {'hasFichaForNext': chunk.payload['ficha_for_next'] != null},
            );
            break;

          case 't00_item_partial':
          case 't01_item_partial':
            final raw = chunk.payload['item'];
            if (raw is Map) {
              final result = appendPartialCurriculumItemToState(
                service: service,
                raw: T00StreamItem.fromJson(JsonMap.from(raw)),
                partialItems: partialItems,
                lessonLocalId: args.lessonLocalId,
                objective: topic,
                bootStartedAt: bootStartedAt,
              );
              if (result != null && result.count == 1) {
                final curriculum =
                    service.read(args.lessonLocalId)?.curriculum;
                first = curriculum == null ? null : _firstItemFrom(curriculum);
                debugPrint(
                    '[SIM] T00_FIRST_ITEM_RECEIVED marker=${result.marker}');
                args.onStage?.call(StudentExperienceRouteStage.curriculum);
                writeStudentExperienceSnapshot(
                  service,
                  lessonLocalId: args.lessonLocalId,
                  state: StudentExperienceState.primeiroItemRecebido,
                  startMarker: first?.marker,
                  startItemIndex: first?.itemIndex ?? 0,
                );
                publishStudentExperienceEvent(
                  service,
                  args.lessonLocalId,
                  StudentExperienceEventType.t00FirstItemReceived,
                  {'marker': result.marker},
                );
                // Libera o fast-path; T00 continua em background.
                if (!completer.isCompleted && first != null) {
                  completer.complete(first);
                }
              }
            }
            break;

          case 't00_final':
          case 't01_final':
            final rawCurriculum =
                chunk.payload['curriculo'] ?? chunk.payload['curriculum'];
            final finalItems = normalizeCurriculumItems(rawCurriculum);
            if (finalItems.isNotEmpty) {
              final curriculum = StudentCurriculum(
                topic: topic,
                totalItems: finalItems.length,
                generatedAt: DateTime.now().millisecondsSinceEpoch,
                provisional: false,
                items: finalItems,
              );
              service.mutate(args.lessonLocalId, (state) {
                return state.copyWith(
                  curriculum: curriculum,
                  curriculumStatus: StudentCurriculumStatus(
                    status: CurriculumStatusValue.expanded,
                    expansionStatus: CurriculumStatusValue.expanded,
                    updatedAt: DateTime.now().toIso8601String(),
                    objectiveKey: normalizeStudyKey(topic),
                    initialCount:
                        partialItems.isEmpty ? 1 : partialItems.length,
                    totalCount: finalItems.length,
                  ),
                  profile: state.profile.copyWith(
                    extra: {
                      ...state.profile.extra,
                      'bootstrap_status': 'complete',
                    },
                  ),
                );
              });
              publishStudentExperienceEvent(
                service,
                args.lessonLocalId,
                StudentExperienceEventType.t00FinalCurriculumReceived,
                {'items': finalItems.length},
              );
              first ??= _firstItemFrom(curriculum);
            }
            if (!completer.isCompleted && first != null) {
              completer.complete(first);
            }
            break;

          case 'done':
            // Sinaliza fim do stream; sem payload de currículo.
            if (!completer.isCompleted && first != null) {
              completer.complete(first);
            }
            break;

          case 'fatal':
            throw Exception(chunk.payload['error'] ?? 'erro fatal');
        }
      }

      // Stream encerrou — se ainda não completamos, tenta fallback.
      if (!completer.isCompleted) {
        final fallback = service.read(args.lessonLocalId)?.curriculum;
        final fallbackFirst =
            fallback == null ? null : _firstItemFrom(fallback);
        if (fallbackFirst != null) {
          completer.complete(fallbackFirst);
        } else {
          completer.completeError(Exception('curriculo sem primeiro item'));
        }
      }
    } catch (error) {
      service.mutate(args.lessonLocalId, (state) {
        return state.copyWith(
          profile: state.profile.copyWith(
            extra: {
              ...state.profile.extra,
              'bootstrap_status': 'failed',
            },
          ),
        );
      });
      if (!completer.isCompleted) {
        if (partialItems.isNotEmpty) {
          final partial = service.read(args.lessonLocalId)?.curriculum;
          final partialFirst =
              partial == null ? null : _firstItemFrom(partial);
          if (partialFirst != null) {
            writeStudentExperienceSnapshot(
              service,
              lessonLocalId: args.lessonLocalId,
              state: StudentExperienceState.providerFailedAfterPartial,
              startMarker: partialFirst.marker,
              startItemIndex: partialFirst.itemIndex,
            );
            publishStudentExperienceEvent(
              service,
              args.lessonLocalId,
              StudentExperienceEventType.t00ProviderFailedAfterPartial,
              {'items': partialItems.length, 'error': error.toString()},
            );
            completer.complete(partialFirst);
            return;
          }
        }
        completer.completeError(error);
      }
    }
  }

  FirstCurriculumItem? _firstItemFrom(StudentCurriculum curriculum) {
    if (curriculum.items.isEmpty) return null;
    final item = curriculum.items.first;
    return FirstCurriculumItem(
      curriculum: curriculum,
      item: item,
      itemIndex: 0,
      marker: item.marker,
    );
  }
}
