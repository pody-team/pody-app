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

enum _CreateSidebarSection { chats, drafts }

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const _headerInset = 84.0;
  static const _composerDockBottom = 32.0;
  static const _composerBottomGap = 8.0;
  static const _wideHistoryBreakpoint = 1080.0;
  static const _promptSuggestions = <String>[
    'Tao mot show tin cong nghe moi sang cho founder va product manager.',
    'Len concept show ke chuyen lich su Viet Nam theo goc nhin gan gui, de nghe.',
    'Giup toi xay mot podcast hoc tieng Anh bang tinh huong cong so hang ngay.',
  ];

  final List<String> _attachedFiles = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _statusPulseTimer;
  Timer? _statusClearTimer;
  Timer? _statusAdvanceTimer;
  AIChatThread? _thread;
  StreamSubscription<AIChatStreamEvent>? _streamSubscription;
  bool _isSending = false;
  String? _errorMessage;
  String? _activeUserId;
  String? _pendingUserMessage;
  String? _streamingStatus;
  List<String> _streamingStatusHistory = const [];
  List<String> _pendingStatusQueue = const [];
  List<String> _streamDebugTrail = const [];
  String _streamingAssistantText = '';
  AIProductionPlan? _streamingPlanPreview;
  int _statusPulseTick = 0;
  _CreateSidebarSection _sidebarSection = _CreateSidebarSection.chats;
  Future<List<AIChatThreadSummary>>? _threadHistoryFuture;
  Future<List<AIProductionPlanSummary>>? _draftListFuture;

  @override
  void dispose() {
    _statusPulseTimer?.cancel();
    _statusClearTimer?.cancel();
    _statusAdvanceTimer?.cancel();
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
    _statusPulseTimer?.cancel();
    _statusPulseTimer = null;
    _statusClearTimer?.cancel();
    _statusClearTimer = null;
    _statusAdvanceTimer?.cancel();
    _statusAdvanceTimer = null;
    _streamSubscription?.cancel();
    _thread = null;
    _isSending = false;
    _errorMessage = null;
    _pendingUserMessage = null;
    _streamingStatus = null;
    _streamingStatusHistory = const [];
    _streamDebugTrail = const [];
    _streamingAssistantText = '';
    _streamingPlanPreview = null;
    _statusPulseTick = 0;
    _sidebarSection = _CreateSidebarSection.chats;
    _threadHistoryFuture = userId == null ? null : AIScope.of(context).listThreads();
    _draftListFuture = userId == null ? null : AIScope.of(context).listDrafts();
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
      _streamingStatus = 'Đang suy nghĩ';
      _streamingStatusHistory = const ['Đang suy nghĩ'];
      _pendingStatusQueue = const [];
      _streamDebugTrail = const ['thinking'];
      _streamingAssistantText = '';
      _streamingPlanPreview = null;
    });
    _statusClearTimer?.cancel();
    _statusClearTimer = null;
    _statusAdvanceTimer?.cancel();
    _statusAdvanceTimer = null;
    _startStatusPulse();

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
          _streamingStatusHistory = const [];
          _pendingStatusQueue = const [];
          _streamDebugTrail = const [];
          _streamingAssistantText = '';
          _streamingPlanPreview = null;
        });
        _stopStatusPulse();
        _statusClearTimer?.cancel();
        _statusClearTimer = null;
        _statusAdvanceTimer?.cancel();
        _statusAdvanceTimer = null;
      },
      onDone: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _isSending = false;
        });
        _stopStatusPulse();
        _scheduleStatusClear();
      },
      cancelOnError: false,
    );
  }

  void _startStatusPulse() {
    _statusPulseTimer?.cancel();
    _statusPulseTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted || !_isSending) {
        return;
      }
      setState(() {
        _statusPulseTick = (_statusPulseTick + 1) % 3;
      });
    });
  }

  void _stopStatusPulse() {
    _statusPulseTimer?.cancel();
    _statusPulseTimer = null;
    if (_statusPulseTick == 0) {
      return;
    }
    setState(() {
      _statusPulseTick = 0;
    });
  }

  void _scheduleStatusClear() {
    _statusClearTimer?.cancel();
    _statusClearTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _streamingStatus = null;
        _streamingStatusHistory = const [];
        _pendingStatusQueue = const [];
      });
    });
  }

  void _scheduleNextQueuedStatus() {
    if (_statusAdvanceTimer != null) {
      return;
    }
    _statusAdvanceTimer = Timer(const Duration(milliseconds: 850), () {
      _statusAdvanceTimer?.cancel();
      _statusAdvanceTimer = null;
      if (!mounted) {
        return;
      }
      if (_pendingStatusQueue.isNotEmpty) {
        final nextStatus = _pendingStatusQueue.first;
        setState(() {
          _pendingStatusQueue = _pendingStatusQueue.sublist(1);
          _streamingStatus = nextStatus;
          _pushStreamingStatus(nextStatus);
        });
        _scheduleNextQueuedStatus();
        return;
      }
      if (!_isSending) {
        _scheduleStatusClear();
      }
    });
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
    _stopStatusPulse();
    _statusClearTimer?.cancel();
    _statusClearTimer = null;
    _statusAdvanceTimer?.cancel();
    _statusAdvanceTimer = null;
    _streamSubscription?.cancel();
    setState(() {
      _sidebarSection = _CreateSidebarSection.chats;
      _thread = null;
      _isSending = false;
      _errorMessage = null;
      _pendingUserMessage = null;
      _streamingStatus = null;
      _streamingStatusHistory = const [];
      _pendingStatusQueue = const [];
      _streamDebugTrail = const [];
      _streamingAssistantText = '';
      _streamingPlanPreview = null;
      _attachedFiles.clear();
      _messageController.clear();
    });
    _scrollToTop();
  }

  void _openThreadHistoryDrawer() {
    if (_isSending) {
      return;
    }
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _selectThread(String threadId) async {
    FocusScope.of(context).unfocus();
    final repository = AIScope.of(context);
    await _streamSubscription?.cancel();
    _statusClearTimer?.cancel();
    _statusClearTimer = null;
    _statusAdvanceTimer?.cancel();
    _statusAdvanceTimer = null;

    setState(() {
      _errorMessage = null;
      _pendingUserMessage = null;
      _streamingStatus = null;
      _streamingStatusHistory = const [];
      _pendingStatusQueue = const [];
      _streamDebugTrail = const [];
      _streamingAssistantText = '';
      _streamingPlanPreview = null;
      _attachedFiles.clear();
      _messageController.clear();
    });

    try {
      final thread = await repository.getThread(threadId);
      if (!mounted) {
        return;
      }
      setState(() {
        _sidebarSection = _CreateSidebarSection.chats;
        _thread = thread;
        _threadHistoryFuture = repository.listThreads();
        _draftListFuture = repository.listDrafts();
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _humanizeError(error);
      });
    }
  }

  void _handleStreamEvent(AIChatStreamEvent event) {
    _pushDebugEvent(event.debugLabel);
    switch (event.type) {
      case AIChatStreamEventType.status:
        _statusClearTimer?.cancel();
        _statusClearTimer = null;
        final normalizedStatus = _normalizedStatusText(event.message ?? '').trim();
        if (normalizedStatus.isEmpty) {
          break;
        }
        final isThinkingOnly = event.debugLabel?.trim() == 'thinking';
        if (!isThinkingOnly) {
          _statusAdvanceTimer?.cancel();
          _statusAdvanceTimer = null;
          setState(() {
            final prev = _streamingStatus;
            if (prev != null) {
              final prevNorm = _normalizedStatusText(prev).trim();
              if (prevNorm != normalizedStatus) {
                _pushStreamingStatus(prev);
              }
            }
            _streamingStatus = normalizedStatus;
            _pushStreamingStatus(normalizedStatus);
          });
          _scheduleNextQueuedStatus();
          _scrollToBottom();
          break;
        }
        setState(() {
          final prevNorm = _streamingStatus == null
              ? ''
              : _normalizedStatusText(_streamingStatus!).trim();
          if (_streamingStatus == null) {
            _streamingStatus = normalizedStatus;
            _pushStreamingStatus(normalizedStatus);
          } else if (prevNorm != normalizedStatus &&
              (_pendingStatusQueue.isEmpty ||
                  _pendingStatusQueue.last != normalizedStatus)) {
            _pendingStatusQueue = <String>[
              ..._pendingStatusQueue,
              normalizedStatus,
            ];
          }
        });
        _scheduleNextQueuedStatus();
        _scrollToBottom();
        break;
      case AIChatStreamEventType.assistantDelta:
        setState(() {
          _streamingAssistantText += event.deltaText ?? '';
        });
        _scrollToBottom();
        break;
      case AIChatStreamEventType.planUpdated:
        setState(() {
          _streamingPlanPreview = event.plan;
        });
        _scrollToBottom();
        break;
      case AIChatStreamEventType.thread:
        final repository = AIScope.of(context);
        setState(() {
          _thread = event.thread;
          _errorMessage = null;
          _pendingUserMessage = null;
          _streamingAssistantText = '';
          _streamingPlanPreview = null;
          _threadHistoryFuture = repository.listThreads();
          _draftListFuture = repository.listDrafts();
        });
        _scrollToBottom();
        break;
      case AIChatStreamEventType.done:
        setState(() {
          _isSending = false;
        });
        _stopStatusPulse();
        if (_statusAdvanceTimer == null && _pendingStatusQueue.isEmpty) {
          _scheduleStatusClear();
        }
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
          _streamingStatusHistory = const [];
          _pendingStatusQueue = const [];
          _streamDebugTrail = const [];
          _streamingAssistantText = '';
          _streamingPlanPreview = null;
        });
        _stopStatusPulse();
        _statusClearTimer?.cancel();
        _statusClearTimer = null;
        _statusAdvanceTimer?.cancel();
        _statusAdvanceTimer = null;
        break;
    }
  }

  void _pushStreamingStatus(String? message) {
    final normalized = _normalizedStatusText(message ?? '').trim();
    if (normalized.isEmpty) {
      return;
    }
    if (_streamingStatusHistory.isNotEmpty &&
        _streamingStatusHistory.last == normalized) {
      return;
    }
    _streamingStatusHistory = <String>[
      ..._streamingStatusHistory,
      normalized,
    ];
  }

  void _pushDebugEvent(String? label) {
    final normalized = (label ?? '').trim();
    if (normalized.isEmpty) {
      return;
    }
    if (_streamDebugTrail.isNotEmpty && _streamDebugTrail.last == normalized) {
      return;
    }
    final next = <String>[..._streamDebugTrail, normalized];
    _streamDebugTrail = next.length <= 8
        ? next
        : next.sublist(next.length - 8);
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

  void _showChatsSection() {
    setState(() {
      _sidebarSection = _CreateSidebarSection.chats;
    });
  }

  void _showDraftsSection() {
    setState(() {
      _sidebarSection = _CreateSidebarSection.drafts;
    });
  }

  Future<void> _openDraft(String draftId) async {
    FocusScope.of(context).unfocus();
    final repository = AIScope.of(context);

    try {
      final draft = await repository.getDraft(draftId);
      if (!mounted) {
        return;
      }
      await _openPlanDetail(draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _humanizeError(error);
      });
    }
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
        if (_streamingAssistantText.isNotEmpty ||
            _streamingStatus != null ||
            _streamingStatusHistory.isNotEmpty ||
            _streamingPlanPreview != null)
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

    if (_streamingAssistantText.isNotEmpty ||
        _streamingStatus != null ||
        _streamingStatusHistory.isNotEmpty ||
        _streamingPlanPreview != null) {
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

  Widget _buildWorkspace(
    BuildContext context, {
    required bool showHistoryButton,
  }) {
    final canResetThread = _thread != null && !_isSending;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;
    final baseComposerBottom = safeBottom + _composerDockBottom;
    final composerBottom = math.max(
      baseComposerBottom,
      bottomInset + _composerBottomGap,
    );
    final conversationBottomPadding = composerBottom + 132;

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16 + _headerInset,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            border: Border.all(color: _createBorderSoft),
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
                      decoration: const BoxDecoration(
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
        if (showHistoryButton)
          Positioned(
            top: 8,
            left: 16,
            child: _HistoryButton(
              enabled: !_isSending,
              onPressed: _openThreadHistoryDrawer,
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
    );
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

    final mediaQuery = MediaQuery.of(context);
    final isWideLayout = mediaQuery.size.width >= _wideHistoryBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _createBg,
      resizeToAvoidBottomInset: false,
      drawer: isWideLayout
          ? null
          : Drawer(
              backgroundColor: _createBg,
              child: _ThreadHistoryPanel(
                threadsFuture: _threadHistoryFuture,
                draftsFuture: _draftListFuture,
                currentThreadId: _thread?.id,
                section: _sidebarSection,
                onSelectThread: (threadId) {
                  Navigator.of(context).pop();
                  _selectThread(threadId);
                },
                onOpenDraft: (draftId) {
                  Navigator.of(context).pop();
                  _openDraft(draftId);
                },
                onNewChat: () {
                  Navigator.of(context).pop();
                  _resetThread();
                },
                onShowChats: _showChatsSection,
                onShowDrafts: _showDraftsSection,
                compact: true,
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: isWideLayout
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 320,
                    child: _ThreadHistoryPanel(
                      threadsFuture: _threadHistoryFuture,
                      draftsFuture: _draftListFuture,
                      currentThreadId: _thread?.id,
                      section: _sidebarSection,
                      onSelectThread: _selectThread,
                      onOpenDraft: _openDraft,
                      onNewChat: _resetThread,
                      onShowChats: _showChatsSection,
                      onShowDrafts: _showDraftsSection,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: _buildWorkspace(
                          context,
                          showHistoryButton: false,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 768),
                  child: _buildWorkspace(context, showHistoryButton: true),
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
    final statusHistory = _streamingStatusHistory;
    final currentStatus = _streamingStatus == null
        ? null
        : _normalizedStatusText(_streamingStatus!);
    final previousStatuses = currentStatus == null
        ? statusHistory
        : statusHistory.where((status) => status != currentStatus).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_streamDebugTrail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'debug: ${_streamDebugTrail.join(' -> ')}',
                style: const TextStyle(
                  color: _createTextMuted,
                  fontSize: 11,
                  height: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          if (previousStatuses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: previousStatuses
                    .map(
                      (status) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _createSurfaceSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _createBorderSoft),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: _createTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (_streamingAssistantText.isNotEmpty)
            _buildAssistantMarkdown(_streamingAssistantText),
          if (_streamingStatus != null)
            Padding(
              padding: EdgeInsets.only(
                top: _streamingAssistantText.isNotEmpty ? 10 : 0,
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: _createTextSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: currentStatus),
                    TextSpan(text: '.' * (_statusPulseTick + 1)),
                  ],
                ),
              ),
            ),
          if (_streamingPlanPreview != null) ...[
            const SizedBox(height: 16),
            _buildPlanCard(_streamingPlanPreview!),
          ],
        ],
      ),
    );
  }

  String _normalizedStatusText(String value) {
    final trimmed = value.trimRight();
    final normalized = trimmed.replaceFirst(RegExp(r'(?:\.\.\.|…)+$'), '');
    return normalized;
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

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled ? _createSurface : const Color(0xFFF8FAFC);
    final borderColor = enabled ? _createBorder : _createBorderSoft;
    final foregroundColor = enabled ? _createTextPrimary : _createTextSecondary;

    return Tooltip(
      message: 'Lịch sử chat',
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
            child: Icon(
              CupertinoIcons.time,
              size: 18,
              color: foregroundColor,
            ),
          ),
        ),
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

class _ThreadHistoryPanel extends StatelessWidget {
  const _ThreadHistoryPanel({
    required this.threadsFuture,
    required this.draftsFuture,
    required this.currentThreadId,
    required this.section,
    required this.onSelectThread,
    required this.onOpenDraft,
    required this.onNewChat,
    required this.onShowChats,
    required this.onShowDrafts,
    this.compact = false,
  });

  final Future<List<AIChatThreadSummary>>? threadsFuture;
  final Future<List<AIProductionPlanSummary>>? draftsFuture;
  final String? currentThreadId;
  final _CreateSidebarSection section;
  final ValueChanged<String> onSelectThread;
  final ValueChanged<String> onOpenDraft;
  final VoidCallback onNewChat;
  final VoidCallback onShowChats;
  final VoidCallback onShowDrafts;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDraftSection = section == _CreateSidebarSection.drafts;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _createBg,
        border: Border(right: BorderSide(color: _createBorderSoft)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, compact ? 16 : 20, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SidebarActionButton(
                label: 'New chat',
                selected: !isDraftSection && currentThreadId == null,
                onTap: onNewChat,
              ),
              const SizedBox(height: 4),
              _SidebarActionButton(
                label: 'Chats',
                selected: !isDraftSection,
                onTap: onShowChats,
              ),
              const SizedBox(height: 4),
              _SidebarActionButton(
                label: 'Drafts',
                selected: isDraftSection,
                onTap: onShowDrafts,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  isDraftSection ? 'Tất cả draft' : 'Gần đây',
                  style: const TextStyle(
                    color: _createTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: isDraftSection
                    ? FutureBuilder<List<AIProductionPlanSummary>>(
                        future: draftsFuture,
                        builder: (context, snapshot) {
                          final drafts =
                              snapshot.data ?? const <AIProductionPlanSummary>[];
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Padding(
                              padding: EdgeInsets.fromLTRB(8, 12, 8, 24),
                              child: Text(
                                'Chưa tải được danh sách draft. Thử lại sau ít phút nữa.',
                                style: TextStyle(
                                  color: _createDanger,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            );
                          }
                          if (drafts.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.fromLTRB(8, 12, 8, 24),
                              child: Text(
                                'Bạn chưa có bản draft nào.',
                                style: TextStyle(
                                  color: _createTextSecondary,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: drafts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 2),
                            itemBuilder: (context, index) {
                              final draft = drafts[index];
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => onOpenDraft(draft.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                draft.seriesTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: _createTextPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatThreadTimestamp(
                                                draft.updatedAt,
                                              ),
                                              style: const TextStyle(
                                                color: _createTextMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${draft.contentType} • ${draft.episodeCount} tập',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _createTextSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      )
                    : FutureBuilder<List<AIChatThreadSummary>>(
                        future: threadsFuture,
                        builder: (context, snapshot) {
                          final threads =
                              snapshot.data ?? const <AIChatThreadSummary>[];
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Padding(
                              padding: EdgeInsets.fromLTRB(8, 12, 8, 24),
                              child: Text(
                                'Chưa tải được lịch sử chat. Thử lại sau ít phút nữa.',
                                style: TextStyle(
                                  color: _createDanger,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            );
                          }
                          if (threads.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.fromLTRB(8, 12, 8, 24),
                              child: Text(
                                'Bạn chưa có cuộc trò chuyện nào.',
                                style: TextStyle(
                                  color: _createTextSecondary,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: threads.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 2),
                            itemBuilder: (context, index) {
                              final thread = threads[index];
                              final isCurrent = thread.id == currentThreadId;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    onShowChats();
                                    onSelectThread(thread.id);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? _createAccentSoft
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            thread.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: _createTextPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatThreadTimestamp(
                                            thread.updatedAt,
                                          ),
                                          style: const TextStyle(
                                            color: _createTextMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarActionButton extends StatelessWidget {
  const _SidebarActionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _createAccentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _createTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

String _formatThreadTimestamp(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final isToday =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (isToday) {
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month';
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
