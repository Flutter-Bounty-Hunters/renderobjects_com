import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'site_navbar.dart';

class RenderKitLayout extends PageLayoutBase {
  const RenderKitLayout();

  @override
  String get name => 'renderkit';

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
  }

  @override
  Component buildBody(Page page, Component _) {
    return div(attributes: {'style': 'display:flex;flex-direction:column;min-height:100vh;background:var(--bg-base)'}, [
      const SiteNavbar(activePage: 'renderkit'),
      div(attributes: {'style': 'flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:4rem 1.5rem;text-align:center'}, [
        span(attributes: {'style': 'display:inline-block;padding:0.25rem 0.75rem;border-radius:9999px;border:1px solid rgba(91,141,238,0.35);background:rgba(91,141,238,0.08);color:var(--accent-light);font-size:0.75rem;font-weight:600;letter-spacing:0.06em;font-family:"JetBrains Mono",monospace;margin-bottom:1.5rem'}, [
          .text('COMING SOON'),
        ]),
        h1(attributes: {'style': 'font-size:clamp(2rem,5vw,3.25rem);font-weight:800;color:var(--heading);line-height:1.1;margin:0 0 1rem'}, [
          .text('RenderKit'),
        ]),
        p(attributes: {'style': 'max-width:480px;font-size:1.0625rem;color:var(--text);line-height:1.7;margin:0'}, [
          .text('A Flutter package of production-ready custom render objects — drop-in building blocks for effects and layouts that go beyond the widget layer.'),
        ]),
      ]),
    ]);
  }
}
