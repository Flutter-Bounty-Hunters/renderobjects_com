import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

@Import.onWeb('../examples/apple_watch_app_grid/main.dart', show: [#AppleWatchAppGridApp])
import 'embedded_apple_watch_app_grid.imports.dart' deferred as widget;

/// Embeds the [AppleWatchAppGridApp] demo from `examples/apple_watch_app_grid`
/// live inside a Jaspr page via [FlutterEmbedView.deferred].
@client
class EmbeddedAppleWatchAppGrid extends StatelessComponent {
  const EmbeddedAppleWatchAppGrid({super.key});

  @override
  Component build(BuildContext context) {
    return FlutterEmbedView.deferred(
      classes: 'embedded-apple-watch-app-grid flutter-embed',
      constraints: ViewConstraints(minWidth: 300, maxWidth: 400, minHeight: 300, maxHeight: 400),
      loader: div(classes: 'embedded-apple-watch-app-grid-loader', []),
      loadLibrary: widget.loadLibrary(),
      builder: () => widget.AppleWatchAppGridApp(),
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.embedded-apple-watch-app-grid').styles(
      display: Display.flex,
      margin: Spacing.only(top: 1.rem, bottom: 1.5.rem),
      radius: BorderRadius.circular(1.rem),
    ),
    css('.embedded-apple-watch-app-grid-loader').styles(
      width: 300.px,
      height: 300.px,
      margin: Spacing.only(top: 1.rem, bottom: 1.5.rem),
      border: Border.all(width: 2.px, color: const Color('rgba(255,255,255,0.25)')),
      radius: BorderRadius.circular(1.rem),
    ),
  ];
}
