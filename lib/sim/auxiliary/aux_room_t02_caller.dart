import '../lesson/lesson_models.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'student_aux_addons.dart';

class AuxRoomT02Payload {
  const AuxRoomT02Payload({
    required this.auxMode,
    required this.signal,
    required this.marker,
    required this.item,
    required this.itemIdx,
    required this.stableLang,
    required this.academicLevel,
    required this.preferredName,
    required this.notes,
    required this.auxAddonReference,
  });

  final AuxRoomMode auxMode;
  final DecisionSignal signal;
  final String marker;
  final String item;
  final int? itemIdx;
  final String stableLang;
  final String academicLevel;
  final String preferredName;
  final String notes;
  final String auxAddonReference;
}

class AuxRoomCallResult {
  const AuxRoomCallResult.aborted({
    required this.reason,
    required this.payload,
  })  : aborted = true,
        conteudo = null;

  const AuxRoomCallResult.completed({
    required this.payload,
    required this.conteudo,
  })  : aborted = false,
        reason = null;

  final bool aborted;
  final String? reason;
  final AuxRoomT02Payload payload;
  final LessonContent? conteudo;
}

class AuxRoomT02Caller {
  const AuxRoomT02Caller({
    required this.client,
    this.auxRoomsEnabled = true,
    this.reviewRoomEnabled = true,
    this.recoveryRoomEnabled = true,
  });

  final T02LessonClient client;
  final bool auxRoomsEnabled;
  final bool reviewRoomEnabled;
  final bool recoveryRoomEnabled;

  AuxRoomT02Payload buildPayload({
    required String lessonLocalId,
    required AuxRoomMode mode,
    required AuxRoomProfile profile,
    required String marker,
    required String item,
    required DecisionSignal signal,
    int? itemIdx,
  }) {
    return AuxRoomT02Payload(
      auxMode: mode,
      signal: signal,
      marker: marker,
      item: item,
      itemIdx: itemIdx,
      stableLang: profile.stableLang ?? '',
      academicLevel: profile.academicLevel ?? '',
      preferredName: profile.preferredName ?? '',
      notes: profile.notes ?? '',
      auxAddonReference: getAuxRoomAddonReference(mode),
    );
  }

  Future<AuxRoomCallResult> call({
    required String lessonLocalId,
    required AuxRoomMode mode,
    required AuxRoomProfile profile,
    required String marker,
    required String item,
    required DecisionSignal signal,
    int? itemIdx,
    bool confirmEnabled = false,
  }) async {
    final payload = buildPayload(
      lessonLocalId: lessonLocalId,
      mode: mode,
      profile: profile,
      marker: marker,
      item: item,
      signal: signal,
      itemIdx: itemIdx,
    );
    final modeFlag = switch (mode) {
      AuxRoomMode.review => reviewRoomEnabled || auxRoomsEnabled,
      AuxRoomMode.recovery => recoveryRoomEnabled || auxRoomsEnabled,
      AuxRoomMode.doubt => auxRoomsEnabled,
    };
    if (!modeFlag) {
      return AuxRoomCallResult.aborted(
        reason: 'feature flag off',
        payload: payload,
      );
    }
    if (!confirmEnabled) {
      return AuxRoomCallResult.aborted(
        reason: 'missing confirmEnabled',
        payload: payload,
      );
    }
    if (payload.auxAddonReference.isEmpty) {
      return AuxRoomCallResult.aborted(reason: 'empty addon', payload: payload);
    }
    if (payload.item.trim().isEmpty) {
      return AuxRoomCallResult.aborted(reason: 'empty item', payload: payload);
    }

    final material = await client.auxiliaryRoom(
      T02LessonRequest(
        lessonLocalId: lessonLocalId,
        item: payload.item,
        lang: payload.stableLang.isEmpty ? 'Portuguese' : payload.stableLang,
        academic: payload.academicLevel.isEmpty
            ? 'ensino_medio'
            : payload.academicLevel,
        layer: LessonLayer.l1,
        mode: mode.name,
        errCount: 0,
        history: const [],
        marker: payload.marker.isEmpty ? null : payload.marker,
        profile: profile.toJson(),
        addendum: payload.auxAddonReference,
      ),
    );
    return AuxRoomCallResult.completed(
      payload: payload,
      conteudo: LessonContent(
        explanation: material.explanation,
        question: material.question,
        options: material.options,
        correctAnswer: material.correctAnswer,
        whyCorrect: material.whyCorrect,
        whyWrong: material.whyWrong,
      ),
    );
  }
}
