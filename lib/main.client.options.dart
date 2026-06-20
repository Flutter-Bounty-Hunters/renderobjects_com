// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:jaspr_content/components/_internal/code_block_copy_button.dart'
    deferred as _code_block_copy_button;
import 'package:jaspr_content/components/sidebar_toggle_button.dart'
    deferred as _sidebar_toggle_button;
import 'package:renderobjects/components/embedded_thermostat.dart'
    deferred as _embedded_thermostat;
import 'package:renderobjects/components/hero_scene.dart'
    deferred as _hero_scene;
import 'package:renderobjects/components/renderkit_chat.dart'
    deferred as _renderkit_chat;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  clients: {
    'jaspr_content:code_block_copy_button': ClientLoader(
      (p) => _code_block_copy_button.CodeBlockCopyButton(),
      loader: _code_block_copy_button.loadLibrary,
    ),
    'jaspr_content:sidebar_toggle_button': ClientLoader(
      (p) => _sidebar_toggle_button.SidebarToggleButton(),
      loader: _sidebar_toggle_button.loadLibrary,
    ),
    'embedded_thermostat': ClientLoader(
      (p) => _embedded_thermostat.EmbeddedThermostat(),
      loader: _embedded_thermostat.loadLibrary,
    ),
    'hero_scene': ClientLoader(
      (p) => _hero_scene.HeroScene(),
      loader: _hero_scene.loadLibrary,
    ),
    'renderkit_chat': ClientLoader(
      (p) => _renderkit_chat.RenderKitChat(),
      loader: _renderkit_chat.loadLibrary,
    ),
  },
);
