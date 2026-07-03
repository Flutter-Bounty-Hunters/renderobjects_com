import 'dart:html' as html;

Future<String> fetchSkeletonHtml(String url) => html.HttpRequest.getString(url);

void injectSkeletonHtml(String elementId, String htmlContent) {
  final el = html.document.getElementById(elementId);
  el?.setInnerHtml(htmlContent, treeSanitizer: html.NodeTreeSanitizer.trusted);
}

String? getSkeletonParam() {
  final search = html.window.location.search;
  if (search == null || search.isEmpty) return null;
  return Uri.splitQueryString(search.substring(1))['skeleton'];
}

void setSkeletonUrl(String skeletonName) {
  html.window.history
      .replaceState(null, '', '${html.window.location.pathname}?skeleton=$skeletonName');
}

void clearSkeletonUrl() {
  html.window.history.replaceState(null, '', html.window.location.pathname);
}

Future<void> copySkeletonCode() async {
  final el = html.document.querySelector('#skeleton-html-target code');
  if (el == null) return;
  final text = el.text ?? '';
  try {
    await html.window.navigator.clipboard?.writeText(text);
  } catch (_) {}
}
