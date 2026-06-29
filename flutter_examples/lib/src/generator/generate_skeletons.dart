import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

void main() async {
  final pubspecDir = _findPubspecDir();
  final configDir = Directory(path.join(pubspecDir, 'config'));
  final skeletonsDir = Directory(path.join(pubspecDir, 'lib', 'src', 'skeletons'));

  if (!configDir.existsSync()) {
    print('Error: config directory not found at ${configDir.path}');
    exit(1);
  }

  skeletonsDir.createSync(recursive: true);

  final featuresFile = File(path.join(configDir.path, 'features.yaml'));
  final templateFile = File(path.join(configDir.path, 'template.dart.tmpl'));

  if (!featuresFile.existsSync()) {
    print('Error: features.yaml not found');
    exit(1);
  }
  if (!templateFile.existsSync()) {
    print('Error: template.dart.tmpl not found');
    exit(1);
  }

  final featuresYaml = loadYaml(featuresFile.readAsStringSync()) as Map;
  final template = templateFile.readAsStringSync();

  final axes = (featuresYaml['axes'] as Map).map((k, v) {
    final values = (v is Map ? v['values'] : v) as List;
    return MapEntry(k as String, values.map((x) => x.toString()).cast<String>().toList());
  });

  final constraints = (featuresYaml['constraints'] as List<dynamic>?) ?? [];
  final outputNamePattern = featuresYaml['output_name'] as String? ?? '{children}_{paint}_{hit_test}_{semantics}_{baseline}.dart';

  final combos = _generateCombinations(axes);
  var generated = 0;
  var skipped = 0;

  for (final combo in combos) {
    if (_shouldSkip(combo, constraints)) {
      skipped++;
      continue;
    }

    final vars = _buildVariables(combo);
    final output = _processTemplate(template, vars);
    final filename = _formatOutputName(outputNamePattern, combo);
    final outputFile = File(path.join(skeletonsDir.path, filename));

    outputFile.writeAsStringSync(output);
    generated++;
  }

  print('✓ Generated $generated skeleton(s), skipped $skipped due to constraints');
  print('  Output: ${skeletonsDir.path}');
}

String _findPubspecDir() {
  var current = Directory.current;
  while (current.path != '/') {
    if (File(path.join(current.path, 'pubspec.yaml')).existsSync()) {
      final pubspec = current.path;
      if (File(path.join(pubspec, 'lib', 'src', 'generator', 'generate_skeletons.dart')).existsSync()) {
        return pubspec;
      }
    }
    current = current.parent;
  }
  throw Exception('Could not find flutter_examples pubspec.yaml');
}

List<Map<String, String>> _generateCombinations(Map<String, List<String>> axes) {
  if (axes.isEmpty) return [];
  final result = <Map<String, String>>[];
  final axisNames = axes.keys.toList();

  void generate(int depth, Map<String, String> current) {
    if (depth == axisNames.length) {
      result.add(Map.from(current));
      return;
    }
    final axis = axisNames[depth];
    for (final value in axes[axis]!) {
      current[axis] = value;
      generate(depth + 1, current);
    }
  }

  generate(0, {});
  return result;
}

bool _shouldSkip(Map<String, String> combo, List<dynamic> constraints) {
  for (final constraint in constraints) {
    if (constraint is! Map) continue;
    final ifCond = constraint['if'] as Map?;
    if (ifCond == null) continue;

    bool matches = true;
    for (final entry in ifCond.entries) {
      if (combo[entry.key.toString()] != entry.value.toString()) {
        matches = false;
        break;
      }
    }

    if (!matches) continue;

    if (constraint['skip'] == true) return true;

    final disallow = constraint['disallow'] as Map?;
    if (disallow != null) {
      for (final entry in disallow.entries) {
        final values = entry.value is List
          ? (entry.value as List).map((v) => v.toString()).toList()
          : [entry.value.toString()];
        if (values.contains(combo[entry.key.toString()])) {
          return true;
        }
      }
    }
  }
  return false;
}

Map<String, String> _buildVariables(Map<String, String> combo) {
  final childrenType = combo['children']!;
  final vars = <String, String>{};

  vars['CHILDREN'] = childrenType;
  vars['PAINT'] = combo['paint']!;
  vars['HIT_TEST'] = combo['hit_test']!;
  vars['SEMANTICS'] = combo['semantics']!;
  vars['BASELINE'] = combo['baseline']!;

  vars['BASE_CLASS'] = 'RenderBox';

  switch (childrenType) {
    case 'single':
      vars['CHILD_MIXIN'] = 'RenderObjectWithChildMixin<RenderBox>';
      vars['CHILD_PARENT_DATA'] = 'BoxParentData';
    case 'multi':
      vars['CHILD_MIXIN'] = 'ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>';
      vars['CHILD_PARENT_DATA'] = 'ContainerBoxParentData<RenderBox>';
    case 'none':
    default:
      break;
  }

  return vars;
}

String _processTemplate(String template, Map<String, String> vars) {
  final lines = template.split('\n');
  final (_, processed) = _processLines(lines, 0, vars);

  var result = processed.join('\n');
  for (final entry in vars.entries) {
    result = result.replaceAll('@var(${entry.key})', entry.value);
  }

  return result;
}

(int, List<String>) _processLines(List<String> lines, int startIdx, Map<String, String> vars) {
  final output = <String>[];
  var i = startIdx;

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed.startsWith('// @if(')) {
      final expr = trimmed.substring(7, trimmed.length - 1);
      final condition = _evalCondition(expr, vars);
      final (endIdx, blockLines) = _extractAndProcess(lines, i, condition, vars);
      output.addAll(blockLines);
      i = endIdx + 1;
    } else if (trimmed.startsWith('// @ifnot(')) {
      final expr = trimmed.substring(10, trimmed.length - 1);
      final condition = _evalCondition(expr, vars);
      final (endIdx, blockLines) = _extractAndProcess(lines, i, !condition, vars);
      output.addAll(blockLines);
      i = endIdx + 1;
    } else if (trimmed.startsWith('// @endif')) {
      return (i, output);
    } else {
      output.add(line);
      i++;
    }
  }

  return (lines.length - 1, output);
}

(int, List<String>) _extractAndProcess(List<String> lines, int startIdx, bool include, Map<String, String> vars) {
  var depth = 1;
  var i = startIdx + 1;
  final blockLines = <String>[];

  while (i < lines.length && depth > 0) {
    final trimmed = lines[i].trim();
    if (trimmed.startsWith('// @if(') || trimmed.startsWith('// @ifnot(')) {
      depth++;
    } else if (trimmed.startsWith('// @endif')) {
      depth--;
      if (depth == 0) break;
    }
    if (depth > 1) {
      blockLines.add(lines[i]);
    } else if (include) {
      blockLines.add(lines[i]);
    }
    i++;
  }

  if (include) {
    final (_, processed) = _processLines(blockLines, 0, vars);
    return (i, processed);
  }
  return (i, []);
}

bool _evalCondition(String expr, Map<String, String> vars) {
  if (expr.contains(':')) {
    final parts = expr.split(':');
    final varName = parts[0];
    final expectedValue = parts[1];
    return vars[varName] == expectedValue;
  }
  return vars[expr] == 'true';
}

String _formatOutputName(String pattern, Map<String, String> combo) {
  var result = pattern;
  for (final entry in combo.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value);
  }
  return result;
}
