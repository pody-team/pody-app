import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show Headers, ResponseBody;
import 'package:flutter_test/flutter_test.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/ai/data/ai_remote_data_source.dart';
import 'package:pody/features/ai/domain/ai_models.dart';

void main() {
  test(
    'streamCreateThread times out a stalled SSE stream and frees it',
    () async {
      final controller = StreamController<Uint8List>();
      var closed = false;
      addTearDown(() async {
        await controller.close();
      });

      controller.add(
        Uint8List.fromList(
          utf8.encode(
            'event: status\ndata: {"message":"Dang suy nghi","phase":"thinking"}\n\n',
          ),
        ),
      );

      final remote = AIRemoteDataSource(
        _FakeStreamApiClient(
          () async => ResponseBody(
            controller.stream,
            200,
            headers: {
              Headers.contentTypeHeader: ['text/event-stream'],
            },
            onClose: () {
              closed = true;
            },
          ),
        ),
        streamIdleTimeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        remote.streamCreateThread(prompt: 'Tao show moi'),
        emitsInOrder([
          predicate<AIChatStreamEvent>(
            (event) =>
                event.type == AIChatStreamEventType.status &&
                event.phase == 'thinking',
          ),
          emitsError(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              contains('Ket noi toi AI bi gian doan qua lau'),
            ),
          ),
        ]),
      );

      expect(closed, isTrue);
    },
  );
}

class _FakeStreamApiClient extends ApiClient {
  _FakeStreamApiClient(this._openStream)
    : super(baseUrl: 'http://localhost:8080');

  final Future<ResponseBody> Function() _openStream;

  @override
  Future<ResponseBody> openEventStream(
    String path, {
    required String method,
    Map<String, dynamic>? body,
    String? bearerToken,
    bool requiresAuth = false,
  }) {
    return _openStream();
  }
}
