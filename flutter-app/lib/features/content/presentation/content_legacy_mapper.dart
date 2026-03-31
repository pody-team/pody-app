import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/models/models.dart';

Show mapContentShowToLegacy(
  ContentShowDetail show,
  List<ContentEpisodeSummary> episodes,
) {
  return Show(
    id: show.id,
    title: show.title,
    hosts: [
      for (final host in show.hosts)
        Host(
          id: host.id,
          name: host.displayName,
          avatarUrl: host.avatarUrl,
          voiceId: host.voiceProfileId,
          role: host.role,
        ),
    ],
    category: show.primaryCategory,
    imageUrl: show.coverImageUrl,
    episodes: episodes.map(mapContentEpisodeSummaryToLegacy).toList(),
    subscriberCount: show.formattedSubscriberCount,
    totalEpisodeCount: show.totalEpisodeCount,
    authorId: show.owner.id,
  );
}

Show mapContentShowToLegacyWithEpisodeDetails(
  ContentShowDetail show,
  List<ContentEpisodeSummary> orderedEpisodes,
  Map<String, ContentEpisodeDetail> detailsById,
) {
  return Show(
    id: show.id,
    title: show.title,
    hosts: [
      for (final host in show.hosts)
        Host(
          id: host.id,
          name: host.displayName,
          avatarUrl: host.avatarUrl,
          voiceId: host.voiceProfileId,
          role: host.role,
        ),
    ],
    category: show.primaryCategory,
    imageUrl: show.coverImageUrl,
    episodes: [
      for (final episode in orderedEpisodes)
        if (detailsById.containsKey(episode.id))
          mapContentEpisodeDetailToLegacy(
            detailsById[episode.id]!,
            hosts: show.hosts,
          )
        else
          mapContentEpisodeSummaryToLegacy(episode),
    ],
    subscriberCount: show.formattedSubscriberCount,
    totalEpisodeCount: show.totalEpisodeCount,
    authorId: show.owner.id,
  );
}

Episode mapContentEpisodeSummaryToLegacy(ContentEpisodeSummary episode) {
  return Episode(
    id: episode.id,
    showId: episode.showId,
    episodeNumber: episode.episodeNumber,
    title: episode.title,
    description: episode.description,
    duration: Duration(seconds: episode.durationSeconds),
    images: [episode.coverImageUrl],
  );
}

Episode mapContentEpisodeDetailToLegacy(
  ContentEpisodeDetail episode, {
  List<ContentHost> hosts = const [],
}) {
  return Episode(
    id: episode.id,
    showId: episode.showId,
    episodeNumber: episode.episodeNumber,
    title: episode.title,
    description: episode.description,
    duration: Duration(seconds: episode.durationSeconds),
    images: [episode.coverImageUrl],
    audioUrl: episode.audioUrl,
    tags: episode.tags,
    bubbles: _mapTranscriptToBubbles(episode.transcript, hosts: hosts),
    likes: episode.likeCount,
    comments: episode.commentCount,
  );
}

List<ChatBubble> _mapTranscriptToBubbles(
  ContentEpisodeTranscript? transcript, {
  required List<ContentHost> hosts,
}) {
  if (transcript == null) {
    return const [];
  }

  final speakerStates = <String, _TranscriptSpeakerState>{};
  var nextFallbackHostIndex = 0;

  _TranscriptSpeakerState resolveSpeaker(String speakerLabel) {
    final key = speakerLabel.trim().toLowerCase();
    final existing = speakerStates[key];
    if (existing != null) {
      return existing;
    }

    ContentHost? matchedHost;
    var matchedHostIndex = -1;
    for (var i = 0; i < hosts.length; i += 1) {
      if (_normalizeSpeakerName(hosts[i].displayName) ==
          _normalizeSpeakerName(speakerLabel)) {
        matchedHost = hosts[i];
        matchedHostIndex = i;
        break;
      }
    }

    if (matchedHost == null && nextFallbackHostIndex < hosts.length) {
      matchedHostIndex = nextFallbackHostIndex;
      matchedHost = hosts[nextFallbackHostIndex];
      nextFallbackHostIndex += 1;
    }

    final paletteIndex = matchedHostIndex >= 0
        ? matchedHostIndex
        : speakerStates.length;
    final state = _TranscriptSpeakerState(
      speakerId: matchedHost?.id ?? 'speaker-$paletteIndex',
      speakerName: matchedHost?.displayName ?? speakerLabel.trim(),
      isRight: paletteIndex.isEven,
      colorValue: _speakerColorForIndex(paletteIndex),
    );
    speakerStates[key] = state;
    return state;
  }

  final bubbles = <ChatBubble>[
    for (final segment in transcript.segments)
      if (segment.text.trim().isNotEmpty)
        (() {
          final speaker = resolveSpeaker(segment.speaker);
          return ChatBubble(
            speakerId: speaker.speakerId,
            speaker: speaker.speakerName,
            text: segment.text.trim(),
            isRight: speaker.isRight,
            colorValue: speaker.colorValue,
            startSeconds: segment.startSeconds,
            endSeconds: segment.endSeconds,
            words: [
              for (final word in segment.words)
                TranscriptWordCue(
                  startSeconds: word.startSeconds,
                  endSeconds: word.endSeconds,
                  text: word.text,
                ),
            ],
          );
        })(),
  ];

  if (bubbles.isNotEmpty) {
    return bubbles;
  }

  final fallbackText = transcript.text?.trim() ?? '';
  if (fallbackText.isEmpty) {
    return const [];
  }

  final primaryHost = hosts.isEmpty ? null : hosts.first;
  return [
    ChatBubble(
      speakerId: primaryHost?.id ?? 'speaker-0',
      speaker: primaryHost?.displayName ?? 'Transcript',
      text: fallbackText,
      isRight: true,
      colorValue: _speakerColorForIndex(0),
    ),
  ];
}

String _normalizeSpeakerName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

int _speakerColorForIndex(int index) {
  switch (index % 3) {
    case 0:
      return 0xFFFFFFFF;
    case 1:
      return 0xFFCCCCCC;
    default:
      return 0xFFFFD180;
  }
}

class _TranscriptSpeakerState {
  const _TranscriptSpeakerState({
    required this.speakerId,
    required this.speakerName,
    required this.isRight,
    required this.colorValue,
  });

  final String speakerId;
  final String speakerName;
  final bool isRight;
  final int colorValue;
}
