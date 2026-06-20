import 'package:jaspr_content/jaspr_content.dart';

import 'author_attribution.dart';

const _headingTags = {'h2', 'h3', 'h4', 'h5', 'h6'};

/// Inserts [AuthorAttribution] just above the first `h2`-or-lower heading of
/// every guide/API/example detail page (e.g. `/guides/layout`) — not on their
/// section overview pages (e.g. `/guides` itself) or any other page.
///
/// Placing it there (rather than right after the first paragraph) avoids
/// splitting two closely related intro paragraphs that some pages have
/// before their first heading.
class AuthorAttributionExtension implements PageExtension {
  const AuthorAttributionExtension();

  @override
  Future<List<Node>> apply(Page page, List<Node> nodes) async {
    if (!_isDetailPage(page)) return nodes;

    final index = nodes.indexWhere((n) => n is ElementNode && _headingTags.contains(n.tag));
    if (index == -1) {
      return [...nodes, ComponentNode(const AuthorAttribution())];
    }

    return [
      ...nodes.take(index),
      ComponentNode(const AuthorAttribution()),
      ...nodes.skip(index),
    ];
  }

  static bool _isDetailPage(Page page) {
    final url = page.url;
    return url.startsWith('/guides/') || url.startsWith('/api/') || url.startsWith('/examples/');
  }
}
