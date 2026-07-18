import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/sidebar_toggle_button.dart';

// ─── Shared site navbar ───────────────────────────────────────────────────────
//
// activePage: 'guides' | 'examples' | 'api' | 'renderkit' | 'renderkit-wizard'

class SiteNavbar extends StatelessComponent {
  const SiteNavbar({this.activePage});

  final String? activePage;

  String _navClasses(String page) =>
      activePage == page ? 'navbar-nav-active' : '';

  @override
  Component build(BuildContext context) {
    return nav(classes: 'navbar', attributes: {'data-pagefind-ignore': ''}, [
      // Hamburger that opens the docs sidebar on phone/tablet screens. It stays
      // hidden unless an ancestor carries `data-has-sidebar` (added by
      // DocsLayout) and the viewport is ≤1024px, so it only shows on the
      // guides/API/examples pages where a sidebar nav menu exists.
      const SidebarToggleButton(),
      a(classes: 'navbar-brand', href: '/', [
        img(
          src: '/images/logo.png',
          classes: 'navbar-logo-icon',
          alt: 'Render Objects logo',
        ),
        span([.text('Render Objects')]),
      ]),
      div(classes: 'navbar-divider', []),
      ul(classes: 'navbar-nav', [
        li([a(href: '/guides', classes: _navClasses('guides'), [.text('Guides')])]),
        li([a(href: '/api', classes: _navClasses('api'), [.text('API')])]),
        li([a(href: '/examples', classes: _navClasses('examples'), [.text('Examples')])]),
      ]),
      button(
        type: ButtonType.button,
        classes: 'navbar-search',
        attributes: {'id': 'site-search-trigger', 'aria-label': 'Search docs'},
        [
          _searchIcon(),
          span(classes: 'navbar-search-text', [.text('Search docs...')]),
          span(classes: 'navbar-search-kbd', [.text('⌘K')]),
        ],
      ),
      div(classes: 'navbar-actions', [
        a(
          classes: activePage == 'renderkit' || activePage == 'renderkit-wizard'
              ? 'btn-nav btn-nav-primary rs-navbar-active'
              : 'btn-nav btn-nav-primary',
          href: '/renderkit',
          [.text('RenderKit')],
        ),
      ]),
    ]);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

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
