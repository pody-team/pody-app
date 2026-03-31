import '../domain/ai_models.dart';
import 'ai_remote_data_source.dart';

class AIRepository {
  AIRepository(this._remoteDataSource);

  final AIRemoteDataSource _remoteDataSource;

  Future<List<AIVoiceProfile>> listVoiceProfiles() {
    return _remoteDataSource.listVoiceProfiles();
  }

  Future<AIChatThread> createThread({
    required String prompt,
  }) {
    return _remoteDataSource.createThread(prompt: prompt);
  }

  Future<List<AIChatThreadSummary>> listThreads({int limit = 30}) {
    return _remoteDataSource.listThreads(limit: limit);
  }

  Future<List<AIProductionPlanSummary>> listDrafts({int limit = 50}) {
    return _remoteDataSource.listDrafts(limit: limit);
  }

  Future<AIChatThread> getThread(String threadId) {
    return _remoteDataSource.getThread(threadId);
  }

  Future<AIProductionPlan> getDraft(String draftId) {
    return _remoteDataSource.getDraft(draftId);
  }

  Future<AIGenerationJob> createShowFromPlan(String planId) {
    return _remoteDataSource.createShowFromPlan(planId);
  }

  Future<AIChatThread> addThreadMessage({
    required String threadId,
    required String message,
  }) {
    return _remoteDataSource.addThreadMessage(
      threadId: threadId,
      message: message,
    );
  }

  Stream<AIChatStreamEvent> streamCreateThread({
    required String prompt,
  }) {
    return _remoteDataSource.streamCreateThread(prompt: prompt);
  }

  Stream<AIChatStreamEvent> streamAddThreadMessage({
    required String threadId,
    required String message,
  }) {
    return _remoteDataSource.streamAddThreadMessage(
      threadId: threadId,
      message: message,
    );
  }
}
