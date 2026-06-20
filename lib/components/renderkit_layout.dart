import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'analytics.dart';
import 'favicon.dart';
import 'site_navbar.dart';

Component _svgIcon(List<Component> children, {String size = '20'}) =>
    Component.element(
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

Component _p(String d) =>
    Component.element(tag: 'path', attributes: {'d': d});

// ─── Page layout (server-side shell) ───────────────────────────────────────

class RenderKitLayout extends PageLayoutBase {
  const RenderKitLayout();

  @override
  String get name => 'renderkit';

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
      href: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;450;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap',
      rel: 'stylesheet',
    );
    yield link(href: '/styles.css', rel: 'stylesheet');
    yield script(src: '/search.js', defer: true);
    yield* analyticsHead();
  }

  @override
  Component buildBody(Page page, Component _) {
    return div([
      const SiteNavbar(activePage: 'renderkit'),
      const _RenderKitHero(),
      const _SkillsSection(),
      const _TestsSection(),
    ]);
  }
}

// ─── Hero / generate section ───────────────────────────────────────────────

class _RenderKitHero extends StatelessComponent {
  const _RenderKitHero();

  @override
  Component build(BuildContext context) {
    return div(classes: 'section', [
      div(attributes: {'style': 'max-width:680px'}, [
        div(classes: 'section-label', [.text('RenderKit')]),
        h1(classes: 'section-heading', [
          .text('Generate a custom render object'),
        ]),
        p(classes: 'section-subheading', [
          .text(
              "Answer a few questions about the render object you need — children, paint, hit testing, sizing — and RenderKit produces a Flutter skeleton tailored to your answers, backed by AI skills trained on render object patterns and a battery of tests to validate what you build."),
        ]),
        div(attributes: {'style': 'margin-top:1.5rem'}, [
          a(classes: 'btn-primary btn-renderkit', href: '/renderkit/wizard', [
            .text('Generate a Render Object'),
          ]),
        ]),
      ]),
    ]);
  }
}

// ─── Skills section ─────────────────────────────────────────────────────────

class _SkillsSection extends StatelessComponent {
  const _SkillsSection();

  @override
  Component build(BuildContext context) {
    return div(classes: 'section', [
      div(classes: 'section-label', [.text('Skills')]),
      h2(classes: 'section-heading', [
        .text('AI skills trained on render objects'),
      ]),
      p(classes: 'section-subheading', [
        .text(
            "RenderKit's skills understand the render object lifecycle, not just Flutter syntax — so the code it generates follows the conventions real render objects need."),
      ]),
      div(classes: 'cards-grid cards-grid-3', [
        _RenderKitCard(
          icon: _svgIcon([
            _p('M4 7 L10 3 L16 7 L16 13 L10 17 L4 13 Z'),
            _p('M4 7 L10 11 L16 7'),
            _p('M10 11 L10 17'),
          ]),
          iconBg: 'rgba(91,141,238,0.10)',
          iconColor: '#82acf3',
          title: 'Skeleton generation',
          description:
              'Turns your answers about children, paint, and hit testing into a working RenderBox or RenderSliver subclass.',
        ),
        _RenderKitCard(
          icon: _svgIcon([
            _p('M3 10 L7 6 L7 14 Z'),
            _p('M17 10 L13 6 L13 14 Z'),
            _p('M7 10 L13 10'),
          ]),
          iconBg: 'rgba(91,141,238,0.08)',
          iconColor: '#a5c4fb',
          title: 'Constraint reasoning',
          description:
              'Knows when a render object needs specified constraints versus an intrinsic size, and lays out performLayout accordingly.',
        ),
        _RenderKitCard(
          icon: _svgIcon([
            _p('M4 4 L16 4 L16 16 L4 16 Z'),
            _p('M4 9 L16 9'),
            _p('M9 9 L9 16'),
          ]),
          iconBg: 'rgba(91,141,238,0.06)',
          iconColor: '#c3d9fc',
          title: 'Paint & compositing guidance',
          description:
              'Flags when a render object needs a compositing layer, and generates the matching paint and hit-test overrides.',
        ),
      ]),
    ]);
  }
}

// ─── Tests section ───────────────────────────────────────────────────────────

class _TestsSection extends StatelessComponent {
  const _TestsSection();

  @override
  Component build(BuildContext context) {
    return div(classes: 'section', [
      div(classes: 'section-label', [.text('Validation')]),
      h2(classes: 'section-heading', [
        .text('A battery of tests for what you build')
      ]),
      p(classes: 'section-subheading', [
        .text(
            'Every generated render object comes with a matching test suite, so you can confirm it behaves correctly before it ships.'),
      ]),
      div(classes: 'cards-grid cards-grid-4', [
        _RenderKitCard(
          icon: _svgIcon([
            _p('M3 4 L17 4'),
            _p('M3 8 L17 8'),
            _p('M3 12 L13 12'),
          ]),
          iconBg: 'rgba(91,141,238,0.10)',
          iconColor: '#82acf3',
          title: 'Layout tests',
          description:
              'Verifies constraint handling, intrinsic sizing, and dry layout against the inputs you specified.',
        ),
        _RenderKitCard(
          icon: _svgIcon([
            _p('M4 16 L8 6 L12 12 L16 4'),
          ]),
          iconBg: 'rgba(91,141,238,0.08)',
          iconColor: '#a5c4fb',
          title: 'Paint tests',
          description:
              'Golden-image comparisons and a paint call inspector to catch unexpected canvas operations.',
        ),
        _RenderKitCard(
          icon: _svgIcon([
            _p('M10 3 L10 17'),
            _p('M3 10 L17 10'),
            Component.element(
                tag: 'circle', attributes: {'cx': '10', 'cy': '10', 'r': '3'}),
          ]),
          iconBg: 'rgba(91,141,238,0.06)',
          iconColor: '#c3d9fc',
          title: 'Hit-testing tests',
          description:
              'Confirms the render object reports hits exactly where you said it should be hittable — and nowhere else.',
        ),
        _RenderKitCard(
          icon: _svgIcon([
            _p('M5 10 a5 5 0 1 0 10 0 a5 5 0 1 0 -10 0'),
            _p('M10 7 L10 10 L12.5 12'),
          ]),
          iconBg: 'rgba(91,141,238,0.04)',
          iconColor: '#dde9fd',
          title: 'Semantics tests',
          description:
              'Checks that the semantics tree your render object describes is complete and accessible.',
        ),
      ]),
    ]);
  }
}

class _RenderKitCard extends StatelessComponent {
  final Component icon;
  final String iconBg;
  final String iconColor;
  final String title;
  final String description;

  const _RenderKitCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'card', [
      div(classes: 'card-icon',
          attributes: {'style': 'background:$iconBg;color:$iconColor'},
          [icon]),
      div(classes: 'card-title', [.text(title)]),
      p(classes: 'card-description', [.text(description)]),
    ]);
  }
}
