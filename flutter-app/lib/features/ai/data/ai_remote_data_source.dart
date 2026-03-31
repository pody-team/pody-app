import 'dart:convert';

import 'package:dio/dio.dart' show ResponseBody;
import 'package:pody/core/network/api_client.dart';

import '../domain/ai_models.dart';

class AIRemoteDataSource {
  AIRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AIVoiceProfile>> listVoiceProfiles() async {
    final response = await _apiClient.get(
      '/api/v1/ai/voice-profiles',
      requiresAuth: true,
    );
    final rawProfiles =
        response['voice_profiles'] as List<dynamic>? ?? const [];
    return rawProfiles
        .whereType<Map<String, dynamic>>()
        .map(AIVoiceProfile.fromJson)
        .toList();
  }

  Future<AIChatThread> createThread({
    required String prompt,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/ai/chat-create/threads',
      requiresAuth: true,
      body: {'prompt': prompt},
    );
    return AIChatThread.fromJson(
      (response['thread'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<List<AIChatThreadSummary>> listThreads({int limit = 30}) async {
    final response = await _apiClient.get(
      '/api/v1/ai/chat-create/threads?limit=$limit',
      requiresAuth: true,
    );
    final rawThreads = response['threads'] as List<dynamic>? ?? const [];
    return rawThreads
        .whereType<Map<String, dynamic>>()
        .map(AIChatThreadSummary.fromJson)
        .toList();
  }

  Future<List<AIProductionPlanSummary>> listDrafts({int limit = 50}) async {
    final response = await _apiClient.get(
      '/api/v1/ai/production-plans?limit=$limit',
      requiresAuth: true,
    );
    final rawDrafts = response['drafts'] as List<dynamic>? ?? const [];
    return rawDrafts
        .whereType<Map<String, dynamic>>()
        .map(AIProductionPlanSummary.fromJson)
        .toList();
  }

  Future<AIChatThread> getThread(String threadId) async {
    final response = await _apiClient.get(
      '/api/v1/ai/chat-create/threads/$threadId',
      requiresAuth: true,
    );
    return AIChatThread.fromJson(
      (response['thread'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<AIProductionPlan> getDraft(String draftId) async {
    final response = await _apiClient.get(
      '/api/v1/ai/production-plans/$draftId',
      requiresAuth: true,
    );
    return AIProductionPlan.fromJson(
      (response['draft'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<AIGenerationJob> createShowFromPlan(String planId) async {
    final response = await _apiClient.post(
      '/api/v1/ai/production-plans/$planId/create-show',
      requiresAuth: true,
    );
    return AIGenerationJob.fromJson(
      (response['job'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<AIChatThread> addThreadMessage({
    required String threadId,
    required String message,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/ai/chat-create/threads/$threadId/messages',
      requiresAuth: true,
      body: {'message': message},
    );
    return AIChatThread.fromJson(
      (response['thread'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Stream<AIChatStreamEvent> streamCreateThread({
    required String prompt,
  }) async* {
    final responseBody = await _apiClient.openEventStream(
      '/api/v1/ai/chat-create/threads/stream',
      method: 'POST',
      requiresAuth: true,
      body: {'prompt': prompt},
    );
    yield* _parseSseStream(responseBody);
  }

  Stream<AIChatStreamEvent> streamAddThreadMessage({
    required String threadId,
    required String message,
  }) async* {
    final responseBody = await _apiClient.openEventStream(
      '/api/v1/ai/chat-create/threads/$threadId/messages/stream',
      method: 'POST',
      requiresAuth: true,
      body: {'message': message},
    );
    yield* _parseSseStream(responseBody);
  }

  Stream<AIChatStreamEvent> _parseSseStream(ResponseBody responseBody) async* {
    final lines = utf8.decoder
        .bind(responseBody.stream)
        .transform(const LineSplitter());
    var eventName = 'message';
    final dataLines = <String>[];

    await for (final line in lines) {
      if (line.isEmpty) {
        final event = _buildStreamEvent(eventName, dataLines.join('\n'));
        if (event != null) {
          yield event;
        }
        eventName = 'message';
        dataLines.clear();
        continue;
      }

      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }

    if (dataLines.isNotEmpty) {
      final event = _buildStreamEvent(eventName, dataLines.join('\n'));
      if (event != null) {
        yield event;
      }
    }
  }

  AIChatStreamEvent? _buildStreamEvent(String eventName, String rawData) {
    final payload = rawData.trim().isEmpty
        ? const <String, dynamic>{}
        : (jsonDecode(rawData) as Map<String, dynamic>? ?? const {});

    switch (eventName.trim()) {
      case 'status':
        final phase = _readPayloadNullableString(payload['phase']);
        final tool = _readPayloadNullableString(payload['tool']);
        final debugLabel = tool ?? phase ?? 'status';
        return AIChatStreamEvent.status(
          _readPayloadString(payload['message'], fallback: 'AI dang xu ly...'),
          debugLabel: debugLabel,
        );
      case 'assistant_delta':
        return AIChatStreamEvent.assistantDelta(
          _readPayloadString(payload['text'], fallback: ''),
          debugLabel: 'assistant_delta',
        );
      case 'plan_updated':
        final planJson = payload['plan'] as Map<String, dynamic>? ?? const {};
        return AIChatStreamEvent.planUpdated(
          AIProductionPlan.fromJson(planJson),
          debugLabel: 'plan_updated',
        );
      case 'thread':
        final threadJson =
            payload['thread'] as Map<String, dynamic>? ?? const {};
        return AIChatStreamEvent.thread(
          AIChatThread.fromJson(threadJson),
          debugLabel: 'thread',
        );
      case 'done':
        return AIChatStreamEvent.done(
          threadId: _readPayloadNullableString(payload['thread_id']),
          debugLabel: 'done',
        );
      case 'error':
        return AIChatStreamEvent.error(
          _readPayloadString(payload['message'], fallback: 'AI service gap loi.'),
          debugLabel: 'error',
        );
      default:
        return null;
    }
  }
}

String _readPayloadString(Object? value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

String? _readPayloadNullableString(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}
