import 'package:pody/models/models.dart';

const _articlePodcastHostAvatar =
    'https://picsum.photos/seed/article-podcast-host/200/200';
const _articlePodcastCover =
    'https://picsum.photos/seed/article-podcast-cover/800/800';

(Show, Episode) buildArticlePodcastPlayable(ArticlePodcastJobDetail detail) {
  final host = Host(
    id: 'article-podcast-host',
    name: 'Pody News AI',
    avatarUrl: _articlePodcastHostAvatar,
    voiceId: 'kore',
  );
  final episode = Episode(
    id: detail.jobId,
    showId: 'article-podcast-show-${detail.jobId}',
    episodeNumber: 1,
    title: detail.podcastTitle?.trim().isNotEmpty == true
        ? detail.podcastTitle!.trim()
        : 'Podcast bai bao',
    description: detail.podcastDescription?.trim().isNotEmpty == true
        ? detail.podcastDescription!.trim()
        : 'Ban audio tong hop tu cac bai bao da chon.',
    duration: Duration(seconds: detail.durationSeconds ?? 60),
    images: const [_articlePodcastCover],
    audioUrl: detail.audioUrl,
    bubbles: [
      if ((detail.scriptText ?? '').trim().isNotEmpty)
        ChatBubble(
          speakerId: host.id,
          speaker: host.name,
          text: detail.scriptText!.trim(),
          isRight: false,
        ),
    ],
  );
  final show = Show(
    id: 'article-podcast-show-${detail.jobId}',
    title: 'Article Podcast',
    hosts: [host],
    category: 'News',
    imageUrl: _articlePodcastCover,
    episodes: [episode],
    subscriberCount: '0',
    totalEpisodeCount: 1,
    authorId: 'article-service',
  );
  return (show, episode);
}
