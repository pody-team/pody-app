import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:pody/models/models.dart';

List<Episode> sortEpisodesForPlayback(Iterable<Episode> episodes) {
  final sorted = episodes.toList(growable: false);
  sorted.sort((left, right) {
    final leftNumber = left.episodeNumber;
    final rightNumber = right.episodeNumber;
    final leftHasNumber = leftNumber > 0;
    final rightHasNumber = rightNumber > 0;

    if (leftHasNumber && rightHasNumber && leftNumber != rightNumber) {
      return leftNumber.compareTo(rightNumber);
    }
    if (leftHasNumber != rightHasNumber) {
      return leftHasNumber ? -1 : 1;
    }
    return 0;
  });
  return sorted;
}

/// Global state for the currently playing episode.
class PlayerState extends ChangeNotifier {
  static final PlayerState instance = PlayerState._();

  PlayerState._();

  AudioPlayer? _audioPlayer;
  Episode? _episode;
  Show? _show;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  String? _loadedAudioUrl;
  String? _loadedEpisodeId;
  String? _errorMessage;
  double _playbackSpeed = 1.0;
  List<Episode> _queue = const [];
  int _queueIndex = -1;
  String? _activePreviewId;
  _PreviewPlaybackSnapshot? _previewSnapshot;
  bool _isRestoringPreview = false;

  Episode? get episode => _episode;
  Show? get show => _show;
  double get progress {
    final totalMillis = _duration.inMilliseconds;
    if (totalMillis <= 0) {
      return 0.0;
    }
    return (_position.inMilliseconds / totalMillis).clamp(0.0, 1.0);
  }

  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get hasAudio =>
      (_episode?.audioUrl?.trim().isNotEmpty ?? false) && _audioPlayer != null;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get errorMessage => _errorMessage;
  double get playbackSpeed => _playbackSpeed;
  bool get hasPrevious => _queueIndex > 0;
  bool get hasNext => _queueIndex >= 0 && _queueIndex < _queue.length - 1;
  List<Episode> get queue => List.unmodifiable(_queue);
  int get currentQueueIndex => _queueIndex;
  String? get activePreviewId => _activePreviewId;
  bool get isPreviewPlaying => _activePreviewId != null && _isPlaying;
  bool get isPreviewBuffering => _activePreviewId != null && _isBuffering;
  bool get isPreviewActive => _activePreviewId != null;

  Future<void> play({
    required Show show,
    required Episode episode,
    bool autoplay = true,
  }) async {
    await _finishPreviewIfNeeded(restorePlayback: false);
    final previousEpisodeId = _episode?.id;
    _show = show;
    _episode = episode;
    _errorMessage = null;

    final rawAudioUrl = episode.audioUrl?.trim() ?? '';
    if (rawAudioUrl.isEmpty) {
      await _audioPlayer?.stop();
      _position = Duration.zero;
      _duration = episode.duration;
      _isPlaying = false;
      _isBuffering = false;
      _loadedAudioUrl = null;
      _loadedEpisodeId = null;
      _queue = const [];
      _queueIndex = -1;
      notifyListeners();
      return;
    }

    notifyListeners();

    try {
      final player = _ensureAudioPlayer();
      final audioUrl = _normalizeAudioUrl(rawAudioUrl);
      final queue = _buildQueue(show: show, currentEpisode: episode);
      _queue = queue.episodes;
      _queueIndex = queue.currentIndex;
      final shouldReload =
          _loadedAudioUrl != audioUrl || _loadedEpisodeId != episode.id;

      if (shouldReload) {
        _isBuffering = true;
        _position = Duration.zero;
        notifyListeners();
        await player.setAudioSources(
          [
            for (final queueEpisode in _queue)
              _buildEpisodeAudioSource(show: show, episode: queueEpisode),
          ],
          initialIndex: _queueIndex,
          initialPosition: Duration.zero,
        );
        _loadedAudioUrl = audioUrl;
        _loadedEpisodeId = episode.id;
      } else if (previousEpisodeId != episode.id) {
        _position = player.position;
      }
      if (autoplay) {
        await player.play();
      }
    } catch (error) {
      _errorMessage = 'Khong the phat audio luc nay.';
      _isPlaying = false;
      _isBuffering = false;
      notifyListeners();
    }
  }

  String _normalizeAudioUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return value;
    }
    return uri.toString();
  }

  Future<void> togglePlayPause() async {
    var player = _audioPlayer;
    final audioUrl = _episode?.audioUrl?.trim() ?? '';
    if (audioUrl.isEmpty) {
      return;
    }
    if (player == null) {
      final show = _show;
      final episode = _episode;
      if (show == null || episode == null) {
        return;
      }
      await play(show: show, episode: episode);
      player = _audioPlayer;
      if (player == null) {
        return;
      }
    }
    if (_isPlaying) {
      await player.pause();
      return;
    }
    await player.play();
  }

  Future<void> seekToFraction(double value) async {
    final player = _audioPlayer;
    if (player == null || _duration.inMilliseconds <= 0) {
      return;
    }
    final targetMillis = (_duration.inMilliseconds * value).round();
    await player.seek(Duration(milliseconds: targetMillis));
  }

  Future<void> seekToPosition(Duration position) async {
    var player = _audioPlayer;
    if (player == null) {
      final show = _show;
      final episode = _episode;
      if (show == null || episode == null) {
        return;
      }
      await play(show: show, episode: episode, autoplay: false);
      player = _audioPlayer;
      if (player == null) {
        return;
      }
    }

    final totalDuration = _duration.inMilliseconds > 0
        ? _duration
        : _episode?.duration ?? Duration.zero;
    final clamped = position < Duration.zero
        ? Duration.zero
        : position > totalDuration
        ? totalDuration
        : position;
    await player.seek(clamped);
  }

  Future<void> seekRelative(Duration offset) async {
    final player = _audioPlayer;
    if (player == null) {
      return;
    }
    final target = _position + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > _duration
        ? _duration
        : target;
    await player.seek(clamped);
  }

  Future<void> cyclePlaybackSpeed() async {
    final nextSpeed = switch (_playbackSpeed) {
      1.0 => 1.5,
      1.5 => 2.0,
      _ => 1.0,
    };
    _playbackSpeed = nextSpeed;
    final player = _audioPlayer;
    if (player != null) {
      await player.setSpeed(nextSpeed);
    }
    notifyListeners();
  }

  Future<void> skipToPrevious() async {
    final player = _audioPlayer;
    if (player == null || !hasPrevious) {
      return;
    }
    await player.seekToPrevious();
  }

  Future<void> skipToNext() async {
    final player = _audioPlayer;
    if (player == null || !hasNext) {
      return;
    }
    await player.seekToNext();
  }

  Future<void> playQueueEpisodeAt(int index) async {
    final player = _audioPlayer;
    if (player == null || index < 0 || index >= _queue.length) {
      return;
    }
    await player.seek(Duration.zero, index: index);
  }

  Future<void> playPreview({
    required String previewId,
    required String title,
    required String audioUrl,
  }) async {
    final player = _ensureAudioPlayer();
    final normalizedAudioUrl = _normalizeAudioUrl(audioUrl);
    final isSamePreview =
        _activePreviewId == previewId && _loadedAudioUrl == normalizedAudioUrl;

    if (_activePreviewId == null) {
      _previewSnapshot = _capturePreviewSnapshot();
    }

    _activePreviewId = previewId;
    _errorMessage = null;
    _show = null;
    _episode = null;
    _queue = const [];
    _queueIndex = -1;
    _loadedEpisodeId = null;
    _loadedAudioUrl = normalizedAudioUrl;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isBuffering = true;
    notifyListeners();

    if (!isSamePreview) {
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(normalizedAudioUrl),
          tag: MediaItem(
            id: 'voice-preview-$previewId',
            title: 'Nghe thử: $title',
            artist: 'Pody AI Voice',
          ),
        ),
      );
    }

    await player.seek(Duration.zero);
    await player.play();
  }

  Future<void> stopPreview() async {
    await _finishPreviewIfNeeded(restorePlayback: true);
  }

  Future<void> dismissPlayer() async {
    if (_activePreviewId != null) {
      _errorMessage = null;
      await _finishPreviewIfNeeded(restorePlayback: false);
      return;
    }

    await _audioPlayer?.stop();
    _show = null;
    _episode = null;
    _queue = const [];
    _queueIndex = -1;
    _loadedAudioUrl = null;
    _loadedEpisodeId = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
    _isBuffering = false;
    _errorMessage = null;
    notifyListeners();
  }

  AudioPlayer _ensureAudioPlayer() {
    final existing = _audioPlayer;
    if (existing != null) {
      return existing;
    }

    final player = AudioPlayer();
    player.positionStream.listen((value) {
      _position = value;
      notifyListeners();
    });
    player.durationStream.listen((value) {
      _duration = value ?? _episode?.duration ?? Duration.zero;
      notifyListeners();
    });
    player.playerStateStream.listen((value) {
      _isPlaying = value.playing;
      _isBuffering =
          value.processingState == ProcessingState.loading ||
          value.processingState == ProcessingState.buffering;
      if (value.processingState == ProcessingState.completed) {
        _isPlaying = false;
        if (_activePreviewId != null) {
          unawaited(_finishPreviewIfNeeded(restorePlayback: true));
        }
      }
      notifyListeners();
    });
    player.currentIndexStream.listen((value) {
      if (value == null || value < 0 || value >= _queue.length) {
        return;
      }
      _queueIndex = value;
      _episode = _queue[value];
      _loadedEpisodeId = _episode?.id;
      _loadedAudioUrl = _episode?.audioUrl?.trim();
      notifyListeners();
    });
    player.setSpeed(_playbackSpeed);
    _audioPlayer = player;
    return player;
  }

  _PlayerQueue _buildQueue({
    required Show show,
    required Episode currentEpisode,
  }) {
    final mergedEpisodes = <Episode>[];
    var hasCurrentEpisode = false;

    for (final episode in show.episodes) {
      if (episode.id == currentEpisode.id) {
        mergedEpisodes.add(currentEpisode);
        hasCurrentEpisode = true;
      } else {
        mergedEpisodes.add(episode);
      }
    }

    if (!hasCurrentEpisode) {
      mergedEpisodes.add(currentEpisode);
    }

    final playableEpisodes = sortEpisodesForPlayback(mergedEpisodes)
        .where((episode) => (episode.audioUrl?.trim().isNotEmpty ?? false))
        .toList(growable: false);

    final currentIndex = playableEpisodes.indexWhere(
      (episode) => episode.id == currentEpisode.id,
    );

    return _PlayerQueue(
      episodes: playableEpisodes,
      currentIndex: currentIndex < 0 ? 0 : currentIndex,
    );
  }

  AudioSource _buildEpisodeAudioSource({
    required Show show,
    required Episode episode,
  }) {
    return AudioSource.uri(
      Uri.parse(_normalizeAudioUrl(episode.audioUrl!.trim())),
      tag: MediaItem(
        id: episode.id,
        album: show.title,
        title: episode.title,
        artist: show.hostsLabel,
        artUri: Uri.tryParse(
          episode.images.isNotEmpty ? episode.images.first : show.imageUrl,
        ),
        duration: episode.duration,
      ),
    );
  }

  _PreviewPlaybackSnapshot? _capturePreviewSnapshot() {
    final show = _show;
    final episode = _episode;
    if (show == null || episode == null || _audioPlayer == null) {
      return null;
    }
    return _PreviewPlaybackSnapshot(
      show: show,
      episode: episode,
      queue: List<Episode>.from(_queue),
      queueIndex: _queueIndex,
      position: _position,
      wasPlaying: _isPlaying,
    );
  }

  Future<void> _finishPreviewIfNeeded({required bool restorePlayback}) async {
    if (_activePreviewId == null || _isRestoringPreview) {
      return;
    }

    _isRestoringPreview = true;
    final player = _audioPlayer;
    final snapshot = _previewSnapshot;
    _activePreviewId = null;
    _previewSnapshot = null;

    try {
      if (player != null) {
        await player.pause();
      }

      if (!restorePlayback || snapshot == null) {
        _show = null;
        _episode = null;
        _queue = const [];
        _queueIndex = -1;
        _loadedAudioUrl = null;
        _loadedEpisodeId = null;
        _position = Duration.zero;
        _duration = Duration.zero;
        _isPlaying = false;
        _isBuffering = false;
        notifyListeners();
        return;
      }

      _show = snapshot.show;
      _episode = snapshot.episode;
      _queue = snapshot.queue;
      _queueIndex = snapshot.queueIndex;
      _loadedEpisodeId = snapshot.episode.id;
      _loadedAudioUrl = snapshot.episode.audioUrl?.trim();
      _position = snapshot.position;
      _duration = snapshot.episode.duration;
      _isBuffering = true;
      notifyListeners();

      if (player != null) {
        await player.setAudioSources(
          [
            for (final queueEpisode in snapshot.queue)
              _buildEpisodeAudioSource(
                show: snapshot.show,
                episode: queueEpisode,
              ),
          ],
          initialIndex: snapshot.queueIndex,
          initialPosition: snapshot.position,
        );
        if (snapshot.wasPlaying) {
          await player.play();
        }
      }

      _isBuffering = false;
      notifyListeners();
    } finally {
      _isRestoringPreview = false;
    }
  }
}

class _PlayerQueue {
  const _PlayerQueue({required this.episodes, required this.currentIndex});

  final List<Episode> episodes;
  final int currentIndex;
}

class _PreviewPlaybackSnapshot {
  const _PreviewPlaybackSnapshot({
    required this.show,
    required this.episode,
    required this.queue,
    required this.queueIndex,
    required this.position,
    required this.wasPlaying,
  });

  final Show show;
  final Episode episode;
  final List<Episode> queue;
  final int queueIndex;
  final Duration position;
  final bool wasPlaying;
}
