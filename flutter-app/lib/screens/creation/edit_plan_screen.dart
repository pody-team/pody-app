import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/features/ai/domain/ai_models.dart';
import 'package:pody/features/ai/presentation/ai_scope.dart';

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
  bool _isCreatingShow = false;

  static const List<Map<String, String>> _availableVoices = [
    {
      'id': 'v_male_deep',
      'name': 'Nam trầm',
      'desc': 'Giọng nam trầm ấm, phù hợp tin tức',
    },
    {
      'id': 'v_male_young',
      'name': 'Nam trẻ',
      'desc': 'Giọng nam trẻ năng động',
    },
    {
      'id': 'v_female_warm',
      'name': 'Nữ ấm',
      'desc': 'Giọng nữ ấm áp, thân thiện',
    },
    {
      'id': 'v_female_pro',
      'name': 'Nữ chuyên nghiệp',
      'desc': 'Giọng nữ rõ ràng, chuyên nghiệp',
    },
    {
      'id': 'v_neutral',
      'name': 'Trung tính',
      'desc': 'Giọng trung tính, đa năng',
    },
    {
      'id': 'v_narrator',
      'name': 'Narrator',
      'desc': 'Giọng kể chuyện điềm đạm',
    },
  ];

  @override
  void initState() {
    super.initState();
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
        ? [_EditableHost(name: 'Nova', voiceId: 'v_neutral', bio: '')]
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
  void dispose() {
    _seriesTitleController.dispose();
    _seriesDescriptionController.dispose();
    _toneStyleController.dispose();
    super.dispose();
  }

  String _normalizeVoiceId(String? rawVoiceId) {
    for (final voice in _availableVoices) {
      if (voice['id'] == rawVoiceId) {
        return rawVoiceId!;
      }
    }
    return 'v_neutral';
  }

  String _voiceLabel(String? voiceId) {
    for (final voice in _availableVoices) {
      if (voice['id'] == voiceId) {
        return voice['name']!;
      }
    }
    return 'AI Voice';
  }

  void _openHostEditor(int hostIndex) {
    final host = _hosts[hostIndex];
    final nameController = TextEditingController(text: host.name);
    final bioController = TextEditingController(text: host.bio);
    String selectedVoice = host.voiceId;

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
                    ...List.generate(_availableVoices.length, (i) {
                      final voice = _availableVoices[i];
                      final isSelected = selectedVoice == voice['id'];
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => selectedVoice = voice['id']!);
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
                                  : _planNeutral.withValues(alpha: 0.08),
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
                                      ? _planPrimary.withValues(alpha: 0.14)
                                      : _planSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.graphic_eq,
                                  color: isSelected ? _planPrimary : _planMuted,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      voice['name']!,
                                      style: GoogleFonts.workSans(
                                        color: _planNeutral,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      voice['desc']!,
                                      style: GoogleFonts.workSans(
                                        color: _planMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.play_circle_outline,
                                color: isSelected ? _planPrimary : _planMuted,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
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
    );
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
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(_hosts.length, (i) {
                  final host = _hosts[i];
                  final voiceName = _voiceLabel(host.voiceId);
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    child: _buildHostVoiceSelector(
                      name: host.name,
                      voiceType: voiceName,
                      onTap: () => _openHostEditor(i),
                    ),
                  );
                }),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _planSurfaceStrong,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: _planPrimary, size: 16),
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
                const Icon(Icons.graphic_eq, color: _planMuted, size: 14),
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
  final String voiceId;
  final String bio;
  final String role;
}
