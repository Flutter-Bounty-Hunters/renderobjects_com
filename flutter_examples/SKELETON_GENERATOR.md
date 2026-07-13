# Skeleton Generator

This system generates render object skeleton files for different combinations of render object features.

## How It Works

1. **`config/features.yaml`** — Defines feature axes (children, paint, hit_test, semantics, baseline) and their valid values. Also defines constraints that skip invalid combinations.

2. **`config/template.dart.tmpl`** — A single master template using Dart comments as directives:
   - `// @if(FEATURE:value)` ... `// @endif` — include block when feature equals value
   - `// @ifnot(FEATURE:value)` — include block when feature does NOT equal value
   - `@var(VARNAME)` — replaced with computed value (e.g., mixin name, base class)
   - Blocks can be nested; the processor recursively evaluates them.

3. **`lib/src/generator/generate_skeletons.dart`** — Dart script that:
   - Enumerates all feature combinations (cartesian product of all axis values)
   - Filters out combinations marked `skip: true` or that match `disallow` rules
   - For each valid combo, instantiates template variables and processes conditionals
   - Writes output to `lib/src/skeletons/<filename>.dart` (filename from `output_name` pattern)

## Running the Generator

```bash
cd flutter_examples
dart lib/src/generator/generate_skeletons.dart
```

Output: **56 skeletons**, covering all valid combinations of:
- Children: none (leaf), single, multi
- Paint: true or false
- Hit-test: none, self, children, both
- Semantics: true or false
- Baseline: true or false

(40 combinations are filtered by constraints: no paint is skipped for leaves, invalid children+hit_test combos, etc.)

## Verifying the Output

```bash
flutter analyze lib/src/skeletons/
```

All generated files must pass static analysis (no errors, though stylistic warnings about file names are expected).

## Publishing Skeletons to the Website

A companion script (`tool/copy_skeletons.dart`) automatically converts generated Dart skeletons into Markdown files and copies them to `web/renderkit/skeletons/`. This is integrated into the CI/CD pipeline and runs before the site build:

```bash
dart run tool/copy_skeletons.dart
```

This script:
- Reads each skeleton `.dart` file from `flutter_examples/lib/src/skeletons/`
- Parses the configuration comment line
- Generates appropriate frontmatter (title, description, layout)
- Wraps the Dart code in a fenced code block
- Outputs Markdown to `web/renderkit/skeletons/<name>.md`

The Markdown files are then available as static documentation pages on the site.

## Modifying Features

To add a new axis or constraint:
1. Edit `config/features.yaml` to add the axis definition and any new constraints
2. Edit `config/template.dart.tmpl` to add conditional blocks for the new feature
3. If needed, update `lib/src/generator/generate_skeletons.dart` to handle new template variables
4. Regenerate: `dart lib/src/generator/generate_skeletons.dart`
5. Run the copy script to update the published skeletons: `dart run tool/copy_skeletons.dart`
