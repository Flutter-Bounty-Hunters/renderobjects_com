import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'analytics.dart';
import 'favicon.dart';
import 'site_footer.dart';
import 'site_navbar.dart';

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
      const SiteFooter(),
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
        div(classes: 'section-label', [.text('Code Skeleton')]),
        h1(classes: 'section-heading', [
          .text('Generate a custom render object'),
        ]),
        p(classes: 'section-subheading', [
          .text(
              "Answer a few questions about the render object you need — children, paint, hit testing, sizing — and RenderKit produces a Flutter skeleton tailored to your needs."),
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
        .text('AI skills to write render objects'),
      ]),
      p(classes: 'section-subheading', [
        .text(
            "LLMs produce chaotic results. Get the consistency that your code needs for readability by using skills made specifically for writing render objects."),
      ]),
      div(attributes: {'style': 'margin-top:1.5rem'}, [
        a(
          classes: 'btn-primary btn-renderkit',
          href:
              'https://github.com/Flutter-Bounty-Hunters/render_kit/tree/main/skills',
          target: Target.blank,
          attributes: {'rel': 'noopener noreferrer'},
          [.text('Browse the skills')],
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
        .text('A battery of tests for your render objects')
      ]),
      p(classes: 'section-subheading', [
        .text(
            'Keep your render objects in compliance with the Flutter framework\'s expectations by running pre-built tests.'),
      ]),
      div(attributes: {'style': 'margin-top:1.5rem'}, [
        a(
          classes: 'btn-primary btn-renderkit',
          href: 'https://pub.dev/packages/render_proof',
          target: Target.blank,
          attributes: {'rel': 'noopener noreferrer'},
          [.text('Render Proof')],
        ),
      ]),
    ]);
  }
}
