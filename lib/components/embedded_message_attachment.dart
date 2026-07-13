import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

@Import.onWeb('../examples/message_attachment/main.dart', show: [#MessageAttachmentApp])
import 'embedded_message_attachment.imports.dart' deferred as widget;

/// Embeds the [MyApp]/[MessageAttachment] demo from `examples/message_attachment`
/// live inside a Jaspr page via [FlutterEmbedView.deferred].
@client
class EmbeddedMessageAttachment extends StatelessComponent {
  const EmbeddedMessageAttachment({super.key});

  @override
  Component build(BuildContext context) {
    return FlutterEmbedView.deferred(
      classes: 'embedded-message-attachment flutter-embed',
      constraints: ViewConstraints(minWidth: 300, maxWidth: 420, minHeight: 220, maxHeight: 300),
      loader: div(classes: 'embedded-message-attachment-loader', []),
      loadLibrary: widget.loadLibrary(),
      builder: () => widget.MessageAttachmentApp(),
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.embedded-message-attachment').styles(
      display: Display.flex,
      margin: Spacing.only(top: 1.rem, bottom: 1.5.rem),
      radius: BorderRadius.circular(1.rem),
    ),
    css('.embedded-message-attachment-loader').styles(
      width: 300.px,
      height: 220.px,
      margin: Spacing.only(top: 1.rem, bottom: 1.5.rem),
      border: Border.all(width: 2.px, color: const Color('rgba(255,255,255,0.25)')),
      radius: BorderRadius.circular(1.rem),
    ),
  ];
}
