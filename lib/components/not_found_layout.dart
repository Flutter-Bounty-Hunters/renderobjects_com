import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'analytics.dart';
import 'site_navbar.dart';

class NotFoundLayout extends PageLayoutBase {
  const NotFoundLayout();

  @override
  String get name => 'notfound';

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
    yield script(src: '/search.js', defer: true);
    yield* analyticsHead();
  }

  @override
  Component buildBody(Page page, Component _) {
    return div(attributes: {'style': 'display:flex;flex-direction:column;min-height:100vh;background:var(--bg-base)', 'data-pagefind-ignore': ''}, [
      const SiteNavbar(),
      div(attributes: {'style': 'flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:4rem 1.5rem;text-align:center'}, [
        p(attributes: {'style': 'font-family:"JetBrains Mono",monospace;font-size:5rem;font-weight:800;color:rgba(255,255,255,0.06);line-height:1;margin:0 0 1.5rem;letter-spacing:-0.04em'}, [
          .text('404'),
        ]),
        h1(attributes: {'style': 'font-size:clamp(1.5rem,4vw,2.25rem);font-weight:700;color:var(--heading);line-height:1.2;margin:0 0 0.75rem'}, [
          .text('Page not found'),
        ]),
        p(attributes: {'style': 'max-width:400px;font-size:1rem;color:var(--text);line-height:1.7;margin:0 0 2rem'}, [
          .text("The page you're looking for doesn't exist or has been moved."),
        ]),
        div(attributes: {'style': 'display:flex;gap:0.75rem;flex-wrap:wrap;justify-content:center'}, [
          a(
            href: '/',
            attributes: {'style': 'display:inline-flex;align-items:center;padding:0.5rem 1.25rem;border-radius:6px;background:var(--accent);color:#fff;font-size:0.9375rem;font-weight:600;text-decoration:none;font-family:"Inter",sans-serif'},
            [.text('Go home')],
          ),
          a(
            href: '/guides',
            attributes: {'style': 'display:inline-flex;align-items:center;padding:0.5rem 1.25rem;border-radius:6px;border:1px solid var(--border);color:var(--text);font-size:0.9375rem;font-weight:500;text-decoration:none;font-family:"Inter",sans-serif'},
            [.text('Browse guides')],
          ),
        ]),
      ]),
    ]);
  }
}
