import 'package:flutter/widgets.dart';
import 'package:pody/features/content/domain/content_models.dart';

import 'content_show_detail_screen.dart';

class CreatorShowDetailScreen extends StatelessWidget {
  const CreatorShowDetailScreen({
    required this.showId,
    this.initialSummary,
    super.key,
  });

  final String showId;
  final ContentShowSummary? initialSummary;

  @override
  Widget build(BuildContext context) {
    return ContentShowDetailScreen(
      showId: showId,
      initialSummary: initialSummary,
      source: ContentShowDetailSource.creator,
    );
  }
}
