import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

// GA4 Measurement ID — get this from the GA4 console under
// Admin > Data Streams > (your web stream) > Measurement ID.
const String gaMeasurementId = 'G-FNRVZETCTX';

Iterable<Component> analyticsHead() sync* {
  yield script(
    src: 'https://www.googletagmanager.com/gtag/js?id=$gaMeasurementId',
    defer: true,
  );
  yield script(content: '''
window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', '$gaMeasurementId');
''');
}
