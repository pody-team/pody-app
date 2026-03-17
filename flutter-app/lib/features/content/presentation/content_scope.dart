import 'package:flutter/widgets.dart';

import '../data/content_repository.dart';

class ContentScope extends InheritedWidget {
  const ContentScope({
    required this.repository,
    required super.child,
    super.key,
  });

  final ContentRepository repository;

  static ContentRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ContentScope>();
    assert(scope != null, 'ContentScope not found in widget tree.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(ContentScope oldWidget) {
    return oldWidget.repository != repository;
  }
}
