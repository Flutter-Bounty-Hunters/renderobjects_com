import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

@Import.onWeb('../examples/nest_thermostat/main.dart', show: [#MyApp])
import 'embedded_thermostat.imports.dart' deferred as widget;

/// Embeds the [MyApp]/[Thermostat] demo from `examples/nest_thermostat` live
/// inside a Jaspr page via [FlutterEmbedView.deferred]. The widget manages its
/// own temperature state internally, so no Jaspr-side state is needed here.
@client
class EmbeddedThermostat extends StatelessComponent {
  const EmbeddedThermostat({super.key});

  @override
  Component build(BuildContext context) {
    return FlutterEmbedView.deferred(
      classes: 'embedded-thermostat flutter-embed',
      constraints: ViewConstraints(minWidth: 320, maxWidth: 380, minHeight: 380, maxHeight: 440),
      loader: div(classes: 'embedded-thermostat-loader', []),
      loadLibrary: widget.loadLibrary(),
      builder: () => widget.MyApp(),
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.embedded-thermostat').styles(
      display: Display.flex,
      margin: Spacing.only(top: 1.rem, bottom: 1.5.rem),
      radius: BorderRadius.circular(1.rem),
    ),
    css('.embedded-thermostat-loader').styles(
      width: 320.px,
      height: 380.px,
      margin: Spacing.only(top: 1.rem, bottom: 1.5.rem),
      border: Border.all(width: 2.px, color: const Color('rgba(255,255,255,0.25)')),
      radius: BorderRadius.circular(1.rem),
    ),
  ];
}
