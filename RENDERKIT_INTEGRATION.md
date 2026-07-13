# RenderKit Wizard + Skeleton Integration

## Overview

The RenderKit wizard guides users through 5 questions about their render object requirements, then displays a matching skeleton with syntax highlighting.

## How It Works

### 1. User Answers Questions
The wizard asks:
1. **Children**: How many children (leaf, single, multi)
2. **Paint**: Do you need custom paint/compositing
3. **Hit Testing**: What hit testing behavior (none, self, children, both)
4. **Intrinsic Size**: Does it have an intrinsic size (affects baseline support)
5. **Layout Build**: Does it need build during layout

### 2. Answer Mapping
User-friendly answers are mapped to skeleton feature flags:

| Wizard Answer | Feature | Skeleton Value |
|---|---|---|
| "Zero (leaf)" | children | `none` |
| "One" | children | `single` |
| "Slotted"/"List"/"Custom model" | children | `multi` |
| "Custom paint"/"Compositing"/"Both" | paint | `true` |
| "No — use default" | paint | `false` |
| "Entirely hittable" + leaf | hit_test | `self` |
| "Entirely hittable" + children | hit_test | `both` |
| "Partially hittable" + leaf | hit_test | `self` |
| "Partially hittable" + children | hit_test | `children` |
| "Non-hittable" | hit_test | `none` |
| "Has an intrinsic size" | baseline | `true` |
| "Always requires constraints" | baseline | `false` |

Other features default to:
- **semantics**: `false` (users can add later)
- **baseline**: determined by question 4

### 3. Skeleton Filename Generation
From the mapped features, a filename is generated:
```
{children}_paint-{paint}_hit-{hit_test}_sem-{semantics}_base-{baseline}.html
```

Example: `single_paint-true_hit-both_sem-false_base-true.html`

### 4. Skeleton Loading & Display
When the user clicks "Generate Skeleton":
1. Component loads the corresponding HTML file from `/renderkit/skeletons/`
2. Renders the pre-styled HTML snippet with built-in syntax highlighting
3. The HTML includes Prism.js-compatible token classes for Dart syntax highlighting

## File Structure

### Source
- `flutter_examples/lib/src/skeletons/*.dart` — Generated skeleton files (56 total)

### Website Build Output
- `web/renderkit/skeletons/*.html` — Published skeletons as pre-styled HTML with syntax highlighting

### Component Code
- `lib/components/renderkit_chat.dart` — Main wizard + skeleton display logic
  - `_SkeletonFeatures` — Handles answer-to-feature mapping
  - `RenderKitChat` — @client component for browser interaction
  - `_loadSkeleton()` — Fetches and displays skeleton

### Styling
- `web/renderkit-wizard.css` — Chat UI + skeleton display styling

## How to Extend

### Add a New Feature Axis
1. Add to skeleton generator (`flutter_examples/config/features.yaml`)
2. Add template conditionals (`flutter_examples/config/template.dart.tmpl`)
3. Update `_SkeletonFeatures._mapAnswerToFeature()` in `renderkit_chat.dart`
4. Regenerate skeletons and markdown:
   ```bash
   dart flutter_examples/lib/src/generator/generate_skeletons.dart
   dart tool/copy_skeletons.dart
   ```

### Refine Answer Mapping
Edit `_SkeletonFeatures.fromAnswers()` in `lib/components/renderkit_chat.dart` to adjust how wizard answers map to feature values.

## Testing Locally

1. Start the development server:
   ```bash
   jaspr serve
   ```

2. Navigate to `/renderkit-wizard`

3. Answer all questions and click "Generate Skeleton"

4. The skeleton should load and display within 1-2 seconds
