import 'package:jaspr/jaspr.dart';

import 'hero_interop_stub.dart'
    if (dart.library.js_interop) 'hero_interop_web.dart';

/// Initializes the Three.js hero scene in the browser after hydration.
/// On the server this is a no-op; the canvas div is rendered server-side.
@client
class HeroScene extends StatefulComponent {
  const HeroScene({super.key});

  @override
  State<HeroScene> createState() => _HeroSceneState();
}

class _HeroSceneState extends State<HeroScene> {
  @override
  void initState() {
    super.initState();
    initHeroScene('hero-canvas');
  }

  @override
  void dispose() {
    disposeHeroScene();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return Component.fragment([]);
  }
}
