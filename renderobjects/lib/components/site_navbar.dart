import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

// ─── Shared site navbar ───────────────────────────────────────────────────────
//
// activePage: 'guides' | 'examples' | 'api' | 'renderstudio' | 'renderkit'

class SiteNavbar extends StatelessComponent {
  const SiteNavbar({this.activePage});

  final String? activePage;

  String _navClasses(String page) =>
      activePage == page ? 'navbar-nav-active' : '';

  @override
  Component build(BuildContext context) {
    return nav(classes: 'navbar', [
      a(classes: 'navbar-brand', href: '/', [
        _logoIcon(),
        span([.text('Render Objects')]),
      ]),
      div(classes: 'navbar-divider', []),
      ul(classes: 'navbar-nav', [
        li([a(href: '/guides', classes: _navClasses('guides'), [.text('Guides')])]),
        li([a(href: '/api', classes: _navClasses('api'), [.text('API')])]),
        li([a(href: '/examples', classes: _navClasses('examples'), [.text('Examples')])]),
      ]),
      div(classes: 'navbar-search', [
        _searchIcon(),
        span(classes: 'navbar-search-text', [.text('Search docs...')]),
        span(classes: 'navbar-search-kbd', [.text('⌘K')]),
      ]),
      div(classes: 'navbar-actions', [
        a(
          classes: 'btn-nav btn-nav-ghost',
          href: '/renderkit',
          [.text('RenderKit')],
        ),
        a(
          classes: activePage == 'renderstudio'
              ? 'btn-nav btn-nav-primary rs-navbar-active'
              : 'btn-nav btn-nav-primary',
          href: '/renderstudio',
          [.text('RenderStudio')],
        ),
      ]),
    ]);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Component _logoIcon() => Component.element(
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
          'x': '2', 'y': '7', 'width': '11', 'height': '11',
          'rx': '2', 'fill': '#5b8dee', 'fill-opacity': '0.9',
        }),
        Component.element(tag: 'rect', attributes: {
          'x': '9', 'y': '2', 'width': '11', 'height': '11',
          'rx': '2', 'fill': '#82acf3', 'fill-opacity': '0.8',
        }),
      ],
    );

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
