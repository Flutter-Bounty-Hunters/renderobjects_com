// Keeps URLs stable across content reorganizations.
//
// Usage:
//   dart run tool/redirects.dart check          # detect moved/removed content, update redirects.json
//   dart run tool/redirects.dart stubs <dir>     # write redirect stub pages into a built site
//
// `check` diffs content/ between the `deployed` git tag (moved to HEAD after
// each successful deploy) and the current commit. Detected renames are
// folded into redirects.json automatically. Deletions that aren't covered by
// an existing redirect entry fail the run, since that's a URL that would
// start 404ing with no replacement.
import 'dart:convert';
import 'dart:io';

const _baseTag = 'deployed';
const _redirectsFile = 'redirects.json';
const _removedFile = 'removed.json';

Future<void> main(List<String> args) async {
  final mode = args.isEmpty ? '' : args.first;
  switch (mode) {
    case 'check':
      await _runCheck();
      break;
    case 'stubs':
      final buildDir = args.length > 1 ? args[1] : 'build/jaspr';
      await _generateStubs(buildDir);
      break;
    default:
      stderr.writeln('Usage: dart run tool/redirects.dart <check|stubs> [buildDir]');
      exit(64);
  }
}

/// Maps a content file path (relative to the repo root, e.g.
/// `content/guides/painting.md`) to the URL jaspr_content serves it at.
/// Mirrors the routing rules in lib/main.server.dart.
String? _urlForContentPath(String repoRelativePath) {
  const prefix = 'content/';
  if (!repoRelativePath.startsWith(prefix) || !repoRelativePath.endsWith('.md')) return null;
  final relPath = repoRelativePath.substring(prefix.length);
  final withoutExt = relPath.substring(0, relPath.length - 3);
  if (withoutExt == '404') return null; // error page, not a tracked content URL
  if (withoutExt == 'index') return '/';
  return '/$withoutExt';
}

Future<bool> _tagExists(String tag) async {
  final result = await Process.run('git', ['rev-parse', '--verify', '--quiet', 'refs/tags/$tag']);
  return result.exitCode == 0;
}

Future<Map<String, String>> _loadRedirects() async {
  final file = File(_redirectsFile);
  if (!await file.exists()) return {};
  final content = await file.readAsString();
  if (content.trim().isEmpty) return {};
  final decoded = jsonDecode(content) as Map<String, dynamic>;
  return decoded.map((k, v) => MapEntry(k, v as String));
}

/// URLs that intentionally stopped existing with no replacement — e.g. a
/// page that should never have been published. Listed explicitly so a
/// missing redirect is a recorded decision, not a silently-skipped check.
Future<Set<String>> _loadRemoved() async {
  final file = File(_removedFile);
  if (!await file.exists()) return {};
  final content = await file.readAsString();
  if (content.trim().isEmpty) return {};
  final decoded = jsonDecode(content) as List<dynamic>;
  return decoded.map((e) => e as String).toSet();
}

Future<void> _saveRedirects(Map<String, String> redirects) async {
  final sortedKeys = redirects.keys.toList()..sort();
  final sorted = {for (final k in sortedKeys) k: redirects[k]!};
  final encoder = JsonEncoder.withIndent('  ');
  await File(_redirectsFile).writeAsString('${encoder.convert(sorted)}\n');
}

/// Resolves chains so every value in the map is a final, non-redirected URL.
/// E.g. if A->B is already recorded and B has now moved to C, this turns it
/// into A->C (plus the newly added B->C) instead of a two-hop chain.
Map<String, String> _flatten(Map<String, String> redirects) {
  final result = <String, String>{};
  for (final key in redirects.keys) {
    var target = redirects[key]!;
    final seen = <String>{key};
    while (redirects.containsKey(target)) {
      if (!seen.add(target)) break; // cycle guard
      target = redirects[target]!;
    }
    result[key] = target;
  }
  return result;
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}

Future<void> _runCheck() async {
  if (!await _tagExists(_baseTag)) {
    stdout.writeln(
      'No "$_baseTag" tag found yet — nothing to compare against. This is '
      'expected before the first successful deploy creates it.',
    );
    return;
  }

  final diff = await Process.run(
    'git',
    ['diff', '-M50', '--name-status', _baseTag, 'HEAD', '--', 'content'],
  );
  if (diff.exitCode != 0) {
    stderr.writeln(diff.stderr);
    exit(1);
  }

  var redirects = await _loadRedirects();
  final originalRedirects = Map<String, String>.from(redirects);
  final removed = await _loadRemoved();
  final renames = <String, String>{};
  final deletions = <String>{};

  for (final line in (diff.stdout as String).split('\n')) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('\t');
    final status = parts[0];
    if (status.startsWith('R')) {
      final oldUrl = _urlForContentPath(parts[1]);
      final newUrl = _urlForContentPath(parts[2]);
      if (oldUrl != null && newUrl != null && oldUrl != newUrl) {
        renames[oldUrl] = newUrl;
      }
    } else if (status == 'D') {
      final url = _urlForContentPath(parts[1]);
      if (url != null) deletions.add(url);
    }
  }

  redirects.addAll(renames);
  redirects = _flatten(redirects);

  // A deletion is fine if it's covered by a redirect (renamed/merged into
  // something that still resolves) or explicitly marked as intentionally
  // removed in removed.json. Otherwise it's a URL that would start 404ing
  // with no replacement, which needs a human decision.
  final uncovered = deletions
      .where((url) => !redirects.containsKey(url) && !removed.contains(url))
      .toList()
    ..sort();

  if (renames.isNotEmpty) {
    stdout.writeln('Detected ${renames.length} content move(s):');
    renames.forEach((from, to) => stdout.writeln('  $from -> $to'));
  }

  if (!_mapEquals(redirects, originalRedirects)) {
    await _saveRedirects(redirects);
    stdout.writeln(
      '\nredirects.json was updated automatically. Commit this file so the '
      'redirects ship with your change.',
    );
  }

  if (uncovered.isNotEmpty) {
    stderr.writeln('\nThese URLs existed in the previous release and were removed without a redirect:');
    for (final url in uncovered) {
      stderr.writeln('  $url');
    }
    stderr.writeln(
      '\nEither restore the content, add an entry to redirects.json mapping '
      'the old URL to wherever it should now go, or add the URL to '
      'removed.json if it was deleted intentionally with no replacement.',
    );
    exit(1);
  }

  stdout.writeln('\nNo broken URLs found.');
}

Future<void> _generateStubs(String buildDir) async {
  final redirects = await _loadRedirects();
  if (redirects.isEmpty) {
    stdout.writeln('No redirects to generate.');
    return;
  }

  for (final entry in redirects.entries) {
    final oldUrl = entry.key;
    final newUrl = entry.value;
    final relDir = oldUrl == '/' ? '' : oldUrl.substring(1);
    final dir = Directory('$buildDir/$relDir');

    if (await File('${dir.path}/index.html').exists()) {
      stderr.writeln(
        'Skipping redirect stub for $oldUrl -> $newUrl: a real page already exists at that path.',
      );
      continue;
    }

    await dir.create(recursive: true);
    await File('${dir.path}/index.html').writeAsString(_stubHtml(newUrl));
    stdout.writeln('Wrote redirect stub: $oldUrl -> $newUrl');
  }
}

String _stubHtml(String newUrl) => '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Page moved</title>
<link rel="canonical" href="$newUrl">
<meta http-equiv="refresh" content="0; url=$newUrl">
<script>location.replace(${jsonEncode(newUrl)});</script>
</head>
<body>
<p>This page has moved to <a href="$newUrl">$newUrl</a>.</p>
</body>
</html>
''';
