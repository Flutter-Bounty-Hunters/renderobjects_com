import 'dart:html' as html;

Future<String> fetchSkeletonHtml(String url) => html.HttpRequest.getString(url);

void injectSkeletonHtml(String elementId, String htmlContent) {
  final el = html.document.getElementById(elementId);
  el?.setInnerHtml(htmlContent, treeSanitizer: html.NodeTreeSanitizer.trusted);
}
