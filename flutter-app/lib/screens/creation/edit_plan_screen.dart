import 'package:flutter/material.dart';
import 'package:pody/features/ai/domain/ai_models.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/screens/user/create_show_screen.dart';

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
                  bio:
                      host.personaSummary?.trim().isNotEmpty == true
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
                color: Color(0xFF252525),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Chỉnh sửa giọng nói',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tên host',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Persona summary',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bioController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Chọn giọng nói AI',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
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
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(
                                    0xFFFE2C55,
                                  ).withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(
                                      0xFFFE2C55,
                                    ).withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.06),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(
                                          0xFFFE2C55,
                                        ).withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.graphic_eq,
                                  color: isSelected
                                      ? const Color(0xFFFE2C55)
                                      : Colors.white38,
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
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      voice['desc']!,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFFE2C55),
                                  size: 22,
                                )
                              else
                                Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white.withValues(alpha: 0.2),
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
                      height: 48,
                      child: ElevatedButton(
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFE2C55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Lưu thay đổi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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
        const SnackBar(content: Text('Series title khong duoc de trong.')),
      );
      return;
    }

    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => CreateShowScreen(initialSeed: _buildSeed()),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    Navigator.of(context).pop(result);
  }

  ContentCreateShowSeed _buildSeed() {
    return ContentCreateShowSeed(
      title: _seriesTitleController.text.trim(),
      description: _seriesDescriptionController.text.trim(),
      primaryCategory: widget.plan.showDraft.primaryCategory,
      coverImageUrl: widget.plan.showDraft.coverImageUrl,
      contentType: widget.plan.showDraft.contentType,
      hosts: _hosts
          .map(
            (host) => ContentCreateHostInput(
              displayName: host.name,
              role: host.role,
              voiceProfileId: host.voiceId,
              bio: host.bio.trim().isEmpty ? null : host.bio.trim(),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.plan.tags.isNotEmpty
        ? widget.plan.tags
        : widget.plan.showDraft.tags;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Production Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          left: 16,
          right: 16,
          top: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Series Title',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _seriesTitleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Series Description',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _seriesDescriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .take(5)
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Hosts & Voices',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(_hosts.length, (i) {
                final host = _hosts[i];
                final voiceName = _voiceLabel(host.voiceId);
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 44) / 2,
                  child: _buildHostVoiceSelector(
                    name: host.name,
                    voiceType: voiceName,
                    onTap: () => _openHostEditor(i),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tone & Style',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _toneStyleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Generation',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildToggleRow(
                    icon: Icons.image_outlined,
                    title: 'Auto-generate Cover Images',
                    value: _autoGenerateImages,
                    onChanged: (val) =>
                        setState(() => _autoGenerateImages = val),
                  ),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  _buildToggleRow(
                    icon: Icons.music_note_outlined,
                    title: 'Auto-generate Intro Music',
                    value: _autoGenerateIntroMusic,
                    onChanged: (val) =>
                        setState(() => _autoGenerateIntroMusic = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Episodes',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.plan.episodes.map(
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
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createShowFromDraft,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFE2C55),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Tạo show từ bản draft này',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  num,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Episode Details',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              const Icon(Icons.drag_indicator, color: Colors.white24, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: _buildMiniTextField('Title', title)),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
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
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: text),
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            suffixText: suffixText,
            suffixStyle: const TextStyle(color: Colors.white54, fontSize: 13),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.graphic_eq, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    voiceType,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white54,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white38,
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
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
