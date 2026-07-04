import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'skeleton_loader_stub.dart'
    if (dart.library.html) 'skeleton_loader_web.dart';

// ─── Wizard phase ─────────────────────────────────────────────────────────────

enum _WizardPhase {
  widgetName,
  confirmWidgetCasing,
  renderObjectSuggestion,
  renderObjectName,
  confirmRenderObjectCasing,
  questions,
}

// ─── Dart name validation ─────────────────────────────────────────────────────

const _kDartKeywords = {
  'abstract', 'as',       'assert',    'async',    'await',    'base',
  'break',    'case',     'catch',     'class',    'const',    'continue',
  'covariant','default',  'deferred',  'do',       'dynamic',  'else',
  'enum',     'export',   'extends',   'extension','external', 'factory',
  'false',    'final',    'finally',   'for',      'Function', 'get',
  'hide',     'if',       'implements','import',   'in',       'interface',
  'is',       'late',     'library',   'mixin',    'new',      'null',
  'of',       'on',       'operator',  'part',     'required', 'rethrow',
  'return',   'sealed',   'set',       'show',     'static',   'super',
  'switch',   'sync',     'this',      'throw',    'true',     'try',
  'type',     'typedef',  'var',       'void',     'when',     'while',
  'with',     'yield',
};

final _kIdentifierRe = RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$');

String? _validateClassName(String name) {
  if (name.isEmpty) return 'Please enter a name.';
  if (!_kIdentifierRe.hasMatch(name)) {
    return "'$name' isn't a valid Dart identifier. Use only letters, digits, _ "
        "and \$, and don't start with a digit.";
  }
  if (_kDartKeywords.contains(name)) {
    return "'$name' is a Dart keyword and can't be used as a class name.";
  }
  return null;
}

bool _isUpperCamelCase(String name) =>
    name.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(name);

String _capitalizeFirst(String name) =>
    name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

// ─── Wizard questions ─────────────────────────────────────────────────────────

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
        'Will your render object recognize and handle any gestures, internally?',
    options: ['Yes', 'No'],
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

// ─── Answer → skeleton mapping ────────────────────────────────────────────────

class _SkeletonFeatures {
  final String children;
  final String paint;
  final String hitTest;
  final String semantics;
  final String baseline;
  final String gestures;

  _SkeletonFeatures({
    required this.children,
    required this.paint,
    required this.hitTest,
    required this.semantics,
    required this.baseline,
    required this.gestures,
  });

  String get filename {
    final base =
        '${children}_paint-${paint}_hit-${hitTest}_sem-${semantics}_base-${baseline}';
    return gestures == 'true' ? '${base}_gest-true.dart' : '$base.dart';
  }

  String get fragmentFilename {
    final base =
        '${children}_paint-${paint}_hit-${hitTest}_sem-${semantics}_base-${baseline}';
    return gestures == 'true'
        ? '${base}_gest-true.fragment'
        : '$base.fragment';
  }

  static _SkeletonFeatures fromAnswers(List<String> answers) {
    if (answers.length < 3) throw ArgumentError('Need at least 3 answers');
    final children = _mapChildrenAnswer(answers[0]);
    final paint = _mapPaintAnswer(answers[1]);
    final hitTest = _mapHitTestAnswer(answers[2], children);
    final gestures =
        answers.length > 3 && answers[3] == 'Yes' ? 'true' : 'false';
    final baseline =
        answers.length > 4 && answers[4].contains('intrinsic') ? 'true' : 'false';
    const semantics = 'false';
    return _SkeletonFeatures(
      children: children,
      paint: paint,
      hitTest: hitTest,
      semantics: semantics,
      baseline: baseline,
      gestures: gestures,
    );
  }

  static String _mapChildrenAnswer(String answer) {
    if (answer.contains('Zero')) return 'none';
    if (answer.contains('One')) return 'single';
    return 'multi';
  }

  static String _mapPaintAnswer(String answer) {
    if (answer.contains('No')) return 'false';
    return 'true';
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
  // ─── Phase + naming ──────────────────────────────────────────
  _WizardPhase _phase = _WizardPhase.widgetName;
  String _widgetName = '';
  String _renderObjectName = '';
  String? _pendingName;
  String? _nameInputError;

  // ─── Chat thread ─────────────────────────────────────────────
  final List<_ChatMessage> _messages = [];
  final List<String> _answers = [];
  int _currentStep = 0;
  bool _isTyping = false;
  bool _isDone = false;

  // ─── Result view ─────────────────────────────────────────────
  bool _showingResult = false;
  String? _skeletonCode;
  bool _isLoadingSkeleton = false;
  String? _skeletonError;
  bool _isCopied = false;

  // ─── Lifecycle ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _messages.add(const _ChatMessage(
      sender: _MessageSender.bot,
      text: _kWelcomeMessage,
    ));
    _messages.add(const _ChatMessage(
      sender: _MessageSender.bot,
      text: 'First, what would you like to name your widget class?',
    ));

    final skeletonName = getSkeletonParam();
    if (skeletonName != null) {
      _widgetName = getWidgetNameParam() ?? '';
      _renderObjectName = getRenderObjectNameParam() ?? '';
      _showingResult = true;
      _isLoadingSkeleton = true;
      // ignore: unawaited_futures
      Future.microtask(() => _fetchAndInjectSkeleton(skeletonName));
    } else {
      Future.delayed(Duration.zero, _setupNameInput);
    }
  }

  // ─── Name input helpers ───────────────────────────────────────

  void _setupNameInput() {
    setupNameInputEnterKey('wizard-name-input', (value) {
      if (_phase == _WizardPhase.widgetName ||
          _phase == _WizardPhase.renderObjectName) {
        _onNameSubmit(value);
      }
    });
    focusNameInput('wizard-name-input');
  }

  void _onNameSubmit(String raw) {
    final name = raw.trim();
    switch (_phase) {
      case _WizardPhase.widgetName:
        _submitWidgetName(name);
        break;
      case _WizardPhase.renderObjectName:
        _submitRenderObjectName(name);
        break;
      default:
        break;
    }
  }

  // ─── Widget name flow ─────────────────────────────────────────

  void _submitWidgetName(String name) {
    final error = _validateClassName(name);
    if (error != null) {
      setState(() => _nameInputError = error);
      return;
    }
    if (!_isUpperCamelCase(name)) {
      final corrected = _capitalizeFirst(name);
      setState(() {
        _nameInputError = null;
        _pendingName = name;
      });
      _botReply(name, () {
        setState(() {
          _phase = _WizardPhase.confirmWidgetCasing;
          _messages.add(_ChatMessage(
            sender: _MessageSender.bot,
            text: "Dart class names conventionally start with an uppercase "
                "letter. Did you mean '$corrected'?",
          ));
        });
      });
    } else {
      setState(() {
        _nameInputError = null;
        _widgetName = name;
      });
      _botReply(name, _offerRenderObjectName);
    }
  }

  void _onCasingChoice(String choice) {
    final corrected = _capitalizeFirst(_pendingName ?? '');
    setState(() {
      _widgetName = choice.startsWith('Use') ? corrected : (_pendingName ?? '');
    });
    _botReply(choice, _offerRenderObjectName);
  }

  void _offerRenderObjectName() {
    final suggested = 'Render$_widgetName';
    setState(() {
      _phase = _WizardPhase.renderObjectSuggestion;
      _messages.add(_ChatMessage(
        sender: _MessageSender.bot,
        text: "How about '$suggested' for the render object class name?",
      ));
    });
  }

  // ─── Render object name flow ──────────────────────────────────

  void _onROSuggestion(String choice) {
    if (choice.startsWith('Yes')) {
      setState(() => _renderObjectName = 'Render$_widgetName');
      _botReply(choice, _transitionToQuestions);
    } else {
      _botReply(choice, () {
        setState(() {
          _phase = _WizardPhase.renderObjectName;
          _messages.add(const _ChatMessage(
            sender: _MessageSender.bot,
            text: 'What would you like to name your render object class?',
          ));
        });
        Future.delayed(Duration.zero, _setupNameInput);
      });
    }
  }

  void _submitRenderObjectName(String name) {
    final error = _validateClassName(name);
    if (error != null) {
      setState(() => _nameInputError = error);
      return;
    }
    if (!_isUpperCamelCase(name)) {
      final corrected = _capitalizeFirst(name);
      setState(() {
        _nameInputError = null;
        _pendingName = name;
      });
      _botReply(name, () {
        setState(() {
          _phase = _WizardPhase.confirmRenderObjectCasing;
          _messages.add(_ChatMessage(
            sender: _MessageSender.bot,
            text: "Dart class names conventionally start with an uppercase "
                "letter. Did you mean '$corrected'?",
          ));
        });
      });
    } else {
      setState(() {
        _nameInputError = null;
        _renderObjectName = name;
      });
      _botReply(name, _transitionToQuestions);
    }
  }

  void _onROCasingChoice(String choice) {
    final corrected = _capitalizeFirst(_pendingName ?? '');
    setState(() {
      _renderObjectName =
          choice.startsWith('Use') ? corrected : (_pendingName ?? '');
    });
    _botReply(choice, _transitionToQuestions);
  }

  // ─── Transition to questions ──────────────────────────────────

  void _transitionToQuestions() {
    setState(() {
      _phase = _WizardPhase.questions;
      _messages.add(_ChatMessage(
        sender: _MessageSender.bot,
        text: _kWizardSteps[0].question,
      ));
    });
  }

  // ─── Question flow ────────────────────────────────────────────

  void _onQuestionAnswer(String option) {
    if (_isTyping) return;
    setState(() {
      _answers.add(option);
      _isTyping = true;
      _messages.add(_ChatMessage(sender: _MessageSender.user, text: option));
    });
    _scrollThread();
    // ignore: unawaited_futures
    Future.delayed(
        const Duration(milliseconds: 900), _onQuestionTypingComplete);
  }

  void _onQuestionTypingComplete() {
    var nextStep = _currentStep + 1;
    // Advance past any steps that should be skipped given current answers.
    while (nextStep < _kWizardSteps.length && _shouldSkipStep(nextStep)) {
      nextStep++;
    }
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
    _scrollThread();
  }

  bool _shouldSkipStep(int step) {
    // "Build during layout" (step 5) is only relevant when there are children.
    if (step == 5 && _answers.isNotEmpty && _answers[0] == 'Zero (leaf)') {
      return true;
    }
    return false;
  }

  List<String> _optionsForStep(int step) {
    final base = _kWizardSteps[step].options;
    if (step == 2 && _answers.isNotEmpty && _answers[0] != 'Zero (leaf)') {
      return [...base, 'Only Children Hittable'];
    }
    return base;
  }

  // ─── Shared bot-reply helper ──────────────────────────────────

  void _botReply(String userText, void Function() onDone) {
    setState(() {
      _isTyping = true;
      _messages.add(_ChatMessage(sender: _MessageSender.user, text: userText));
    });
    _scrollThread();
    // ignore: unawaited_futures
    Future.delayed(const Duration(milliseconds: 900), () {
      setState(() => _isTyping = false);
      onDone();
      _scrollThread();
    });
  }

  void _scrollThread() => scrollToBottom('wizard-thread');

  // ─── Skeleton load + inject ───────────────────────────────────

  Future<void> _fetchAndInjectSkeleton(String skeletonName) async {
    try {
      final url = '/renderkit/skeletons/$skeletonName.fragment';
      final fetchedHtml = await fetchSkeletonHtml(url);
      setState(() {
        _skeletonCode = fetchedHtml;
        _isLoadingSkeleton = false;
      });
      Future.delayed(Duration.zero, _injectSkeletonHtml);
    } catch (e) {
      setState(() {
        _isLoadingSkeleton = false;
        _skeletonError = 'Error loading skeleton: $e';
      });
    }
  }

  Future<void> _loadSkeleton() async {
    final features = _SkeletonFeatures.fromAnswers(_answers);
    final skeletonName = features.fragmentFilename.replaceAll('.fragment', '');
    setState(() {
      _isLoadingSkeleton = true;
      _skeletonError = null;
      _skeletonCode = null;
      _isCopied = false;
      _showingResult = true;
    });
    setSkeletonUrl(skeletonName, widgetName: _widgetName, renderObjectName: _renderObjectName);
    await _fetchAndInjectSkeleton(skeletonName);
  }

  void _injectSkeletonHtml() {
    if (_skeletonCode == null) return;
    var html = _skeletonCode!;
    // Substitute placeholder class names with the user's chosen names.
    if (_renderObjectName.isNotEmpty) {
      html = html.replaceAll('MyRenderObject', _renderObjectName);
    }
    if (_widgetName.isNotEmpty) {
      html = html.replaceAll('MyWidget', _widgetName);
    }
    injectSkeletonHtml('skeleton-html-target', html);
  }

  Future<void> _copyCode() async {
    await copySkeletonCode();
    setState(() => _isCopied = true);
    // ignore: unawaited_futures
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isCopied = false);
    });
  }

  void _goBack() {
    clearSkeletonUrl();
    setState(() {
      _showingResult = false;
      _skeletonCode = null;
      _isLoadingSkeleton = false;
      _skeletonError = null;
      _isCopied = false;
      // Reset the whole wizard so the user can start fresh.
      _phase = _WizardPhase.widgetName;
      _widgetName = '';
      _renderObjectName = '';
      _pendingName = null;
      _nameInputError = null;
      _answers.clear();
      _currentStep = 0;
      _isDone = false;
      _isTyping = false;
      _messages
        ..clear()
        ..add(const _ChatMessage(
          sender: _MessageSender.bot,
          text: _kWelcomeMessage,
        ))
        ..add(const _ChatMessage(
          sender: _MessageSender.bot,
          text: 'First, what would you like to name your widget class?',
        ));
    });
    Future.delayed(Duration.zero, _setupNameInput);
  }

  // ─── Build helpers ────────────────────────────────────────────

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

  Component _buildOptions(
    List<String> options, {
    required void Function(String) onSelect,
  }) {
    return div(classes: 'rs-chips', [
      for (final opt in options)
        button(
          type: ButtonType.button,
          classes: 'rs-chip',
          onClick: () => onSelect(opt),
          [.text(opt)],
        ),
    ]);
  }

  Component _buildNameInputRow() {
    final isWidget = _phase == _WizardPhase.widgetName;
    final placeholder = isWidget
        ? 'e.g. MyWidget'
        : 'e.g. Render${_widgetName.isNotEmpty ? _widgetName : "MyWidget"}';
    return div(classes: 'rs-msg-row rs-msg-row--user', [
      div(classes: 'rs-name-input-wrap', [
        if (_nameInputError != null)
          div(classes: 'rs-name-error', [.text(_nameInputError!)]),
        div(classes: 'rs-name-row', [
          input(
            id: 'wizard-name-input',
            type: InputType.text,
            classes: 'rs-name-field',
            attributes: {
              'placeholder': placeholder,
              'autocomplete': 'off',
              'autocorrect': 'off',
              'autocapitalize': 'off',
              'spellcheck': 'false',
            },
          ),
          button(
            type: ButtonType.button,
            classes: 'rs-name-submit-btn',
            onClick: () =>
                _onNameSubmit(getNameInputValue('wizard-name-input')),
            [.text('→')],
          ),
        ]),
      ]),
    ]);
  }

  // ─── Build: result page ───────────────────────────────────────

  Component _buildGenerateButton() {
    return div(classes: 'rs-generate-row', [
      button(
        type: ButtonType.button,
        classes: 'rs-generate-btn',
        onClick: () => _loadSkeleton(),
        [.text('Generate Skeleton')],
      ),
    ]);
  }

  Component _buildResultPage() {
    final Component codeArea;
    if (_isLoadingSkeleton) {
      codeArea = div(classes: 'rs-skeleton-loading', [
        p([.text('Loading skeleton...')]),
      ]);
    } else if (_skeletonError != null) {
      codeArea = div(classes: 'rs-skeleton-error', [
        p([.text(_skeletonError!)]),
      ]);
    } else {
      codeArea = div(classes: 'rs-code-wrapper', [
        button(
          type: ButtonType.button,
          classes:
              'rs-copy-btn${_isCopied ? ' rs-copy-btn--copied' : ''}',
          onClick: _isCopied ? null : () => _copyCode(),
          [.text(_isCopied ? 'Copied!' : 'Copy')],
        ),
        div(id: 'skeleton-html-target', []),
      ]);
    }

    return div(classes: 'rs-wizard-root', [
      div(classes: 'rs-result-page', [
        div(classes: 'rs-result-header', [
          button(
            type: ButtonType.button,
            classes: 'rs-back-btn',
            onClick: () => _goBack(),
            [.text('← Back')],
          ),
          h2(
            classes: 'rs-result-title',
            [.text('Your Render Object Skeleton')],
          ),
        ]),
        codeArea,
      ]),
    ]);
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Component build(BuildContext context) {
    if (_showingResult) return _buildResultPage();

    final casingOpts = [
      "Use '${_capitalizeFirst(_pendingName ?? '')}'",
      "Keep '$_pendingName' as-is",
    ];

    Component? inputRow;
    if (!_isTyping) {
      switch (_phase) {
        case _WizardPhase.widgetName:
        case _WizardPhase.renderObjectName:
          inputRow = _buildNameInputRow();
          break;
        case _WizardPhase.confirmWidgetCasing:
          inputRow = div(classes: 'rs-msg-row rs-msg-row--user', [
            _buildOptions(casingOpts, onSelect: _onCasingChoice),
          ]);
          break;
        case _WizardPhase.renderObjectSuggestion:
          inputRow = div(classes: 'rs-msg-row rs-msg-row--user', [
            _buildOptions(
              [
                "Yes, use 'Render$_widgetName'",
                "I'll choose a different name",
              ],
              onSelect: _onROSuggestion,
            ),
          ]);
          break;
        case _WizardPhase.confirmRenderObjectCasing:
          inputRow = div(classes: 'rs-msg-row rs-msg-row--user', [
            _buildOptions(casingOpts, onSelect: _onROCasingChoice),
          ]);
          break;
        case _WizardPhase.questions:
          if (!_isDone) {
            inputRow = div(classes: 'rs-msg-row rs-msg-row--user', [
              _buildOptions(
                _optionsForStep(_currentStep),
                onSelect: _onQuestionAnswer,
              ),
            ]);
          }
          break;
      }
    }

    return div(classes: 'rs-wizard-root', [
      div(classes: 'rs-chat-root', [
        div(id: 'wizard-thread', classes: 'rs-thread', [
          for (final msg in _messages) _buildMessage(msg),
          if (_isTyping) _buildTypingIndicator(),
          if (inputRow != null) inputRow,
        ]),
        if (_isDone)
          div(classes: 'rs-input-area', [_buildGenerateButton()]),
      ]),
    ]);
  }
}
