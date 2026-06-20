import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'embedded_counter.dart';

/// Proof that multiple independent Flutter app instances can run on the same
/// Jaspr page: renders two [EmbeddedCounter]s side by side, each backed by
/// its own Flutter engine/view, incrementable independently of one another.
@client
class FlutterMultiViewDemo extends StatelessComponent {
  const FlutterMultiViewDemo({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'flutter-multi-view-demo', [
      const EmbeddedCounter(),
      const EmbeddedCounter(),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.flutter-multi-view-demo').styles(
      display: Display.flex,
      flexDirection: FlexDirection.row,
      flexWrap: FlexWrap.wrap,
      gap: Gap.all(1.5.rem),
    ),
  ];
}
