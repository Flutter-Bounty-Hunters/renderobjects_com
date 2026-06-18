// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:jaspr_content/components/_internal/code_block_copy_button.dart'
    as _code_block_copy_button;
import 'package:jaspr_content/components/callout.dart' as _callout;
import 'package:jaspr_content/components/code_block.dart' as _code_block;
import 'package:jaspr_content/components/sidebar_toggle_button.dart'
    as _sidebar_toggle_button;
import 'package:renderobjects/components/hero_scene.dart' as _hero_scene;
import 'package:renderobjects/components/render_studio_chat.dart'
    as _render_studio_chat;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _code_block_copy_button.CodeBlockCopyButton:
        ClientTarget<_code_block_copy_button.CodeBlockCopyButton>(
          'jaspr_content:code_block_copy_button',
        ),
    _sidebar_toggle_button.SidebarToggleButton:
        ClientTarget<_sidebar_toggle_button.SidebarToggleButton>(
          'jaspr_content:sidebar_toggle_button',
        ),
    _hero_scene.HeroScene: ClientTarget<_hero_scene.HeroScene>('hero_scene'),
    _render_studio_chat.RenderStudioChat:
        ClientTarget<_render_studio_chat.RenderStudioChat>(
          'render_studio_chat',
        ),
  },
  styles: () => [..._callout.Callout.styles, ..._code_block.CodeBlock.styles],
);
