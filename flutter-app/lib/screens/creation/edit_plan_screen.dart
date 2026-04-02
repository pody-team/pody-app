import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/features/ai/domain/ai_models.dart';
import 'package:pody/features/ai/presentation/ai_scope.dart';
import 'package:pody/state/player_state.dart';

const Color _planCanvas = Color(0xFFFFFBF6);
const Color _planSurface = Color(0xFFFFFEFC);
const Color _planSurfaceStrong = Color(0xFFF2E6D9);
const Color _planPrimary = Color(0xFFBF5700);
const Color _planNeutral = Color(0xFF3E2723);
const Color _planMuted = Color(0xFF7E665F);

class EditPlanScreen extends StatefulWidget {
  const EditPlanScreen({required this.plan, super.key});

  final AIProductionPlan plan;

  @override
  State<EditPlanScreen> createState() => _EditPlanScreenState();
}

class _EditPlanScreenState extends State<EditPlanScreen> {
  late final TextEditingController _seriesTitleController;
  late final TextEditingController _seriesDescriptionController;
  late final TextEditingController _toneStyleController;
  late bool _autoGenerateImages;
  late bool _autoGenerateIntroMusic;
  late final List<_EditableHost> _hosts;
  List<AIVoiceProfile> _availableVoices = const <AIVoiceProfile>[];
  bool _isLoadingVoices = true;
  String? _voiceLoadError;
  bool _hasRequestedVoiceProfiles = false;
  bool _isCreatingShow = false;
  final PlayerState _sharedPlayerState = PlayerState.instance;
  final ValueNotifier<int> _voicePreviewRefresh = ValueNotifier<int>(0);
  String? _previewingVoiceId;
  String? _loadingPreviewVoiceId;

  @override
  void initState() {
    super.initState();
    _sharedPlayerState.addListener(_handleSharedPlayerChanged);
    _seriesTitleController = TextEditingController(
      text: widget.plan.seriesTitle,
    );
    _seriesDescriptionController = TextEditingController(
      text: widget.plan.seriesDescription,
    );
    _toneStyleController = TextEditingController(
      text: widget.plan.toneStyle ?? '',
    );
    _autoGenerateImages = true;
    _autoGenerateIntroMusic = false;
    final draftHosts = widget.plan.showDraft.hosts;
    _hosts = draftHosts.isEmpty
        ? [_EditableHost(name: 'Host 1', voiceId: null, bio: '')]
        : draftHosts
              .map(
                (host) => _EditableHost(
                  name: host.displayName,
                  voiceId: _normalizeVoiceId(host.voiceProfileId),
                  role: host.role,
                  bio: host.personaSummary?.trim().isNotEmpty == true
                      ? host.personaSummary!
                      : (host.bio ?? ''),
                ),
              )
              .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasRequestedVoiceProfiles) {
      return;
    }
    _hasRequestedVoiceProfiles = true;
    _loadVoiceProfiles();
  }

  @override
  void dispose() {
    _sharedPlayerState.removeListener(_handleSharedPlayerChanged);
    _voicePreviewRefresh.dispose();
    _seriesTitleController.dispose();
    _seriesDescriptionController.dispose();
    _toneStyleController.dispose();
    super.dispose();
  }

  Future<void> _loadVoiceProfiles() async {
    setState(() {
      _isLoadingVoices = true;
      _voiceLoadError = null;
    });
    try {
      final voices = await AIScope.of(context).listVoiceProfiles();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableVoices = voices;
        _isLoadingVoices = false;
        _voiceLoadError = voices.isEmpty
            ? 'Chưa có giọng AI nào khả dụng từ hệ thống.'
            : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingVoices = false;
        _voiceLoadError =
            'Không tải được danh sách giọng AI. Thử lại sau ít phút nữa.';
      });
    }
  }

  String? _normalizeVoiceId(String? rawVoiceId) {
    final normalized = rawVoiceId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  AIVoiceProfile? _voiceProfileById(String? voiceId) {
    if (voiceId == null || voiceId.isEmpty) {
      return null;
    }
    for (final voice in _availableVoices) {
      if (voice.id == voiceId) {
        return voice;
      }
    }
    return null;
  }

  String _voiceLabel(String? voiceId) {
    if (_isLoadingVoices) {
      return 'Đang tải giọng...';
    }
    if (voiceId == null || voiceId.isEmpty) {
      return 'Chưa chọn giọng';
    }
    final voice = _voiceProfileById(voiceId);
    if (voice != null) {
      return voice.name;
    }
    return 'Giọng không còn khả dụng';
  }

  String _voiceDescription(AIVoiceProfile voice) {
    final segments = <String>[
      voice.languageCode.toUpperCase(),
      _genderLabel(voice.gender),
      voice.provider,
    ];
    return segments.where((value) => value.trim().isNotEmpty).join(' • ');
  }

  void _handleSharedPlayerChanged() {
    final nextPreviewingVoiceId = _sharedPlayerState.activePreviewId;
    final shouldClearLoading =
        _loadingPreviewVoiceId != null &&
        (nextPreviewingVoiceId == _loadingPreviewVoiceId ||
            !_sharedPlayerState.isPreviewBuffering);
    if (_previewingVoiceId == nextPreviewingVoiceId && !shouldClearLoading) {
      return;
    }
    _previewingVoiceId = nextPreviewingVoiceId;
    if (shouldClearLoading) {
      _loadingPreviewVoiceId = null;
    }
    _notifyVoicePreviewUi();
  }

  void _notifyVoicePreviewUi() {
    _voicePreviewRefresh.value++;
  }

  bool _hasVoicePreview(AIVoiceProfile voice) {
    final uri = _voicePreviewUri(voice);
    if (uri == null) {
      return false;
    }
    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty || host == 'example.com') {
      return false;
    }
    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  String _describeVoicePreviewError(Object error) {
    return error.toString();
  }

  Future<void> _stopVoicePreview() async {
    _previewingVoiceId = null;
    _loadingPreviewVoiceId = null;
    _notifyVoicePreviewUi();
    await _sharedPlayerState.stopPreview();
  }

  Future<void> _toggleVoicePreview(AIVoiceProfile voice) async {
    if (_loadingPreviewVoiceId == voice.id) {
      return;
    }

    final isCurrentVoice = _previewingVoiceId == voice.id;
    if (isCurrentVoice && _sharedPlayerState.isPreviewActive) {
      await _stopVoicePreview();
      return;
    }

    _loadingPreviewVoiceId = voice.id;
    _notifyVoicePreviewUi();
    try {
      await _playVoicePreview(voice);
    } catch (error, stackTrace) {
      final errorDetail = _describeVoicePreviewError(error);
      final sampleUrl = (voice.sampleAudioUrl ?? '').trim();
      debugPrint(
        'Voice preview failed'
        ' voice=${voice.name}'
        ' url=$sampleUrl'
        ' error=$errorDetail',
      );
      debugPrintStack(stackTrace: stackTrace);
      _previewingVoiceId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể phát audio mẫu của ${voice.name} lúc này.'
              ' ($errorDetail)',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _loadingPreviewVoiceId = null;
      _notifyVoicePreviewUi();
    }
  }

  Future<void> _playVoicePreview(AIVoiceProfile voice) async {
    final previewUri = _voicePreviewUri(voice);
    if (previewUri == null || !_hasVoicePreview(voice)) {
      throw StateError('Voice này chưa có audio mẫu khả dụng.');
    }

    await _sharedPlayerState.playPreview(
      previewId: voice.id,
      title: voice.name,
      audioUrl: previewUri.toString(),
    );
    _previewingVoiceId = voice.id;
  }

  Uri? _voicePreviewUri(AIVoiceProfile voice) {
    final sampleAudioUrl = (voice.sampleAudioUrl ?? '').trim();
    if (sampleAudioUrl.isEmpty) {
      return null;
    }
    return Uri.tryParse(sampleAudioUrl);
  }

  String _genderLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'male':
        return 'Nam';
      case 'female':
        return 'Nữ';
      case 'neutral':
        return 'Trung tính';
      default:
        return value.trim().isEmpty ? 'Không rõ' : value;
    }
  }

  void _openHostEditor(int hostIndex) {
    final host = _hosts[hostIndex];
    final nameController = TextEditingController(text: host.name);
    final bioController = TextEditingController(text: host.bio);
    String? selectedVoice = host.voiceId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: _planSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _planMuted.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Chỉnh sửa giọng nói',
                      style: GoogleFonts.newsreader(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _planNeutral,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PlanInput(
                      controller: nameController,
                      label: 'Tên host',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    _PlanInput(
                      controller: bioController,
                      label: 'Persona summary',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Chọn giọng nói AI',
                      style: GoogleFonts.workSans(
                        color: _planNeutral,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingVoices)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_voiceLoadError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _planSurfaceStrong,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _voiceLoadError!,
                              style: GoogleFonts.workSans(
                                color: _planNeutral,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _loadVoiceProfiles();
                              },
                              child: const Text('Tải lại'),
                            ),
                          ],
                        ),
                      )
                    else
                      ValueListenableBuilder<int>(
                        valueListenable: _voicePreviewRefresh,
                        builder: (_, _, _) {
                          return Column(
                            children: List.generate(_availableVoices.length, (
                              i,
                            ) {
                              final voice = _availableVoices[i];
                              final isSelected = selectedVoice == voice.id;
                              final hasPreview = _hasVoicePreview(voice);
                              final isLoadingPreview =
                                  _loadingPreviewVoiceId == voice.id;
                              final isPlayingPreview =
                                  _previewingVoiceId == voice.id &&
                                  _sharedPlayerState.isPreviewPlaying;
                              return GestureDetector(
                                onTap: () async {
                                  final wasSelected = selectedVoice == voice.id;
                                  setModalState(() => selectedVoice = voice.id);
                                  if (!wasSelected && hasPreview) {
                                    await _toggleVoicePreview(voice);
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _planPrimary.withValues(alpha: 0.10)
                                        : _planSurfaceStrong,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? _planPrimary
                                          : _planNeutral.withValues(
                                              alpha: 0.08,
                                            ),
                                      width: isSelected ? 1.4 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _planPrimary.withValues(
                                                  alpha: 0.14,
                                                )
                                              : _planSurface,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.graphic_eq,
                                          color: isSelected
                                              ? _planPrimary
                                              : _planMuted,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              voice.name,
                                              style: GoogleFonts.workSans(
                                                color: _planNeutral,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _voiceDescription(voice),
                                              style: GoogleFonts.workSans(
                                                color: _planMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (isLoadingPreview)
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  isSelected
                                                      ? _planPrimary
                                                      : _planMuted,
                                                ),
                                          ),
                                        )
                                      else if (isPlayingPreview)
                                        Icon(
                                          Icons.pause_circle_filled,
                                          color: isSelected
                                              ? _planPrimary
                                              : _planMuted,
                                          size: 24,
                                        )
                                      else if (!hasPreview)
                                        Icon(
                                          Icons.volume_off_outlined,
                                          color: _planMuted.withValues(
                                            alpha: 0.45,
                                          ),
                                          size: 24,
                                        ),
                                      if (isSelected)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 12,
                                          ),
                                          child: Icon(
                                            Icons.check_circle,
                                            color: _planPrimary,
                                            size: 20,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed:
                            (_isLoadingVoices ||
                                (_availableVoices.isNotEmpty &&
                                    selectedVoice == null))
                            ? null
                            : () {
                                setState(() {
                                  _hosts[hostIndex] = _EditableHost(
                                    name: nameController.text.trim().isNotEmpty
                                        ? nameController.text.trim()
                                        : host.name,
                                    voiceId: selectedVoice,
                                    role: host.role,
                                    bio: bioController.text.trim(),
                                  );
                                });
                                Navigator.pop(ctx);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: _planPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: GoogleFonts.workSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Lưu thay đổi'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(_stopVoicePreview);
  }

  Future<void> _createShowFromDraft() async {
    final title = _seriesTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Series title không được để trống.')),
      );
      return;
    }

    if (_isCreatingShow) {
      return;
    }

    setState(() => _isCreatingShow = true);
    try {
      final job = await AIScope.of(context).createShowFromPlan(widget.plan.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đang tạo "${widget.plan.seriesTitle}" bằng worker (${job.status}). App sẽ gửi thông báo khi xong.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể bắt đầu tạo show lúc này. Thử lại sau ít phút nữa.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingShow = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.plan.tags.isNotEmpty
        ? widget.plan.tags
        : widget.plan.showDraft.tags;

    return Scaffold(
      backgroundColor: _planCanvas,
      appBar: AppBar(
        backgroundColor: _planCanvas,
        surfaceTintColor: _planCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _planNeutral),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chỉnh sửa plan',
          style: GoogleFonts.newsreader(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _planNeutral,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Lưu',
              style: GoogleFonts.workSans(
                color: _planPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          left: 20,
          right: 20,
          top: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF4E6), Color(0xFFF4E7D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _planPrimary.withValues(alpha: 0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tinh chỉnh production plan',
                    style: GoogleFonts.newsreader(
                      color: _planNeutral,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Điều chỉnh title, host, tone và danh sách tập trước khi queue worker tạo show.',
                    style: GoogleFonts.workSans(
                      color: _planMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _PlanCard(
              title: 'Series',
              child: Column(
                children: [
                  _PlanInput(
                    controller: _seriesTitleController,
                    label: 'Series title',
                  ),
                  const SizedBox(height: 14),
                  _PlanInput(
                    controller: _seriesDescriptionController,
                    label: 'Series description',
                    maxLines: 3,
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags
                          .take(5)
                          .map((tag) => _PlanTag(label: tag))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _PlanCard(
              title: 'Hosts & voices',
              child: ValueListenableBuilder<int>(
                valueListenable: _voicePreviewRefresh,
                builder: (_, _, _) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(_hosts.length, (i) {
                      final host = _hosts[i];
                      final voice = _voiceProfileById(host.voiceId);
                      final voiceName = _voiceLabel(host.voiceId);
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 52) / 2,
                        child: _buildHostVoiceSelector(
                          name: host.name,
                          voiceType: voiceName,
                          canPreview: voice != null && _hasVoicePreview(voice),
                          isPreviewLoading:
                              voice != null &&
                              _loadingPreviewVoiceId == voice.id,
                          isPreviewPlaying:
                              voice != null &&
                              _previewingVoiceId == voice.id &&
                              _sharedPlayerState.isPreviewPlaying,
                          onPreviewTap: voice == null
                              ? null
                              : () => _toggleVoicePreview(voice),
                          onTap: () => _openHostEditor(i),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _PlanCard(
              title: 'Tone & style',
              child: _PlanInput(
                controller: _toneStyleController,
                label: 'Tone description',
              ),
            ),
            const SizedBox(height: 18),
            _PlanCard(
              title: 'AI generation',
              child: Column(
                children: [
                  _buildToggleRow(
                    icon: Icons.image_outlined,
                    title: 'Tự tạo cover image',
                    value: _autoGenerateImages,
                    onChanged: (val) =>
                        setState(() => _autoGenerateImages = val),
                  ),
                  const SizedBox(height: 8),
                  _buildToggleRow(
                    icon: Icons.music_note_outlined,
                    title: 'Tự tạo intro music',
                    value: _autoGenerateIntroMusic,
                    onChanged: (val) =>
                        setState(() => _autoGenerateIntroMusic = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _PlanCard(
              title: 'Episodes',
              child: Column(
                children: widget.plan.episodes
                    .map(
                      (ep) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildEpisodeEditorCard(
                          num: '${ep.episodeNumber}',
                          title: ep.title,
                          description: ep.description,
                          duration: '${ep.estimatedDurationSeconds ~/ 60}',
                          notes: ep.notes ?? '',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isCreatingShow ? null : _createShowFromDraft,
                style: FilledButton.styleFrom(
                  backgroundColor: _planPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: GoogleFonts.workSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  _isCreatingShow ? 'Đang tạo...' : 'Tạo show từ bản draft này',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeEditorCard({
    required String num,
    required String title,
    required String description,
    required String duration,
    required String notes,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _planSurfaceStrong,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _planSurface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  num,
                  style: GoogleFonts.workSans(
                    color: _planPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Episode details',
                style: GoogleFonts.workSans(
                  color: _planNeutral,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: _buildMiniTextField('Title', title)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniTextField(
                  'Duration',
                  duration,
                  suffixText: 'min',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMiniTextField('Description', description, maxLines: 2),
          const SizedBox(height: 8),
          _buildMiniTextField('Notes', notes, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildMiniTextField(
    String label,
    String text, {
    int maxLines = 1,
    String? suffixText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.workSans(
            color: _planMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: text),
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.workSans(color: _planNeutral, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: _planSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixText: suffixText,
            suffixStyle: GoogleFonts.workSans(color: _planMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildHostVoiceSelector({
    required String name,
    required String voiceType,
    required bool canPreview,
    required bool isPreviewLoading,
    required bool isPreviewPlaying,
    required VoidCallback? onPreviewTap,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _planSurfaceStrong,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: _planPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.workSans(
                                color: _planNeutral,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.graphic_eq,
                            color: _planMuted,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              voiceType,
                              style: GoogleFonts.workSans(
                                color: _planMuted,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: _planMuted,
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: canPreview ? 'Nghe thử $voiceType' : 'Chưa có audio mẫu',
            onPressed: onPreviewTap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: isPreviewLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isPreviewPlaying
                        ? Icons.pause_circle_filled
                        : canPreview
                        ? Icons.play_circle_outline
                        : Icons.volume_off_outlined,
                    color: canPreview
                        ? _planPrimary
                        : _planMuted.withValues(alpha: 0.45),
                    size: 22,
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _planSurfaceStrong,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: _planPrimary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.workSans(
                color: _planNeutral,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _planPrimary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: _planMuted.withValues(alpha: 0.28),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _planSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _planNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.newsreader(
              color: _planNeutral,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PlanInput extends StatelessWidget {
  const _PlanInput({
    required this.controller,
    required this.label,
    this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.workSans(color: _planNeutral),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.workSans(color: _planMuted),
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: _planPrimary, size: 18),
        filled: true,
        fillColor: _planSurfaceStrong,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

class _PlanTag extends StatelessWidget {
  const _PlanTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _planSurfaceStrong,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.workSans(
          color: _planPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditableHost {
  const _EditableHost({
    required this.name,
    required this.voiceId,
    required this.bio,
    this.role = 'host',
  });

  final String name;
  final String? voiceId;
  final String bio;
  final String role;
}
