import 'package:flutter/widgets.dart';

import '../data/ai_repository.dart';

class AIScope extends InheritedWidget {
  const AIScope({required this.repository, required super.child, super.key});

  final AIRepository repository;

  static AIRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AIScope>();
    assert(scope != null, 'AIScope not found in widget tree.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(AIScope oldWidget) {
    return oldWidget.repository != repository;
  }
}
