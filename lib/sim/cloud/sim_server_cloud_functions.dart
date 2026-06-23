import 'dart:convert';

import '../external_ai/sim_ai_server_config.dart';
import '../external_ai/sim_http_transport.dart';
import '../state/student_learning_state.dart';
import 'cloud_functions.dart';
import 'supabase_client_contract.dart';

class SimServerCloudFunctions implements StudentStateCloudFunctions {
  SimServerCloudFunctions({
    required this.config,
    SimHttpTransport? transport,
    this.persistPath = '/api/student-state/persist',
    this.listPath = '/api/student-state/list',
    this.summariesPath = '/api/student-state/summaries',
    this.getPath = '/api/student-state/get',
    this.deletePath = '/api/student-state/delete',
    this.timeout = const Duration(seconds: 45),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String persistPath;
  final String listPath;
  final String summariesPath;
  final String getPath;
  final String deletePath;
  final Duration timeout;

  @override
  Future<PersistStudentStateResult> persistStudentState(
    PersistStudentStateInput input,
    SupabaseSession session,
  ) async {
    final json = await _post(persistPath, session, input.toJson());
    if (json['rejected'] == true && json['remoteState'] is Map) {
      return PersistStudentStateResult.rejectedRegression(
        remoteState: StudentLearningState.fromJson(
          JsonMap.from(json['remoteState'] as Map),
        ),
        remoteHighWaterMark:
            (json['remoteHighWaterMark'] as num?)?.toInt() ?? 0,
        remoteUpdatedAt: json['remoteUpdatedAt']?.toString(),
      );
    }
    return PersistStudentStateResult.accepted(
      lessonLocalId: (json['lessonLocalId'] ?? input.lessonLocalId).toString(),
      highWaterMark:
          (json['highWaterMark'] as num?)?.toInt() ?? input.clientScore,
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? input.schemaVersion,
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  @override
  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    await _post(deletePath, session, {'lessonLocalId': lessonLocalId});
  }

  @override
  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    final json = await _post(getPath, session, {
      'lessonLocalId': lessonLocalId,
    });
    if (json['state'] == null) return null;
    return _row(JsonMap.from(json));
  }

  @override
  Future<List<StudentStateRow>> listStudentStates(
    SupabaseSession session,
  ) async {
    final json = await _post(listPath, session, const {});
    final rows = json['rows'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((row) => _row(JsonMap.from(row))).toList();
  }

  @override
  Future<List<StudentStateSummaryRow>> listStudentStateSummaries(
    SupabaseSession session,
  ) async {
    final json = await _post(summariesPath, session, const {});
    final rows = json['rows'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => _summary(JsonMap.from(row)))
        .toList();
  }

  Future<JsonMap> _post(
    String path,
    SupabaseSession session,
    Object body,
  ) async {
    final response = await transport.postJson(
      config.uri(path),
      headers: {
        ...await config.jsonHeaders(),
        ...const AuthMiddlewareContract().bearerHeaders(session),
      },
      body: body,
      timeout: timeout,
    );
    if (!response.ok) {
      throw SimExternalAiException(
        response.body,
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? JsonMap.from(decoded) : <String, dynamic>{};
  }

  StudentStateRow _row(JsonMap json) {
    final state = json['state'] is Map
        ? StudentLearningState.fromJson(JsonMap.from(json['state'] as Map))
        : null;
    return StudentStateRow(
      lessonLocalId: (json['lessonLocalId'] ?? state?.lessonLocalId ?? '')
          .toString(),
      state: state,
      highWaterMark: (json['highWaterMark'] as num?)?.toInt() ?? 0,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  StudentStateSummaryRow _summary(JsonMap json) => StudentStateSummaryRow(
    lessonLocalId: (json['lessonLocalId'] ?? '').toString(),
    lessonCloudId: json['lessonCloudId']?.toString(),
    tema: (json['tema'] ?? '').toString(),
    idioma: (json['idioma'] ?? '').toString(),
    nivel: (json['nivel'] ?? '').toString(),
    createdAt: json['createdAt']?.toString(),
    updatedAt: json['updatedAt']?.toString(),
    totalItens: (json['totalItens'] as num?)?.toInt() ?? 0,
    itemIdx: (json['itemIdx'] as num?)?.toInt() ?? 0,
    layer: (json['layer'] as num?)?.toInt() ?? 1,
    concluidos: (json['concluidos'] as num?)?.toInt() ?? 0,
    finalizada: json['finalizada'] == true,
    markerAtual: json['markerAtual']?.toString(),
    deleted: json['deleted'] == true,
  );
}
