import 'package:flutter_test/flutter_test.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_legacy_mapper.dart';

void main() {
  group('ContentEpisodeDetail transcript parsing', () {
    test('reads transcript payload from episode detail json', () {
      final detail = ContentEpisodeDetail.fromJson({
        'id': 'episode-1',
        'show_id': 'show-1',
        'title': 'Episode title',
        'description': 'Episode description',
        'audio_url': 'https://example.com/audio.wav',
        'cover_image_url': 'https://example.com/cover.jpg',
        'duration_seconds': 138,
        'published_at': '2026-03-30T10:53:23Z',
        'episode_number': 1,
        'tags': ['ai'],
        'like_count': 4,
        'comment_count': 2,
        'transcript': {
          'status': 'completed',
          'language': 'vi',
          'alignment_method': 'mms_fa',
          'asset_url': 'https://example.com/transcript.json',
          'text': 'Atlas: Xin chao',
          'duration_seconds': 138.77,
          'segments': [
            {
              'speaker': 'Atlas',
              'start_seconds': 0.24,
              'end_seconds': 12.5,
              'text': 'Xin chao, day la transcript that.',
            },
          ],
        },
      });

      expect(detail.transcript, isNotNull);
      expect(detail.transcript!.status, 'completed');
      expect(detail.transcript!.alignmentMethod, 'mms_fa');
      expect(detail.transcript!.segments, hasLength(1));
      expect(detail.transcript!.segments.first.speaker, 'Atlas');
    });
  });

  group('mapContentEpisodeDetailToLegacy', () {
    test('maps transcript segments into chat bubbles using show hosts', () {
      final detail = ContentEpisodeDetail(
        id: 'episode-1',
        showId: 'show-1',
        title: 'Episode title',
        description: 'Episode description',
        audioUrl: 'https://example.com/audio.wav',
        coverImageUrl: 'https://example.com/cover.jpg',
        durationSeconds: 138,
        publishedAt: DateTime(2026, 3, 30, 10, 53, 23),
        episodeNumber: 1,
        tags: ['ai'],
        likeCount: 4,
        commentCount: 2,
        transcript: ContentEpisodeTranscript(
          status: 'completed',
          language: 'vi',
          durationSeconds: 138.77,
          segments: [
            ContentTranscriptSegment(
              speaker: 'Atlas',
              startSeconds: 0.24,
              endSeconds: 12.5,
              text: 'Xin chao, toi la Atlas.',
              words: [],
            ),
            ContentTranscriptSegment(
              speaker: 'Mira',
              startSeconds: 12.6,
              endSeconds: 20.1,
              text: 'Va toi la Mira.',
              words: [],
            ),
          ],
        ),
      );
      const hosts = [
        ContentHost(
          id: 'host-1',
          displayName: 'Atlas',
          avatarUrl: 'https://example.com/atlas.jpg',
          role: 'host',
        ),
        ContentHost(
          id: 'host-2',
          displayName: 'Mira',
          avatarUrl: 'https://example.com/mira.jpg',
          role: 'co-host',
        ),
      ];

      final episode = mapContentEpisodeDetailToLegacy(detail, hosts: hosts);

      expect(episode.bubbles, hasLength(2));
      expect(episode.bubbles.first.speakerId, 'host-1');
      expect(episode.bubbles.first.speaker, 'Atlas');
      expect(episode.bubbles.first.isRight, isTrue);
      expect(episode.bubbles[1].speakerId, 'host-2');
      expect(episode.bubbles[1].speaker, 'Mira');
      expect(episode.bubbles[1].isRight, isFalse);
    });

    test('falls back to transcript text when segments are missing', () {
      final detail = ContentEpisodeDetail(
        id: 'episode-2',
        showId: 'show-1',
        title: 'Episode title',
        description: 'Episode description',
        audioUrl: 'https://example.com/audio.wav',
        coverImageUrl: 'https://example.com/cover.jpg',
        durationSeconds: 138,
        publishedAt: DateTime(2026, 3, 30, 10, 53, 23),
        episodeNumber: 2,
        tags: [],
        likeCount: 0,
        commentCount: 0,
        transcript: ContentEpisodeTranscript(
          status: 'completed',
          language: 'vi',
          durationSeconds: 138.77,
          segments: [],
          text: 'Noi dung transcript tong hop.',
        ),
      );
      const hosts = [
        ContentHost(
          id: 'host-1',
          displayName: 'Atlas',
          avatarUrl: 'https://example.com/atlas.jpg',
          role: 'host',
        ),
      ];

      final episode = mapContentEpisodeDetailToLegacy(detail, hosts: hosts);

      expect(episode.bubbles, hasLength(1));
      expect(episode.bubbles.first.speakerId, 'host-1');
      expect(episode.bubbles.first.speaker, 'Atlas');
      expect(episode.bubbles.first.text, 'Noi dung transcript tong hop.');
    });
  });
}
