import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:syntax_highlight_lite/syntax_highlight_lite.dart';

Future<void> main() async {
  final srcDir = Directory('flutter_examples/lib/src/skeletons');
  final destDir = Directory('web/renderkit/skeletons');

  if (!srcDir.existsSync()) {
    stderr.writeln('Error: Source directory not found: ${srcDir.path}');
    exit(1);
  }

  destDir.createSync(recursive: true);

  // Initialize highlighter
  await Highlighter.initialize(['dart']);
  final highlighter = Highlighter(language: 'dart', theme: await HighlighterTheme.loadDarkTheme());

  var count = 0;
  await for (final file in srcDir.list()) {
    if (file is File && file.path.endsWith('.dart')) {
      final dartCode = file.readAsStringSync();
      final filename = path.basenameWithoutExtension(file.path);
      final config = _parseConfig(dartCode);

      final html = _dartToHtml(filename, config, dartCode, highlighter);
      final outputFile = File(path.join(destDir.path, '$filename.html'));

      outputFile.writeAsStringSync(html);
      count++;
    }
  }

  print('✓ Copied and converted $count skeleton(s) to HTML');
  print('  Output: ${destDir.path}');
}

Map<String, String> _parseConfig(String dartCode) {
  final configLine = dartCode.split('\n').firstWhere(
        (line) => line.contains('Configuration:'),
        orElse: () => '',
      );

  final config = <String, String>{};
  if (configLine.isNotEmpty) {
    final parts = configLine.split('Configuration: ')[1];
    for (final pair in parts.split(', ')) {
      final kv = pair.split('=');
      if (kv.length == 2) {
        config[kv[0].trim()] = kv[1].trim();
      }
    }
  }
  return config;
}

String _dartToHtml(String filename, Map<String, String> config, String dartCode, Highlighter highlighter) {
  final highlightedSpan = highlighter.highlight(dartCode);
  final highlightedHtml = _textSpanToHtml(highlightedSpan);

  return '''<div class="rs-skeleton-code">
  <pre><code class="language-dart">$highlightedHtml</code></pre>
</div>
''';
}

String _textSpanToHtml(TextSpan textSpan) {
  final buffer = StringBuffer();

  void visit(TextSpan span) {
    if (span.style case final style?) {
      final color = _colorToHex(style.foreground);
      final fontWeight = style.bold ? 'font-weight: bold; ' : '';
      final fontStyle = style.italic ? 'font-style: italic; ' : '';
      buffer.write('<span style="color: $color; $fontWeight$fontStyle">');
    }

    if (span.text != null) {
      buffer.write(_escapeHtml(span.text!));
    }

    for (final child in span.children) {
      visit(child);
    }

    if (span.style != null) {
      buffer.write('</span>');
    }
  }

  visit(textSpan);
  return buffer.toString();
}

String _colorToHex(Color color) {
  final argb = color.argb;
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

String _escapeHtml(String text) {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}
