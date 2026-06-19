import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'renderkit_chat.dart';
import 'site_navbar.dart';

// ─── Page layout (server-side shell) ─────────────────────────────────────────

class RenderKitWizardLayout extends PageLayoutBase {
  const RenderKitWizardLayout();

  @override
  String get name => 'renderkit-wizard';

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
    yield link(href: '/renderkit-wizard.css', rel: 'stylesheet');

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
      const SiteNavbar(activePage: 'renderkit-wizard'),
      div(classes: 'rs-main', [
        const RenderKitChat(),
      ]),
    ]);
  }
}
