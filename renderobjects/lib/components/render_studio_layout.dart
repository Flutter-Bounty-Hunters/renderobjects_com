import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'render_studio_chat.dart';

// ─── Logo icon ────────────────────────────────────────────────────────────────

class LogoIcon extends StatelessComponent {
  const LogoIcon();

  @override
  Component build(BuildContext context) {
    return Component.element(
      tag: 'svg',
      attributes: {
        'xmlns': 'http://www.w3.org/2000/svg',
        'viewBox': '0 0 22 22',
        'fill': 'none',
        'class': 'navbar-logo-icon',
        'aria-hidden': 'true',
      },
      children: [
        Component.element(tag: 'rect', attributes: {
          'x': '2',
          'y': '7',
          'width': '11',
          'height': '11',
          'rx': '2',
          'fill': '#5b8dee',
          'fill-opacity': '0.9',
        }),
        Component.element(tag: 'rect', attributes: {
          'x': '9',
          'y': '2',
          'width': '11',
          'height': '11',
          'rx': '2',
          'fill': '#82acf3',
          'fill-opacity': '0.8',
        }),
      ],
    );
  }
}

// ─── Search icon ──────────────────────────────────────────────────────────────

Component _searchIcon() => Component.element(
      tag: 'svg',
      attributes: {
        'width': '14',
        'height': '14',
        'viewBox': '0 0 16 16',
        'fill': 'none',
        'stroke': 'currentColor',
        'stroke-width': '1.75',
        'stroke-linecap': 'round',
        'aria-hidden': 'true',
      },
      children: [
        Component.element(
            tag: 'circle', attributes: {'cx': '7', 'cy': '7', 'r': '5'}),
        Component.element(tag: 'path', attributes: {'d': 'M11 11 L14 14'}),
      ],
    );

// ─── Page layout (server-side shell) ─────────────────────────────────────────

class RenderStudioLayout extends PageLayoutBase {
  const RenderStudioLayout();

  @override
  String get name => 'renderstudio';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    yield* super.buildHead(page);

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
    yield link(href: '/renderstudio.css', rel: 'stylesheet');

    yield script(src: 'https://cdn.tailwindcss.com');

    // Auto-scroll .rs-thread to the bottom whenever new message bubbles appear.
    yield script(content: r'''
document.addEventListener('DOMContentLoaded', function () {
  var waitForThread = setInterval(function () {
    var thread = document.querySelector('.rs-thread');
    if (thread) {
      clearInterval(waitForThread);
      new MutationObserver(function () {
        thread.scrollTop = thread.scrollHeight;
      }).observe(thread, { childList: true, subtree: true });
    }
  }, 50);
});
''');
  }

  @override
  Component buildBody(Page page, Component _) {
    return div(classes: 'rs-page', [
      _RenderStudioNavbar(),
      div(classes: 'rs-main', [
        const RenderStudioChat(),
      ]),
    ]);
  }
}

// ─── Navbar ───────────────────────────────────────────────────────────────────

class _RenderStudioNavbar extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return nav(classes: 'navbar', [
      a(classes: 'navbar-brand', href: '/', [
        const LogoIcon(),
        span([.text('Render Objects')]),
      ]),
      div(classes: 'navbar-divider', []),
      span(classes: 'navbar-version', [.text('v1.0')]),
      ul(classes: 'navbar-nav', [
        li([a(href: '/guides', [.text('Guides')])]),
        li([a(href: '/use-cases', [.text('Use Cases')])]),
        li([a(href: '/api', [.text('API')])]),
      ]),
      div(classes: 'navbar-search', [
        _searchIcon(),
        span(classes: 'navbar-search-text', [.text('Search docs...')]),
        span(classes: 'navbar-search-kbd', [.text('⌘K')]),
      ]),
      div(classes: 'navbar-actions', [
        a(classes: 'btn-nav btn-nav-ghost', href: '/renderkit',
            [.text('RenderKit')]),
        a(
          classes: 'btn-nav btn-nav-primary rs-navbar-active',
          href: '/renderstudio',
          [.text('RenderStudio')],
        ),
      ]),
    ]);
  }
}
