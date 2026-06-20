import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

Iterable<Component> faviconHead() sync* {
  yield link(href: '/favicon.ico', rel: 'icon');
  yield link(
    href: '/images/favicon-16x16.png',
    rel: 'icon',
    attributes: {'type': 'image/png', 'sizes': '16x16'},
  );
  yield link(
    href: '/images/favicon-32x32.png',
    rel: 'icon',
    attributes: {'type': 'image/png', 'sizes': '32x32'},
  );
  yield link(
    href: '/images/icon-192.png',
    rel: 'icon',
    attributes: {'type': 'image/png', 'sizes': '192x192'},
  );
  yield link(
    href: '/images/icon-512.png',
    rel: 'icon',
    attributes: {'type': 'image/png', 'sizes': '512x512'},
  );
  yield link(
    href: '/images/apple-touch-icon.png',
    rel: 'apple-touch-icon',
    attributes: {'sizes': '180x180'},
  );
}
