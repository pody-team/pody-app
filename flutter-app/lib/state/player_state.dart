import 'package:flutter/material.dart';
import 'package:pody/models/models.dart';
import 'package:pody/data/mock_data.dart';

/// Global state for the currently playing episode.
class PlayerState extends ChangeNotifier {
  static final PlayerState instance = PlayerState._();

  PlayerState._() {
    // Initialize with the first progress entry
    final progress = MockData.currentUserProgress.isNotEmpty
        ? MockData.currentUserProgress.first
        : null;
    _episode = progress != null
        ? MockData.getEpisodeById(progress.episodeId)
        : MockData.allEpisodes.first;
    _show = progress != null
        ? MockData.getShowById(progress.showId)
        : MockData.shows.first;
    _progress = progress?.progress ?? 0.0;
  }

  Episode? _episode;
  Show? _show;
  double _progress = 0.0;
  bool _isPlaying = true;

  Episode? get episode => _episode;
  Show? get show => _show;
  double get progress => _progress;
  bool get isPlaying => _isPlaying;

  void play({required Show show, required Episode episode}) {
    _show = show;
    _episode = episode;
    _progress = 0.0;
    _isPlaying = true;
    notifyListeners();
  }

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void updateProgress(double value) {
    _progress = value;
    notifyListeners();
  }
}
