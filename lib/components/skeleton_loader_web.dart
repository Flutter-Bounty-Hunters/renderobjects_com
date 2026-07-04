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

String getNameInputValue(String id) {
  final el = html.document.getElementById(id) as html.InputElement?;
  return el?.value?.trim() ?? '';
}

void focusNameInput(String id) {
  final el = html.document.getElementById(id) as html.InputElement?;
  el?.focus();
}

void setupNameInputEnterKey(String id, void Function(String) callback) {
  final el = html.document.getElementById(id) as html.InputElement?;
  if (el == null) return;
  el.onKeyDown.listen((event) {
    if (event.key == 'Enter') {
      event.preventDefault();
      callback(el.value?.trim() ?? '');
    }
  });
}
