import 'package:flutter/widgets.dart';
import 'article_service.dart';

class ArticleScope extends InheritedWidget {
  const ArticleScope({
    required this.service,
    required super.child,
    super.key,
  });

  final ArticleApiService service;

  static ArticleApiService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ArticleScope>();
    assert(scope != null, 'ArticleScope not found in widget tree.');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(ArticleScope oldWidget) {
    return oldWidget.service != service;
  }
}
