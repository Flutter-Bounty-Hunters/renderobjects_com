import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

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
    "Hi! I'm RenderStudio. I'll ask you a few questions to generate a Flutter render object skeleton tailored to your needs.";

const _kFinalBotMessage =
    "Perfect! I have everything I need. Click below to generate your render object skeleton.";

// ─── Message model ────────────────────────────────────────────────────────────

enum _MessageSender { bot, user }

class _ChatMessage {
  const _ChatMessage({required this.sender, required this.text});
  final _MessageSender sender;
  final String text;
}

// ─── Chat component (@client) ─────────────────────────────────────────────────

@client
class RenderStudioChat extends StatefulComponent {
  const RenderStudioChat({super.key});

  @override
  State<RenderStudioChat> createState() => RenderStudioChatState();
}

class RenderStudioChatState extends State<RenderStudioChat> {
  final List<_ChatMessage> _messages = [];
  final List<String> _answers = [];
  int _currentStep = 0;
  bool _isTyping = false;
  bool _isDone = false;

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
    setState(() {
      _answers.add(option);
      _isTyping = true;
      _messages.add(_ChatMessage(sender: _MessageSender.user, text: option));
    });

    Future.delayed(const Duration(milliseconds: 900), () {
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
          classes: 'rs-chip',
          onClick: () => _handleOptionSelected(opt),
          [.text(opt)],
        ),
    ]);
  }

  Component _buildGenerateButton() {
    return div(classes: 'rs-generate-row', [
      button(
        classes: 'rs-generate-btn',
        disabled: true,
        [.text('Generate Skeleton')],
      ),
    ]);
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'rs-chat-root', [
      div(classes: 'rs-thread', [
        for (final msg in _messages) _buildMessage(msg),
        if (_isTyping) _buildTypingIndicator(),
        if (!_isTyping && !_isDone)
          div(classes: 'rs-msg-row rs-msg-row--user', [
            _buildOptions(_optionsForStep(_currentStep)),
          ]),
      ]),
      if (_isDone)
        div(classes: 'rs-input-area', [
          _buildGenerateButton(),
        ]),
    ]);
  }
}
