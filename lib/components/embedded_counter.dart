import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

@Import.onWeb('../flutter_widgets/counter_widget.dart', show: [#CounterWidget])
import 'embedded_counter.imports.dart' deferred as widget;

/// Embeds one independent Flutter app instance ([CounterWidget]) inside a
/// Jaspr page via [FlutterEmbedView.deferred]. Multiple [EmbeddedCounter]s can
/// be placed on the same page — each mounts its own Flutter engine/view.
class EmbeddedCounter extends StatefulComponent {
  const EmbeddedCounter({super.key});

  @override
  State<EmbeddedCounter> createState() => _EmbeddedCounterState();

  @css
  static List<StyleRule> get styles => [
    css('.embedded-counter').styles(
      display: Display.flex,
      minWidth: 220.px,
      minHeight: 56.px,
    ),
    css('.embedded-counter-loader').styles(
      width: 16.px,
      height: 16.px,
      margin: Spacing.all(0.5.rem),
      border: Border.all(width: 2.px, color: const Color('rgba(255,255,255,0.25)')),
      radius: BorderRadius.circular(50.percent),
    ),
  ];
}

class _EmbeddedCounterState extends State<EmbeddedCounter> {
  int count = 0;

  @override
  Component build(BuildContext context) {
    return FlutterEmbedView.deferred(
      classes: 'embedded-counter flutter-embed',
      constraints: ViewConstraints(minWidth: 220, minHeight: 56, maxWidth: double.infinity, maxHeight: double.infinity),
      loader: div(classes: 'embedded-counter-loader', []),
      loadLibrary: widget.loadLibrary(),
      builder: () => widget.CounterWidget(
        count: count,
        onChange: (value) => setState(() => count = value),
      ),
    );
  }
}
