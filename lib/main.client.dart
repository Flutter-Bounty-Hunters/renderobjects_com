/// The entrypoint for the **client** environment.
///
/// The [main] method will only be executed on the client when loading the page.
/// To run code on the server during pre-rendering, check the `main.server.dart` file.
library;

// Client-specific Jaspr import.
import 'package:jaspr/client.dart';

import 'components/hero_scene.dart';
import 'components/renderkit_chat.dart';

// This file is generated automatically by Jaspr, do not remove or edit.
import 'main.client.options.dart';

// Ensure HeroScene is included in the client bundle.
// ignore: unused_element
HeroScene? _ref;

// Ensure RenderKitChat is compiled into the client bundle.
// ignore: unused_element
RenderKitChat? _rsRef;

void main() {
  // Initializes the client environment with the generated default options.
  Jaspr.initializeApp(
    options: defaultClientOptions,
  );

  // Starts the app.
  //
  // [ClientApp] automatically loads and renders all components annotated with @client.
  //
  // You can wrap this with additional [InheritedComponent]s to share state across multiple
  // @client components if needed.
  runApp(
    const ClientApp(),
  );
}
