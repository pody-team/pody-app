class PodcastSelectionUpdate {
  const PodcastSelectionUpdate({
    required this.selectedIdsInOrder,
    required this.removedIds,
  });

  final List<int> selectedIdsInOrder;
  final List<int> removedIds;
}

PodcastSelectionUpdate updatePodcastSelection({
  required List<int> selectedIdsInOrder,
  required int articleId,
  required bool isCurrentlySelected,
  int maxArticles = 20,
}) {
  final updatedIds = List<int>.from(selectedIdsInOrder);
  final removedIds = <int>[];

  if (isCurrentlySelected) {
    updatedIds.remove(articleId);
    return PodcastSelectionUpdate(
      selectedIdsInOrder: updatedIds,
      removedIds: removedIds,
    );
  }

  updatedIds.remove(articleId);
  updatedIds.add(articleId);

  while (updatedIds.length > maxArticles) {
    removedIds.add(updatedIds.removeAt(0));
  }

  return PodcastSelectionUpdate(
    selectedIdsInOrder: updatedIds,
    removedIds: removedIds,
  );
}
