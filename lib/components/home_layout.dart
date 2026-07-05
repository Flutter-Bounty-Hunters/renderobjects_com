import 'dart:io';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:syntax_highlight_lite/syntax_highlight_lite.dart' hide Color;

import 'analytics.dart';
import 'author_attribution.dart';
import 'favicon.dart';
import 'hero_scene.dart';
import 'site_footer.dart';
import 'site_navbar.dart';

Component _svgIcon(List<Component> children, {String size = '20'}) => Component.element(
  tag: 'svg',
  attributes: {
    'viewBox': '0 0 $size $size',
    'fill': 'none',
    'stroke': 'currentColor',
    'stroke-width': '1.5',
    'stroke-linecap': 'round',
    'stroke-linejoin': 'round',
    'width': size,
    'height': size,
    'aria-hidden': 'true',
  },
  children: children,
);

Component _p(String d) => Component.element(tag: 'path', attributes: {'d': d});

class HomeLayout extends PageLayoutBase {
  const HomeLayout();

  @override
  String get name => 'home';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    yield* super.buildHead(page);
    yield* faviconHead();

    yield link(href: 'https://fonts.googleapis.com', rel: 'preconnect');
    yield link(
      href: 'https://fonts.gstatic.com',
      rel: 'preconnect',
      attributes: {'crossorigin': ''},
    );
    yield link(
      href:
          'https://fonts.googleapis.com/css2?family=Inter:wght@400;450;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap',
      rel: 'stylesheet',
    );

    yield link(href: '/styles.css', rel: 'stylesheet');
    // Needed for the AuthorAttribution component embedded in the hero, which
    // is otherwise only styled on docs.css-linked guide/API/example pages.
    yield link(href: '/docs.css', rel: 'stylesheet');
    yield script(src: '/search.js', defer: true);
    yield* analyticsHead();

    yield script(
      content:
          'window._heroQueue=[];window.initHeroScene=function(id){window._heroQueue.push(id);};window.disposeHeroScene=function(){};',
    );

    yield script(
      attributes: {'type': 'importmap'},
      content:
          '{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.170/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.170/examples/jsm/"}}',
    );
    yield script(attributes: {'type': 'module', 'src': '/three_scene.js'});

    yield script(
      content: r'''
document.addEventListener('DOMContentLoaded',function(){
  var obs=new IntersectionObserver(function(entries){
    entries.forEach(function(e){if(e.isIntersecting)e.target.classList.add('revealed');});
  },{threshold:0.10});
  document.querySelectorAll('.reveal').forEach(function(el){obs.observe(el);});
});
''',
    );
  }

  @override
  Component buildBody(Page page, Component _) {
    return div([
      const SiteNavbar(),
      _HeroSection(),
      _StatsBar(),
      _ConceptsSection(),
      _UseCasesSectionWrapper(),
      _ApiSection(),
      _FooterCta(),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Hero section
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return section(classes: 'hero-section', [
      div(id: 'hero-canvas', attributes: {'aria-hidden': 'true'}, []),
      HeroScene(),
      div(classes: 'hero-content', [
        img(
          src: '/images/logo_big.png',
          classes: 'hero-logo',
          alt: 'Render Objects logo',
        ),
        div(classes: 'hero-eyebrow', [
          .text('ADVANCED FLUTTER'),
        ]),
        h1(classes: 'hero-title gradient-text', [
          .text('Render Objects'),
        ]),
        p(classes: 'hero-tagline', [
          .text(
            "Learn the foundation of Flutter's rendering layer. Master the primitives that paint every pixel on the screen.",
          ),
        ]),
        _HeroCodePanel(),
        const AuthorAttribution(),
      ]),
    ]);
  }
}

// The hero panel's example code lives in this Markdown file (a fenced
// ```dart block) so it can be edited without touching the layout. It's
// highlighted at build time with the same highlighter used by the site's
// other code blocks, so its colors stay consistent with guides/docs.
const _heroCodeSnippetPath = 'content/_snippets/hero-code.md';

String _extractDartSource(String markdown) {
  final match = RegExp(r'```dart\n([\s\S]*?)```').firstMatch(markdown);
  return match?.group(1)?.trimRight() ?? markdown.trim();
}

class _HeroCodePanel extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'hero-code-panel', [
      div(classes: 'hero-code-header', [
        div(classes: 'hero-code-dot dot-red', []),
        div(classes: 'hero-code-dot dot-yellow', []),
        div(classes: 'hero-code-dot dot-green', []),
        span(classes: 'hero-code-filename', [.text('my_render_box.dart')]),
      ]),
      div(classes: 'hero-code-body', [
        AsyncBuilder(
          builder: (context) async {
            final source = _extractDartSource(await File(_heroCodeSnippetPath).readAsString());
            Highlighter.initialize(['dart']);
            final highlighter = Highlighter(language: 'dart', theme: await HighlighterTheme.loadDarkTheme());
            return pre([_buildSpan(highlighter.highlight(source))]);
          },
        ),
      ]),
    ]);
  }

  Component _buildSpan(TextSpan textSpan) {
    Styles? styles;

    if (textSpan.style case final style?) {
      styles = Styles(
        color: Color.value(style.foreground.argb & 0x00FFFFFF),
        fontWeight: style.bold ? FontWeight.bold : null,
        fontStyle: style.italic ? FontStyle.italic : null,
        textDecoration: style.underline ? TextDecoration(line: TextDecorationLine.underline) : null,
      );
    }

    if (styles == null && textSpan.children.isEmpty) {
      return Component.text(textSpan.text ?? '');
    }

    return span(styles: styles, [
      if (textSpan.text != null) Component.text(textSpan.text!),
      for (final t in textSpan.children) _buildSpan(t),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Stats bar
// ---------------------------------------------------------------------------

class _StatsBar extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'stats-bar', [
      _stat('20', 'guides'),
      _stat('16', 'api docs'),
      _stat('5', 'examples'),
      _stat('1', 'render kit'),
    ]);
  }
}

Component _stat(String value, String label) {
  return div(classes: 'stat-item', [
    span(classes: 'stat-value', [.text(value)]),
    span(classes: 'stat-label', [.text(label)]),
  ]);
}

// ---------------------------------------------------------------------------
// Concepts section
// ---------------------------------------------------------------------------

class _ConceptsSection extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'section', [
      div(classes: 'section-label', [.text('The what, why, and how')]),
      h2(classes: 'section-heading', [
        .text('Render Object Guides'),
      ]),
      p(classes: 'section-subheading', [
        .text(
          'With AI, you can outsource your knowledge, but not your understanding. Learn the fundamental behaviors of render objects with our guides.',
        ),
      ]),
      div(classes: 'cards-grid cards-grid-3', [
        _ConceptCard(
          icon: _svgIcon([
            _p('M4 8 L4 4 L8 4'),
            _p('M12 4 L16 4 L16 8'),
            _p('M16 12 L16 16 L12 16'),
            _p('M8 16 L4 16 L4 12'),
          ]),
          iconBg: 'rgba(91,141,238,0.10)',
          iconColor: '#82acf3',
          title: 'Layout',
          description: 'Learn how render objects choose sizes and child positions with layout.',
          href: '/guides/layout',
        ),
        _ConceptCard(
          icon: _svgIcon([
            _p('M4 7 L16 7 L16 14 L4 14 Z'),
            _p('M4 4.5 L16 4.5'),
            _p('M6.5 3 L4 4.5 L6.5 6'),
            _p('M13.5 3 L16 4.5 L13.5 6'),
          ]),
          iconBg: 'rgba(91,141,238,0.08)',
          iconColor: '#a5c4fb',
          title: 'Painting',
          description:
              'Learn how render objects put pixels on the screen during paint, with canvas commands and layered effects.',
          href: '/guides/painting',
        ),
        _ConceptCard(
          icon: _svgIcon([
            _p('M3 4 L17 4'),
            _p('M3 8 L17 8'),
            _p('M3 12 L13 12'),
            _p('M10 14 L10 18'),
            _p('M8 16 L10 18 L12 16'),
          ]),
          iconBg: 'rgba(91,141,238,0.06)',
          iconColor: '#c3d9fc',
          title: 'Slotted Children',
          description: 'Learn how to build render objects with named child widgets.',
          href: '/guides/children/slotted-children',
        ),
      ]),
      div(
        attributes: {'style': 'margin-top:2rem'},
        [
          a(
            href: '/guides',
            attributes: {
              'style':
                  'color:var(--accent-light);font-size:0.9rem;font-weight:500;text-decoration:none;display:inline-flex;align-items:center;gap:0.375rem;font-family:"JetBrains Mono",monospace',
            },
            [.text('View all guides →')],
          ),
        ],
      ),
    ]);
  }
}

class _ConceptCard extends StatelessComponent {
  final Component icon;
  final String iconBg;
  final String iconColor;
  final String title;
  final String description;
  final String href;

  _ConceptCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.href,
  });

  @override
  Component build(BuildContext context) {
    return a(classes: 'card reveal', href: href, [
      div(classes: 'card-icon', attributes: {'style': 'background:$iconBg;color:$iconColor'}, [icon]),
      div(classes: 'card-title', [.text(title)]),
      p(classes: 'card-description', [.text(description)]),
      span(classes: 'card-link', [.text('Read guide →')]),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Use Cases section
// ---------------------------------------------------------------------------

class _UseCasesSectionWrapper extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'use-cases-wrapper', [
      div(classes: 'section', [
        div(classes: 'section-label', [.text('Examples')]),
        h2(classes: 'section-heading', [.text('Real Code, Real Render Objects')]),
        p(classes: 'section-subheading', [
          .text(
            "Ground your understanding with real render object implementations, including explanations of implementation decisions.",
          ),
        ]),
        div(classes: 'cards-grid cards-grid-3', [
          _UseCaseCard(
            accent: '#82acf3',
            iconImagePath: 'examples/nest-thermostat_paint.png',
            title: 'Nest Thermostat',
            description:
                "A render object that looks similar to a Nest thermostat. A child-less render object with a complicating painting and paint-aware hit detection.",
            href: '/examples/nest-thermostat',
          ),
          _UseCaseCard(
            accent: '#5b8dee',
            icon: _svgIcon([
              _p('M10 10 L4 4'),
              _p('M10 10 L16 4'),
              _p('M10 10 L18 10'),
              _p('M10 10 L16 16'),
              _p('M10 10 L4 16'),
              _p('M10 10 L2 10'),
              Component.element(tag: 'circle', attributes: {'cx': '10', 'cy': '10', 'r': '2'}),
            ]),
            title: 'Particle Effects',
            description:
                'Render thousands of animated particles per frame, bypassing the widget tree overhead entirely.',
            href: '/examples/particle-effects',
          ),
          _UseCaseCard(
            accent: '#a5c4fb',
            iconImagePath: 'examples/apple-watch-app-grid_paint.png',
            title: 'Apple Watch App Grid',
            description:
                'A render object that looks similar to the Apple Watch app grid. Virtualized child app icons, in an infinitely scrollable honeycomb grid with fisheye distortion. The user can drag, fling, and tap.',
            href: '/examples/apple-watch-app-grid',
          ),
        ]),
        div(
          attributes: {'style': 'margin-top:2rem'},
          [
            a(
              href: '/examples',
              attributes: {
                'style':
                    'color:var(--accent-light);font-size:0.9rem;font-weight:500;text-decoration:none;display:inline-flex;align-items:center;gap:0.375rem;font-family:"JetBrains Mono",monospace',
              },
              [.text('View all examples →')],
            ),
          ],
        ),
      ]),
    ]);
  }
}

class _UseCaseCard extends StatelessComponent {
  final Component? icon;
  final String? iconImagePath;
  final String accent;
  final String title;
  final String description;
  final String href;

  _UseCaseCard({
    this.icon,
    this.iconImagePath,
    required this.accent,
    required this.title,
    required this.description,
    required this.href,
  }) : assert((icon == null) != (iconImagePath == null), 'Provide exactly one of icon or iconImagePath');

  @override
  Component build(BuildContext context) {
    final iconContent = iconImagePath != null ? img(src: context.resolveAsset(iconImagePath!), alt: title) : icon!;
    final iconClasses = iconImagePath != null ? 'card-icon card-icon-image' : 'card-icon';
    return a(classes: 'card reveal', href: href, [
      div(classes: iconClasses, attributes: {'style': 'background:${accent}18;color:$accent'}, [iconContent]),
      div(classes: 'card-title', [.text(title)]),
      p(classes: 'card-description', [.text(description)]),
      span(classes: 'card-link', attributes: {'style': 'color:$accent'}, [.text('See example →')]),
    ]);
  }
}

// ---------------------------------------------------------------------------
// API section
// ---------------------------------------------------------------------------

class _ApiSection extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'section', [
      div(classes: 'section-label', [.text('API Reference')]),
      h2(classes: 'section-heading', [.text('Surgical Help')]),
      p(classes: 'section-subheading', [
        .text(
          'Get help implementing specific render object methods with our API docs.',
        ),
      ]),
      div(
        attributes: {'style': 'display:flex;flex-direction:column;gap:0.75rem'},
        [
          _MethodBlock(
            name: 'performLayout()',
            accentColor: '#5b8dee',
            description:
                'Calculates the size of this render object and positions all its children. Must set this.size before returning.',
            returnNote: 'void — called by the framework during the layout phase',
            href: '/api/layout/performLayout',
          ),
          _MethodBlock(
            name: 'paint(PaintingContext context, Offset offset)',
            accentColor: '#82acf3',
            description:
                'Draws the visual representation of this render object onto the composited layer. Called after layout completes.',
            returnNote: 'void — uses context.canvas for direct drawing operations',
            href: '/api/paint/paint',
          ),
          _MethodBlock(
            name: 'hitTest(BoxHitTestResult result, {required Offset position})',
            accentColor: '#a5c4fb',
            description:
                'Determines whether a pointer event at position falls within this render object. Returns true to claim the event.',
            returnNote: 'bool — true if the hit test is absorbed by this render object',
            href: '/api/hit-testing/hittest',
          ),
        ],
      ),
      div(
        attributes: {'style': 'margin-top:2rem'},
        [
          a(
            href: '/api',
            attributes: {
              'style':
                  'color:var(--accent-light);font-size:0.9rem;font-weight:500;text-decoration:none;display:inline-flex;align-items:center;gap:0.375rem;font-family:"JetBrains Mono",monospace',
            },
            [.text('View full API reference →')],
          ),
        ],
      ),
    ]);
  }
}

class _MethodBlock extends StatelessComponent {
  final String name;
  final String accentColor;
  final String description;
  final String returnNote;
  final String href;

  const _MethodBlock({
    required this.name,
    required this.accentColor,
    required this.description,
    required this.returnNote,
    required this.href,
  });

  @override
  Component build(BuildContext context) {
    return a(
      classes: 'method-block reveal',
      href: href,
      attributes: {'style': 'text-decoration:none;display:block;border-left:2px solid $accentColor'},
      [
        div(classes: 'method-header', [
          span(classes: 'method-name', [.text(name)]),
          span(
            attributes: {
              'style':
                  'font-size:0.75rem;color:var(--text-muted);margin-left:auto;font-family:"JetBrains Mono",monospace',
            },
            [.text('docs →')],
          ),
        ]),
        div(classes: 'method-body', [
          p(classes: 'method-description', [.text(description)]),
          span(classes: 'method-return', [.text(returnNote)]),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Footer CTA + site footer
// ---------------------------------------------------------------------------

class _FooterCta extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div([
      div(classes: 'footer-cta-section', [
        div(classes: 'footer-cta-inner', [
          div(classes: 'section-label', [.text('Tooling')]),
          h2(classes: 'section-heading', [.text('Build better render objects')]),
          p(classes: 'section-subheading', [
            .text('An AI-powered toolkit designed specifically for Flutter render object development.'),
          ]),
          div(classes: 'footer-products-grid', [
            _ProductCard(
              type: 'kit',
              icon: _svgIcon([
                _p('M4 4 L8.5 4 L8.5 8.5 L4 8.5 Z'),
                _p('M11.5 4 L16 4 L16 8.5 L11.5 8.5 Z'),
                _p('M4 11.5 L8.5 11.5 L8.5 16 L4 16 Z'),
                _p('M11.5 11.5 L16 11.5 L16 16 L11.5 16 Z'),
              ]),
              title: 'RenderKit',
              description:
                  'Describe the render object you need — by voice or text — and RenderKit generates a production-ready skeleton, complete with the tests and inspectors to verify it works.',
              features: const [
                'Voice-first, AI-guided code generation',
                'Automated test suite for your render objects',
                'Layout constraint visualizer and paint call inspector',
                'Export to any Flutter project',
              ],
              buttonText: 'Explore RenderKit',
              buttonHref: '/renderkit',
            ),
          ]),
        ]),
      ]),
      const SiteFooter(),
    ]);
  }
}

class _ProductCard extends StatelessComponent {
  final String type;
  final Component icon;
  final String title;
  final String description;
  final List<String> features;
  final String buttonText;
  final String buttonHref;

  _ProductCard({
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    required this.buttonText,
    required this.buttonHref,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'product-card product-card-$type', [
      div(classes: 'product-icon product-icon-$type', [icon]),
      div(classes: 'product-title', [.text(title)]),
      p(classes: 'product-description', [.text(description)]),
      ul(classes: 'product-features', [
        for (final f in features)
          li([
            span(classes: 'feature-check feature-check-$type', [.text('✓')]),
            .text(f),
          ]),
      ]),
      a(classes: 'btn-product btn-product-$type', href: buttonHref, [
        .text(buttonText),
      ]),
    ]);
  }
}
