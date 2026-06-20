import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Author byline shown just below the title divider on every guide, API doc,
/// and example detail page — not on section overview pages.
class AuthorAttribution extends StatelessComponent {
  const AuthorAttribution();

  @override
  Component build(BuildContext context) {
    return div(classes: 'author-attribution', [
      img(
        src: '/images/photo_matt-carroll.png',
        classes: 'author-attribution-photo',
        alt: 'Matt Carroll',
      ),
      div(classes: 'author-attribution-byline', [.text('by Matt Carroll')]),
      div(classes: 'author-attribution-cta', [
        .text('Need help? '),
        a(
          href: 'https://superdeclarative.com',
          target: Target.blank,
          attributes: {'rel': 'noopener noreferrer'},
          [.text('Hire the author')],
        ),
        br(),
        .text('Appreciate these docs? '),
        a(
          href: 'https://github.com/sponsors/matthew-carroll',
          target: Target.blank,
          attributes: {'rel': 'noopener noreferrer'},
          [.text('Sponsor the author')],
        ),
      ]),
    ]);
  }
}
