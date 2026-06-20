import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Shared site-wide footer — used on every page so visitors always have a
/// consistent way back to the main sections, regardless of which layout
/// rendered the page.
class SiteFooter extends StatelessComponent {
  const SiteFooter();

  // The site's first-publication year — copyright covers this year through
  // the current year, not just whatever year it happens to be rebuilt in.
  static const int _firstPublishedYear = 2026;

  static String get _copyrightYears {
    final currentYear = DateTime.now().year;
    return currentYear > _firstPublishedYear
        ? '$_firstPublishedYear–$currentYear'
        : '$_firstPublishedYear';
  }

  @override
  Component build(BuildContext context) {
    return footer(
      classes: 'site-footer',
      attributes: {'data-pagefind-ignore': ''},
      [
        span(classes: 'footer-copy', [
          .text('© $_copyrightYears Matt Carroll'),
        ]),
        div(classes: 'footer-links', [
          a(href: '/guides', [.text('Guides')]),
          a(href: '/examples', [.text('Examples')]),
          a(href: '/api', [.text('API')]),
          a(href: '/renderkit', [.text('RenderKit')]),
        ]),
      ],
    );
  }
}
