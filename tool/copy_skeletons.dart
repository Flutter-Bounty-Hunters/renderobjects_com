import 'dart:io';
import 'package:path/path.dart' as path;

Future<void> main() async {
  final srcDir = Directory('flutter_examples/lib/src/skeletons');
  final destDir = Directory('web/renderkit/skeletons');

  if (!srcDir.existsSync()) {
    stderr.writeln('Error: Source directory not found: ${srcDir.path}');
    exit(1);
  }

  destDir.createSync(recursive: true);

  var count = 0;
  await for (final file in srcDir.list()) {
    if (file is File && file.path.endsWith('.dart')) {
      final dartCode = file.readAsStringSync();
      final filename = path.basenameWithoutExtension(file.path);
      final config = _parseConfig(dartCode);

      final html = _dartToHtml(filename, config, dartCode);
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

String _dartToHtml(String filename, Map<String, String> config, String dartCode) {
  final highlightedCode = _highlightDartCode(dartCode);

  return '''<div class="rs-skeleton-code">
  <pre><code class="language-dart">$highlightedCode</code></pre>
</div>
''';
}

String _highlightDartCode(String code) {
  final dartKeywords = {
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
    'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
    'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
    'factory', 'false', 'final', 'finally', 'for', 'function', 'get', 'hide',
    'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
    'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
    'return', 'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync',
    'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'when', 'while',
    'with', 'yield'
  };

  final dartBuiltins = {
    'int', 'double', 'bool', 'String', 'List', 'Map', 'Set', 'Iterable',
    'Future', 'Stream', 'Duration', 'DateTime', 'Exception', 'Error',
    'Object', 'Type', 'Symbol', 'Uri', 'Pattern', 'Match', 'Range',
    'Stopwatch', 'Random', 'Zone', 'Completer', 'Timer'
  };

  var result = '';
  var i = 0;

  while (i < code.length) {
    // Line comments
    if (i + 1 < code.length && code[i] == '/' && code[i + 1] == '/') {
      final endOfLine = code.indexOf('\n', i);
      final commentEnd = endOfLine == -1 ? code.length : endOfLine;
      final comment = code.substring(i, commentEnd);
      result += '<span class="token comment">${_escapeHtml(comment)}</span>';
      i = commentEnd;
      continue;
    }

    // Block comments
    if (i + 1 < code.length && code[i] == '/' && code[i + 1] == '*') {
      final endOfComment = code.indexOf('*/', i + 2);
      final commentEnd = endOfComment == -1 ? code.length : endOfComment + 2;
      final comment = code.substring(i, commentEnd);
      result += '<span class="token comment">${_escapeHtml(comment)}</span>';
      i = commentEnd;
      continue;
    }

    // String literals (double quotes)
    if (code[i] == '"') {
      var j = i + 1;
      while (j < code.length && code[j] != '"') {
        if (code[j] == '\\' && j + 1 < code.length) j += 2;
        else j++;
      }
      j = j < code.length ? j + 1 : j;
      final str = code.substring(i, j);
      result += '<span class="token string">${_escapeHtml(str)}</span>';
      i = j;
      continue;
    }

    // String literals (single quotes)
    if (code[i] == "'") {
      var j = i + 1;
      while (j < code.length && code[j] != "'") {
        if (code[j] == '\\' && j + 1 < code.length) j += 2;
        else j++;
      }
      j = j < code.length ? j + 1 : j;
      final str = code.substring(i, j);
      result += '<span class="token string">${_escapeHtml(str)}</span>';
      i = j;
      continue;
    }

    // Numbers
    if (_isDigit(code[i]) || (code[i] == '.' && i + 1 < code.length && _isDigit(code[i + 1]))) {
      var j = i;
      while (j < code.length && (_isDigit(code[j]) || code[j] == '.')) j++;
      final num = code.substring(i, j);
      result += '<span class="token number">${_escapeHtml(num)}</span>';
      i = j;
      continue;
    }

    // Identifiers and keywords/builtins
    if (_isIdentifierStart(code[i])) {
      var j = i;
      while (j < code.length && _isIdentifierPart(code[j])) j++;
      final identifier = code.substring(i, j);

      if (dartKeywords.contains(identifier)) {
        result += '<span class="token keyword">${_escapeHtml(identifier)}</span>';
      } else if (dartBuiltins.contains(identifier)) {
        result += '<span class="token builtin">${_escapeHtml(identifier)}</span>';
      } else if (i + 1 < code.length && code[j] == '(') {
        result += '<span class="token function">${_escapeHtml(identifier)}</span>';
      } else if (_isCapitalized(identifier)) {
        result += '<span class="token class-name">${_escapeHtml(identifier)}</span>';
      } else {
        result += _escapeHtml(identifier);
      }

      i = j;
      continue;
    }

    // Operators
    if (_isOperatorChar(code[i])) {
      var j = i + 1;
      // Multi-character operators
      if (i + 1 < code.length) {
        final twoChar = code.substring(i, i + 2);
        if (['==', '!=', '<=', '>=', '+=', '-=', '*=', '/=', '&&', '||',
             '<<', '>>', '??', '=>', '++', '--'].contains(twoChar)) {
          result += '<span class="token operator">${_escapeHtml(twoChar)}</span>';
          i += 2;
          continue;
        }
      }
      result += '<span class="token operator">${_escapeHtml(code[i])}</span>';
      i++;
      continue;
    }

    // Punctuation
    if ('(){}\[\].,;:?'.contains(code[i])) {
      result += '<span class="token punctuation">${_escapeHtml(code[i])}</span>';
      i++;
      continue;
    }

    // Whitespace and other characters
    if (code[i] == '\n') {
      result += '\n';
    } else if (code[i] == ' ' || code[i] == '\t') {
      result += code[i];
    } else {
      result += _escapeHtml(code[i]);
    }
    i++;
  }

  return result;
}

bool _isDigit(String char) => char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

bool _isIdentifierStart(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95;
}

bool _isIdentifierPart(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) ||
         code == 95 || (code >= 48 && code <= 57);
}

bool _isOperatorChar(String char) => '+-*/%<>=!&|^~'.contains(char);

bool _isCapitalized(String str) => str.isNotEmpty && str[0] == str[0].toUpperCase();

String _escapeHtml(String text) {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

String _titleCase(String filename) {
  final parts = filename.split('_');
  return parts
      .map((part) {
        if (part.contains('-')) {
          return part.split('-').map((p) => _capitalize(p)).join('-');
        }
        return _capitalize(part);
      })
      .join(' ');
}

String _capitalize(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

String _buildDescription(String childrenType, bool paint, String hitTest, bool semantics, bool baseline) {
  final parts = <String>[];

  switch (childrenType) {
    case 'none':
      parts.add('Leaf render object');
    case 'single':
      parts.add('Single-child render object');
    case 'multi':
      parts.add('Multi-child container render object');
  }

  if (paint) parts.add('with custom painting');
  if (hitTest != 'none') parts.add('with hit testing ($hitTest)');
  if (semantics) parts.add('with semantics');
  if (baseline) parts.add('with baseline support');

  return parts.join(' ');
}
