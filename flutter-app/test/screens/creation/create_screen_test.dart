import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/features/ai/data/ai_remote_data_source.dart';
import 'package:pody/features/ai/data/ai_repository.dart';
import 'package:pody/features/ai/domain/ai_models.dart';
import 'package:pody/features/ai/presentation/ai_scope.dart';
import 'package:pody/features/auth/application/auth_controller.dart';
import 'package:pody/features/auth/data/auth_local_data_source.dart';
import 'package:pody/features/auth/data/auth_remote_data_source.dart';
import 'package:pody/features/auth/data/auth_repository.dart';
import 'package:pody/features/auth/data/google_auth_data_source.dart';
import 'package:pody/features/auth/domain/auth_session.dart';
import 'package:pody/features/auth/domain/auth_user.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/creation/create_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'create screen does not show Production Plan title and keeps new chat button visible but disabled on empty state',
    (WidgetTester tester) async {
      final aiRemote = _FakeAIRemoteDataSource(
        ApiClient(baseUrl: 'http://localhost:8080'),
      );
      final authController = await _buildAuthenticatedController();

      await tester.pumpWidget(_buildScreen(authController, aiRemote));
      await tester.pumpAndSettle();

      expect(find.text('Production Plan'), findsNothing);
      expect(find.byTooltip('New chat'), findsOneWidget);
      expect(find.text('New'), findsNothing);
      expect(find.text('Hôm nay bạn muốn tạo show gì?'), findsOneWidget);
    },
  );

  testWidgets(
    'new button resets current thread',
    (WidgetTester tester) async {
      final aiRemote = _FakeAIRemoteDataSource(
        ApiClient(baseUrl: 'http://localhost:8080'),
      );
      final authController = await _buildAuthenticatedController();

      await tester.pumpWidget(_buildScreen(authController, aiRemote));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(_createScreenPrompts.first));
      await tester.tap(find.text(_createScreenPrompts.first));
      await tester.pumpAndSettle();

      expect(aiRemote.createThreadCalls, 1);
      expect(find.byTooltip('New chat'), findsOneWidget);
      expect(find.text('Assistant reply 1'), findsOneWidget);

      await tester.tap(find.byTooltip('New chat'));
      await tester.pumpAndSettle();
      await tester.pump();

      expect(find.byTooltip('New chat'), findsOneWidget);
      expect(find.text('Assistant reply 1'), findsNothing);
      expect(find.text(_createScreenPrompts.first), findsOneWidget);
    },
  );
}

const _createScreenPrompts = <String>[
  'Tao mot show tin cong nghe moi sang cho founder va product manager.',
  'Len concept show ke chuyen lich su Viet Nam theo goc nhin gan gui, de nghe.',
  'Giup toi xay mot podcast hoc tieng Anh bang tinh huong cong so hang ngay.',
];

Widget _buildScreen(
  AuthController authController,
  _FakeAIRemoteDataSource aiRemote,
) {
  return MaterialApp(
    home: AIScope(
      repository: AIRepository(aiRemote),
      child: AuthScope(controller: authController, child: const CreateScreen()),
    ),
  );
}

Future<AuthController> _buildAuthenticatedController() async {
  SharedPreferences.setMockInitialValues({});
  final controller = AuthController(
    AuthRepository(
      remoteDataSource: _FakeAuthRemoteDataSource(
        ApiClient(baseUrl: 'http://localhost:8080'),
      ),
      localDataSource: AuthLocalDataSource(),
      googleAuthDataSource: _FakeGoogleAuthDataSource(),
    ),
  );
  await controller.signIn(email: 'creator@pody.vn', password: 'password-123');
  return controller;
}

class _FakeAIRemoteDataSource extends AIRemoteDataSource {
  _FakeAIRemoteDataSource(super.apiClient);

  int createThreadCalls = 0;
  int addThreadMessageCalls = 0;
  bool holdNextAddThread = false;

  AIChatThread? _currentThread;
  Completer<AIChatThread>? _pendingAddThreadCompleter;

  @override
  Future<AIChatThread> createThread({required String prompt}) async {
    createThreadCalls += 1;
    final thread = _buildThread(
      threadId: 'thread-$createThreadCalls',
      prompt: prompt,
      assistantReply: 'Assistant reply $createThreadCalls',
    );
    _currentThread = thread;
    return thread;
  }

  @override
  Future<AIChatThread> addThreadMessage({
    required String threadId,
    required String message,
  }) {
    addThreadMessageCalls += 1;
    if (holdNextAddThread) {
      _pendingAddThreadCompleter = Completer<AIChatThread>();
      return _pendingAddThreadCompleter!.future;
    }

    final thread = _buildFollowUpThread(
      threadId: threadId,
      prompt: message,
      assistantReply: 'Assistant refined reply',
    );
    _currentThread = thread;
    return Future.value(thread);
  }

  @override
  Stream<AIChatStreamEvent> streamCreateThread({required String prompt}) async* {
    createThreadCalls += 1;
    final thread = _buildThread(
      threadId: 'thread-$createThreadCalls',
      prompt: prompt,
      assistantReply: 'Assistant reply $createThreadCalls',
    );
    _currentThread = thread;
    yield AIChatStreamEvent.status('Dang phan tich brief...');
    yield AIChatStreamEvent.assistantDelta('Assistant ');
    yield AIChatStreamEvent.assistantDelta('reply $createThreadCalls');
    yield AIChatStreamEvent.thread(thread);
    yield AIChatStreamEvent.done(threadId: thread.id);
  }

  @override
  Stream<AIChatStreamEvent> streamAddThreadMessage({
    required String threadId,
    required String message,
  }) async* {
    addThreadMessageCalls += 1;
    yield AIChatStreamEvent.status('Dang refine plan...');
    final thread = holdNextAddThread
        ? await (_pendingAddThreadCompleter = Completer<AIChatThread>()).future
        : _buildFollowUpThread(
            threadId: threadId,
            prompt: message,
            assistantReply: 'Assistant refined reply',
          );
    _currentThread = thread;
    yield AIChatStreamEvent.thread(thread);
    yield AIChatStreamEvent.done(threadId: thread.id);
  }

  void completePendingAddThread() {
    final completer = _pendingAddThreadCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }

    holdNextAddThread = false;
    final current = _currentThread!;
    final thread = _buildFollowUpThread(
      threadId: current.id,
      prompt: 'Refine this plan',
      assistantReply: 'Assistant refined reply',
    );
    _currentThread = thread;
    completer.complete(thread);
  }

  AIChatThread _buildThread({
    required String threadId,
    required String prompt,
    required String assistantReply,
  }) {
    final now = DateTime(2026, 3, 17, 18);
    return AIChatThread(
      id: threadId,
      title: 'AI thread $threadId',
      status: 'active',
      createdAt: now,
      updatedAt: now,
      messages: [
        AIChatMessage(
          id: '$threadId-user-1',
          role: 'user',
          text: prompt,
          createdAt: now,
        ),
        AIChatMessage(
          id: '$threadId-assistant-1',
          role: 'assistant',
          text: assistantReply,
          createdAt: now,
        ),
      ],
      currentPlan: _buildPlan(threadId, now),
    );
  }

  AIChatThread _buildFollowUpThread({
    required String threadId,
    required String prompt,
    required String assistantReply,
  }) {
    final current =
        _currentThread ??
        _buildThread(
          threadId: threadId,
          prompt: prompt,
          assistantReply: assistantReply,
        );
    final now = current.updatedAt.add(const Duration(minutes: 1));
    return AIChatThread(
      id: current.id,
      title: current.title,
      status: current.status,
      createdAt: current.createdAt,
      updatedAt: now,
      messages: [
        ...current.messages,
        AIChatMessage(
          id: '$threadId-user-next',
          role: 'user',
          text: prompt,
          createdAt: now,
        ),
        AIChatMessage(
          id: '$threadId-assistant-next',
          role: 'assistant',
          text: assistantReply,
          createdAt: now,
        ),
      ],
      currentPlan: current.currentPlan,
    );
  }

  AIProductionPlan _buildPlan(String threadId, DateTime now) {
    return AIProductionPlan(
      id: 'plan-$threadId',
      threadId: threadId,
      status: 'completed',
      seriesTitle: 'AI Builder Lab',
      seriesDescription: 'Plan generated for testing.',
      targetLanguageCode: 'vi',
      showDraft: const AIShowDraft(
        slug: 'ai-builder-lab',
        title: 'AI Builder Lab',
        description: 'Plan generated for testing.',
        primaryCategory: 'Cong nghe',
        hosts: [AIHostDraft(displayName: 'Nova', role: 'host')],
        categories: ['Cong nghe'],
        tags: ['ai'],
        languageCode: 'vi',
        contentType: 'podcast',
      ),
      episodes: const [
        AIEpisodeDraft(
          episodeNumber: 1,
          title: 'Tap 1',
          description: 'Episode draft',
          estimatedDurationSeconds: 900,
          status: 'draft',
        ),
      ],
      tags: const ['ai'],
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _FakeGoogleAuthDataSource implements GoogleAuthDataSource {
  @override
  Future<String> signIn() async => 'fake-id-token';

  @override
  Future<void> signOut() async {}
}

class _FakeAuthRemoteDataSource extends AuthRemoteDataSource {
  _FakeAuthRemoteDataSource(super.apiClient);

  static final AuthUser _user = AuthUser(
    id: 'user-1',
    email: 'creator@pody.vn',
    displayName: 'Creator',
    status: 'active',
  );

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final now = DateTime.now().toUtc();
    return AuthSession(
      user: _user,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessTokenExpiresAt: now.add(const Duration(hours: 1)),
      refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      tokenType: 'Bearer',
    );
  }
}
