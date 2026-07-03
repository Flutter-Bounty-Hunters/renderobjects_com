import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'skeleton_loader_stub.dart'
    if (dart.library.html) 'skeleton_loader_web.dart';

// ─── Wizard script ────────────────────────────────────────────────────────────

const List<({String question, List<String> options})> _kWizardSteps = [
  (
    question: 'How many children will this render object have?',
    options: ['Zero (leaf)', 'One', 'Slotted', 'List', 'Custom model'],
  ),
  (
    question: 'Do you need custom paint or compositing?',
    options: ['Custom paint', 'Compositing', 'Both', 'No — use default'],
  ),
  (
    question: 'What is the desired hit testing behavior?',
    options: ['Entirely hittable', 'Partially hittable', 'Non-hittable'],
  ),
  (
    question:
        'Does this render object always require specified constraints, or does it have an intrinsic size (a natural size when width and height are infinite)?',
    options: ['Always requires specified constraints', 'Has an intrinsic size'],
  ),
  (
    question:
        'Does this render object need to run build during layout (like LayoutBuilder)?',
    options: ['Yes', 'No', "I don't know"],
  ),
];

const _kWelcomeMessage =
    "Hi! I'm RenderKit. I'll ask you a few questions to generate a Flutter render object skeleton tailored to your needs.";

const _kFinalBotMessage =
    "Perfect! I have everything I need. Click below to generate your render object skeleton.";

// ─── Answer mapping ──────────────────────────────────────────────────────────

/// Maps wizard answers to skeleton feature values.
class _SkeletonFeatures {
  final String children;
  final String paint;
  final String hitTest;
  final String semantics;
  final String baseline;

  _SkeletonFeatures({
    required this.children,
    required this.paint,
    required this.hitTest,
    required this.semantics,
    required this.baseline,
  });

  /// Generates the skeleton filename from features.
  String get filename =>
      '${children}_paint-${paint}_hit-${hitTest}_sem-${semantics}_base-${baseline}.dart';

  /// Generates the skeleton fragment filename (for loading from web).
  String get fragmentFilename =>
      '${children}_paint-${paint}_hit-${hitTest}_sem-${semantics}_base-${baseline}.fragment';

  /// Maps wizard answers to skeleton features.
  static _SkeletonFeatures fromAnswers(List<String> answers) {
    if (answers.length < 3) {
      throw ArgumentError('Need at least 3 answers');
    }

    // Answer 0: children type
    final children = _mapChildrenAnswer(answers[0]);

    // Answer 1: paint
    final paint = _mapPaintAnswer(answers[1]);

    // Answer 2: hit testing
    final hitTest = _mapHitTestAnswer(answers[2], children);

    // Answer 3: intrinsic size (maps to baseline)
    final baseline = answers.length > 3 && answers[3].contains('intrinsic') ? 'true' : 'false';

    // Answer 4: semantics (default false, could be true if user opts in)
    final semantics = 'false';

    return _SkeletonFeatures(
      children: children,
      paint: paint,
      hitTest: hitTest,
      semantics: semantics,
      baseline: baseline,
    );
  }

  static String _mapChildrenAnswer(String answer) {
    if (answer.contains('Zero')) return 'none';
    if (answer.contains('One')) return 'single';
    return 'multi'; // Slotted, List, Custom model all map to multi
  }

  static String _mapPaintAnswer(String answer) {
    if (answer.contains('No')) return 'false';
    return 'true'; // Custom paint, Compositing, Both
  }

  static String _mapHitTestAnswer(String answer, String children) {
    if (answer.contains('Non')) return 'none';
    if (answer.contains('Entirely')) return children == 'none' ? 'self' : 'both';
    if (answer.contains('Partially')) return children == 'none' ? 'self' : 'children';
    if (answer.contains('Only Children')) return 'children';
    return 'self';
  }
}

// ─── Message model ────────────────────────────────────────────────────────────

enum _MessageSender { bot, user }

class _ChatMessage {
  const _ChatMessage({required this.sender, required this.text});
  final _MessageSender sender;
  final String text;
}

// ─── Chat component (@client) ─────────────────────────────────────────────────

@client
class RenderKitChat extends StatefulComponent {
  const RenderKitChat({super.key});

  @override
  State<RenderKitChat> createState() => RenderKitChatState();
}

class RenderKitChatState extends State<RenderKitChat> {
  final List<_ChatMessage> _messages = [];
  final List<String> _answers = [];
  int _currentStep = 0;
  bool _isTyping = false;
  bool _isDone = false;
  String? _skeletonCode;
  bool _isLoadingSkeleton = false;
  String? _skeletonError;

  @override
  void initState() {
    super.initState();
    _messages.add(const _ChatMessage(
      sender: _MessageSender.bot,
      text: _kWelcomeMessage,
    ));
    _messages.add(_ChatMessage(
      sender: _MessageSender.bot,
      text: _kWizardSteps[_currentStep].question,
    ));
  }

  void _handleOptionSelected(String option) {
    if (_isTyping) return;

    // Debug log
    print('Option selected: $option');

    setState(() {
      _answers.add(option);
      _isTyping = true;
      _messages.add(_ChatMessage(sender: _MessageSender.user, text: option));
    });

    // ignore: unawaited_futures
    Future.delayed(const Duration(milliseconds: 900), _onTypingComplete);
  }

  void _onTypingComplete() {
    final nextStep = _currentStep + 1;
    setState(() {
      _isTyping = false;
      _currentStep = nextStep;
      if (nextStep >= _kWizardSteps.length) {
        _isDone = true;
        _messages.add(const _ChatMessage(
          sender: _MessageSender.bot,
          text: _kFinalBotMessage,
        ));
      } else {
        _messages.add(_ChatMessage(
          sender: _MessageSender.bot,
          text: _kWizardSteps[nextStep].question,
        ));
      }
    });
  }

  List<String> _optionsForStep(int step) {
    final base = _kWizardSteps[step].options;
    // Hit testing (step 2): add "Only Children Hittable" when the user has 1+ children.
    if (step == 2 && _answers.isNotEmpty && _answers[0] != 'Zero (leaf)') {
      return [...base, 'Only Children Hittable'];
    }
    return base;
  }

  Component _buildMessage(_ChatMessage msg) {
    if (msg.sender == _MessageSender.bot) {
      return div(classes: 'rs-msg-row rs-msg-row--bot', [
        div(classes: 'rs-avatar', []),
        div(classes: 'rs-bubble rs-bubble--bot', [.text(msg.text)]),
      ]);
    } else {
      return div(classes: 'rs-msg-row rs-msg-row--user', [
        div(classes: 'rs-bubble rs-bubble--user', [.text(msg.text)]),
      ]);
    }
  }

  Component _buildTypingIndicator() {
    return div(classes: 'rs-msg-row rs-msg-row--bot', [
      div(classes: 'rs-avatar', []),
      div(classes: 'rs-bubble rs-bubble--bot rs-bubble--typing', [
        span(classes: 'rs-typing-dot', []),
        span(classes: 'rs-typing-dot', []),
        span(classes: 'rs-typing-dot', []),
      ]),
    ]);
  }

  Component _buildOptions(List<String> options) {
    return div(classes: 'rs-chips', [
      for (final opt in options)
        button(
          type: ButtonType.button,
          classes: 'rs-chip',
          onClick: () {
            print('Button clicked: $opt');
            _handleOptionSelected(opt);
          },
          [.text(opt)],
        ),
    ]);
  }

  Future<void> _loadSkeleton() async {
    final features = _SkeletonFeatures.fromAnswers(_answers);
    setState(() {
      _isLoadingSkeleton = true;
      _skeletonError = null;
      _skeletonCode = null;
    });

    try {
      final url = '/renderkit/skeletons/${features.fragmentFilename}';
      final fetchedHtml = await fetchSkeletonHtml(url);
      setState(() {
        _skeletonCode = fetchedHtml;
        _isLoadingSkeleton = false;
      });
      // Inject after Jaspr has updated the DOM.
      Future.delayed(Duration.zero, _injectSkeletonHtml);
    } catch (e) {
      setState(() {
        _isLoadingSkeleton = false;
        _skeletonError = 'Error loading skeleton: $e';
      });
    }
  }

  void _injectSkeletonHtml() {
    if (_skeletonCode == null) return;
    injectSkeletonHtml('skeleton-html-target', _skeletonCode!);
  }

  Component _buildGenerateButton() {
    return div(classes: 'rs-generate-row', [
      button(
        classes: 'rs-generate-btn',
        onClick: _skeletonCode == null ? () => _loadSkeleton() : null,
        [.text(_skeletonCode == null ? 'Generate Skeleton' : 'Copy Code')],
      ),
    ]);
  }

  Component _buildSkeletonDisplay() {
    if (_isLoadingSkeleton) {
      return div(classes: 'rs-skeleton-loading', [
        p([.text('Loading skeleton...')]),
      ]);
    }

    if (_skeletonError != null) {
      return div(classes: 'rs-skeleton-error', [
        p([.text(_skeletonError!)]),
      ]);
    }

    if (_skeletonCode == null) {
      return div([]);
    }

    return div(classes: 'rs-skeleton-display', [
      div(classes: 'rs-skeleton-header', [
        h3([.text('Your Render Object Skeleton')]),
      ]),
      div(id: 'skeleton-html-target', []),
    ]);
  }

  @override
  Component build(BuildContext context) {
    final shouldShowOptions = !_isTyping && !_isDone;

    return div(classes: 'rs-wizard-root', [
      div(classes: 'rs-chat-root', [
        div(classes: 'rs-thread', [
          for (final msg in _messages) _buildMessage(msg),
          if (_isTyping) _buildTypingIndicator(),
          if (shouldShowOptions)
            div(classes: 'rs-msg-row rs-msg-row--user', [
              _buildOptions(_optionsForStep(_currentStep)),
            ]),
        ]),
        if (_isDone)
          div(classes: 'rs-input-area', [
            _buildGenerateButton(),
          ]),
      ]),
      if (_isDone) _buildSkeletonDisplay(),
    ]);
  }
}
