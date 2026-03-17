import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/ai/domain/ai_models.dart';
import 'package:pody/features/ai/presentation/ai_scope.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';
import 'package:pody/screens/auth/sign_up_screen.dart';
import 'package:pody/screens/creation/edit_plan_screen.dart';

const _createBg = Color(0xFFF7F7F8);
const _createSurface = Colors.white;
const _createSurfaceSoft = Color(0xFFF3F4F6);
const _createBorder = Color(0xFFE5E7EB);
const _createBorderSoft = Color(0xFFEAECF0);
const _createTextPrimary = Color(0xFF111827);
const _createTextSecondary = Color(0xFF6B7280);
const _createTextMuted = Color(0xFF9CA3AF);
const _createAccent = Color(0xFF0F172A);
const _createAccentSoft = Color(0xFFF0F4F8);
const _createDanger = Color(0xFFD14343);

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  static const _headerInset = 84.0;
  static const _composerDockBottom = 32.0;
  static const _composerBottomGap = 8.0;
  static const _promptSuggestions = <String>[
    'Tao mot show tin cong nghe moi sang cho founder va product manager.',
    'Len concept show ke chuyen lich su Viet Nam theo goc nhin gan gui, de nghe.',
    'Giup toi xay mot podcast hoc tieng Anh bang tinh huong cong so hang ngay.',
  ];

  final List<String> _attachedFiles = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AIChatThread? _thread;
  StreamSubscription<AIChatStreamEvent>? _streamSubscription;
  bool _isSending = false;
  String? _errorMessage;
  String? _activeUserId;
  String? _pendingUserMessage;
  String? _streamingStatus;
  String _streamingAssistantText = '';

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = AuthScope.of(context).session?.user.id;
    if (userId == _activeUserId) {
      return;
    }

    _activeUserId = userId;
    _streamSubscription?.cancel();
    _thread = null;
    _isSending = false;
    _errorMessage = null;
    _pendingUserMessage = null;
    _streamingStatus = null;
    _streamingAssistantText = '';
    _attachedFiles.clear();
    _messageController.clear();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _createSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _createBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image, color: _createTextPrimary),
                title: const Text(
                  'Upload Image',
                  style: TextStyle(color: _createTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _attachedFiles.add(
                      'image_${_attachedFiles.length + 1}.png',
                    );
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.description,
                  color: _createTextPrimary,
                ),
                title: const Text(
                  'Upload Document',
                  style: TextStyle(color: _createTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _attachedFiles.add(
                      'document_${_attachedFiles.length + 1}.pdf',
                    );
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.audiotrack,
                  color: _createTextPrimary,
                ),
                title: const Text(
                  'Upload Audio',
                  style: TextStyle(color: _createTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _attachedFiles.add(
                      'audio_${_attachedFiles.length + 1}.mp3',
                    );
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendPrompt([String? seededPrompt]) async {
    if (_isSending) {
      return;
    }

    final prompt = (seededPrompt ?? _messageController.text).trim();
    if (prompt.isEmpty) {
      return;
    }

    final previousText = _messageController.text;
    if (seededPrompt == null) {
      _messageController.clear();
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
      _errorMessage = null;
      _pendingUserMessage = prompt;
      _streamingStatus = 'Dang phan tich brief va len plan...';
      _streamingAssistantText = '';
    });

    final repository = AIScope.of(context);
    final stream = _thread == null
        ? repository.streamCreateThread(prompt: prompt)
        : repository.streamAddThreadMessage(
            threadId: _thread!.id,
            message: prompt,
          );

    await _streamSubscription?.cancel();
    _streamSubscription = stream.listen(
      (event) {
        if (!mounted) {
          return;
        }
        _handleStreamEvent(event);
      },
      onError: (error) {
        if (!mounted) {
          return;
        }
        _restoreInputIfNeeded(previousText, seededPrompt == null);
        setState(() {
          _errorMessage = _humanizeError(error);
          _isSending = false;
          _pendingUserMessage = null;
          _streamingStatus = null;
          _streamingAssistantText = '';
        });
      },
      onDone: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _isSending = false;
          _streamingStatus = null;
        });
      },
      cancelOnError: false,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(0);
    });
  }

  void _resetThread() {
    FocusScope.of(context).unfocus();
    _streamSubscription?.cancel();
    setState(() {
      _thread = null;
      _isSending = false;
      _errorMessage = null;
      _pendingUserMessage = null;
      _streamingStatus = null;
      _streamingAssistantText = '';
      _attachedFiles.clear();
      _messageController.clear();
    });
    _scrollToTop();
  }

  void _handleStreamEvent(AIChatStreamEvent event) {
    switch (event.type) {
      case AIChatStreamEventType.status:
        setState(() {
          _streamingStatus = event.message;
        });
        _scrollToBottom();
        break;
      case AIChatStreamEventType.assistantDelta:
        setState(() {
          _streamingStatus = null;
          _streamingAssistantText += event.deltaText ?? '';
        });
        _scrollToBottom();
        break;
      case AIChatStreamEventType.thread:
        setState(() {
          _thread = event.thread;
          _errorMessage = null;
          _pendingUserMessage = null;
          _streamingStatus = null;
          _streamingAssistantText = '';
        });
        _scrollToBottom();
        break;
      case AIChatStreamEventType.done:
        setState(() {
          _isSending = false;
          _streamingStatus = null;
        });
        break;
      case AIChatStreamEventType.error:
        if (_pendingUserMessage != null && _messageController.text.trim().isEmpty) {
          _messageController.text = _pendingUserMessage!;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        }
        setState(() {
          _errorMessage = event.message ?? 'AI service gap loi.';
          _isSending = false;
          _pendingUserMessage = null;
          _streamingStatus = null;
          _streamingAssistantText = '';
        });
        break;
    }
  }

  void _restoreInputIfNeeded(String previousText, bool shouldRestore) {
    if (!shouldRestore) {
      return;
    }
    _messageController.text = previousText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  Future<void> _openPlanDetail(AIProductionPlan plan) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => EditPlanScreen(plan: plan)),
    );

    if (!mounted || result == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Da tao show "${result.title}".')));
  }

  String _humanizeError(Object error) {
    if (error is ApiException) {
      if (error.isUnauthorized) {
        return 'Ban can dang nhap lai de tiep tuc tao show bang AI.';
      }
      return error.message;
    }
    return 'AI service dang tam thoi khong phan hoi. Thu lai sau it phut nua.';
  }

  List<Widget> _buildConversation(BuildContext context) {
    final thread = _thread;
    if (thread == null) {
      if (_pendingUserMessage == null) {
        return _buildEmptyConversation();
      }

      return [
        _buildUserBubble(context, _pendingUserMessage!),
        const SizedBox(height: 32),
        if (_streamingAssistantText.isNotEmpty || _streamingStatus != null)
          _buildStreamingAssistantBlock(),
      ];
    }

    final lastAssistantIndex = thread.messages.lastIndexWhere(
      (message) => !message.isUser,
    );

    final widgets = <Widget>[
      ...thread.messages
          .asMap()
          .entries
          .map((entry) {
          final index = entry.key;
          final message = entry.value;

          if (message.isUser) {
            return Column(
              children: [
                _buildUserBubble(context, message.text),
                const SizedBox(height: 32),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAssistantMarkdown(message.text),
              if (index == lastAssistantIndex &&
                  thread.currentPlan != null) ...[
                const SizedBox(height: 16),
                _buildPlanCard(thread.currentPlan!),
              ],
              const SizedBox(height: 32),
            ],
          );
          }),
    ];

    if (_pendingUserMessage != null) {
      widgets.add(
        Column(
          children: [
            _buildUserBubble(context, _pendingUserMessage!),
            const SizedBox(height: 32),
          ],
        ),
      );
    }

    if (_streamingAssistantText.isNotEmpty || _streamingStatus != null) {
      widgets.add(_buildStreamingAssistantBlock());
    }

    return widgets;
  }

  List<Widget> _buildEmptyConversation() {
    return [
      const Text(
        'Hôm nay bạn muốn tạo show gì?',
        style: TextStyle(
          color: _createTextPrimary,
          fontSize: 38,
          fontWeight: FontWeight.w500,
          height: 1.08,
          letterSpacing: -1.1,
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Mô tả ngắn chủ đề, format hoặc khán giả mục tiêu. AI sẽ lên concept show, dàn host và lineup tập đầu tiên.',
        style: TextStyle(
          color: _createTextSecondary,
          fontSize: 15,
          height: 1.55,
        ),
      ),
      const SizedBox(height: 30),
      ..._promptSuggestions.map(
        (prompt) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: _isSending ? null : () => _sendPrompt(prompt),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: _createSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _createBorderSoft),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                prompt,
                style: const TextStyle(
                  color: _createTextSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);
    if (!authController.isAuthenticated) {
      return _GuestCreateView(
        onSignIn: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SignInScreen()));
        },
        onSignUp: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SignUpScreen()));
        },
      );
    }

    final canResetThread = _thread != null && !_isSending;
    final topPadding = _headerInset;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;
    final baseComposerBottom = safeBottom + _composerDockBottom;
    final composerBottom = math.max(
      baseComposerBottom,
      bottomInset + _composerBottomGap,
    );
    final conversationBottomPadding = composerBottom + 132;

    return Scaffold(
      backgroundColor: _createBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16 + topPadding,
                      bottom: conversationBottomPadding,
                    ),
                    children: _buildConversation(context),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  left: 16,
                  right: 16,
                  bottom: composerBottom,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _createSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _createBorderSoft),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120F172A),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_attachedFiles.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              top: 4,
                              bottom: 8,
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _attachedFiles.map((file) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _createSurfaceSoft,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _createBorderSoft,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        file.endsWith('.pdf')
                                            ? Icons.description
                                            : file.endsWith('.png')
                                            ? Icons.image
                                            : Icons.audiotrack,
                                        color: _createTextSecondary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        file,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _createTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _attachedFiles.remove(file);
                                          });
                                        },
                                        child: const Icon(
                                          Icons.close,
                                          color: _createTextMuted,
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Container(
                            height: 1,
                            color: _createBorderSoft,
                            margin: const EdgeInsets.only(bottom: 8),
                          ),
                        ],
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 12,
                              bottom: 8,
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: _createDanger,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _createSurfaceSoft,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  color: _createTextPrimary,
                                  size: 18,
                                ),
                                onPressed: _showAttachmentOptions,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                enabled: !_isSending,
                                onSubmitted: (_) => _sendPrompt(),
                                style: const TextStyle(
                                  color: _createTextPrimary,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Message Assistant...',
                                  filled: false,
                                  hintStyle: TextStyle(
                                    color: _createTextMuted,
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: _createAccent,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: _isSending
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.arrow_upward,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                onPressed: _isSending ? null : _sendPrompt,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 16,
                  child: _NewChatButton(
                    enabled: canResetThread,
                    onPressed: _resetThread,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _createSurfaceSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _createBorderSoft),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _createTextSecondary,
        ),
      ),
    );
  }

  Widget _buildUserBubble(BuildContext context, String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _createAccentSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _createBorder),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _createTextPrimary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildStreamingAssistantBlock() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_streamingAssistantText.isNotEmpty)
            _buildAssistantMarkdown(_streamingAssistantText),
          if (_streamingStatus != null)
            Padding(
              padding: EdgeInsets.only(
                top: _streamingAssistantText.isNotEmpty ? 10 : 0,
              ),
              child: Text(
                _streamingStatus!,
                style: const TextStyle(
                  color: _createTextMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssistantMarkdown(String content) {
    return MarkdownBody(
      data: content,
      shrinkWrap: true,
      selectable: false,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          color: _createTextPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        strong: const TextStyle(
          color: _createTextPrimary,
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w700,
        ),
        em: const TextStyle(
          color: _createTextPrimary,
          fontSize: 15,
          height: 1.5,
          fontStyle: FontStyle.italic,
        ),
        code: const TextStyle(
          color: _createTextPrimary,
          fontSize: 14,
          height: 1.4,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: _createSurfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _createBorderSoft),
        ),
        blockquote: const TextStyle(
          color: _createTextSecondary,
          fontSize: 15,
          height: 1.5,
        ),
        blockquoteDecoration: BoxDecoration(
          color: _createSurfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _createBorderSoft),
        ),
        listBullet: const TextStyle(
          color: _createTextPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        h1: const TextStyle(
          color: _createTextPrimary,
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        h2: const TextStyle(
          color: _createTextPrimary,
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        h3: const TextStyle(
          color: _createTextPrimary,
          fontSize: 18,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEpisodeRow(String num, String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$num.',
          style: const TextStyle(
            color: _createTextSecondary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _createTextPrimary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(AIProductionPlan plan) {
    const maxVisible = 2;
    final visibleEps = plan.episodes.take(maxVisible).toList();
    final remaining = plan.episodes.length - maxVisible;
    final tags = plan.tags.isNotEmpty ? plan.tags : plan.showDraft.tags;
    final hostLabel = plan.showDraft.hostNames;
    final summaryLabel =
        '${plan.showDraft.primaryCategory} • $hostLabel • ${plan.episodes.length} episodes';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _createSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _createBorderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.seriesTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _createTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summaryLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: _createTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_note,
                    color: _createTextSecondary,
                    size: 24,
                  ),
                  onPressed: () => _openPlanDetail(plan),
                  tooltip: 'Edit Plan',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...tags.take(4).map(_buildTag),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group, color: _createTextMuted, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      hostLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _createTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...visibleEps.map(
                  (ep) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildEpisodeRow('${ep.episodeNumber}', ep.title),
                  ),
                ),
                if (remaining > 0)
                  Text(
                    '+ $remaining more episode${remaining > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: _createTextMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              plan.seriesDescription,
              style: TextStyle(
                color: _createTextSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled ? _createSurface : const Color(0xFFF8FAFC);
    final borderColor = enabled ? _createBorder : _createBorderSoft;
    final foregroundColor = enabled ? _createTextPrimary : _createTextSecondary;

    return Tooltip(
      message: 'New chat',
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onPressed : null,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Icon(CupertinoIcons.add, size: 18, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}

class _GuestCreateView extends StatelessWidget {
  const _GuestCreateView({required this.onSignIn, required this.onSignUp});

  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _createBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: _createSurface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: _createAccent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Dang nhap de tao show bang AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _createTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sau khi dang nhap, ban se giu duoc flow create hien tai va AI se chi thay the phan du lieu mock bang plan that.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _createTextSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: _createAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Dang nhap'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onSignUp,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _createSurface,
                    foregroundColor: _createTextPrimary,
                    side: const BorderSide(color: _createBorder),
                  ),
                  child: const Text('Tao tai khoan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
