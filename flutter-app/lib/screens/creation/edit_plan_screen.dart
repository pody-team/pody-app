import 'package:flutter/material.dart';
import 'package:pody/data/mock_data.dart';
import 'package:pody/models/models.dart';

class EditPlanScreen extends StatefulWidget {
  const EditPlanScreen({super.key});

  @override
  State<EditPlanScreen> createState() => _EditPlanScreenState();
}

class _EditPlanScreenState extends State<EditPlanScreen> {
  late final ProductionPlan _plan = MockData.samplePlan;
  late bool _autoGenerateImages = _plan.autoGenerateImages;
  late bool _autoGenerateIntroMusic = _plan.autoGenerateIntroMusic;
  late List<Host> _hosts = List.from(_plan.hosts);

  // Available AI voices
  static const List<Map<String, String>> _availableVoices = [
    {'id': 'v_male_deep', 'name': 'Nam trầm', 'desc': 'Giọng nam trầm ấm, phù hợp tin tức'},
    {'id': 'v_male_young', 'name': 'Nam trẻ', 'desc': 'Giọng nam trẻ năng động'},
    {'id': 'v_female_warm', 'name': 'Nữ ấm', 'desc': 'Giọng nữ ấm áp, thân thiện'},
    {'id': 'v_female_pro', 'name': 'Nữ chuyên nghiệp', 'desc': 'Giọng nữ rõ ràng, chuyên nghiệp'},
    {'id': 'v_neutral', 'name': 'Trung tính', 'desc': 'Giọng trung tính, đa năng'},
    {'id': 'v_narrator', 'name': 'Narrator', 'desc': 'Giọng kể chuyện điềm đạm'},
  ];

  void _openHostEditor(int hostIndex) {
    final host = _hosts[hostIndex];
    final nameController = TextEditingController(text: host.name);
    String selectedVoice = host.voiceId ?? 'v_male_deep';

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
                    // Handle
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

                    // Title
                    const Text(
                      'Chỉnh sửa giọng nói',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Host name
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: const Icon(Icons.person, color: Colors.white38, size: 20),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Voice selection
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
                                ? const Color(0xFFFE2C55).withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFE2C55).withValues(alpha: 0.4)
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
                                      ? const Color(0xFFFE2C55).withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.graphic_eq,
                                  color: isSelected ? const Color(0xFFFE2C55) : Colors.white38,
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
                                        color: isSelected ? Colors.white : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      voice['desc']!,
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Color(0xFFFE2C55), size: 22),
                              if (!isSelected)
                                Icon(Icons.play_circle_outline,
                                    color: Colors.white.withValues(alpha: 0.2), size: 22),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _hosts[hostIndex] = Host(
                              id: host.id,
                              name: nameController.text.trim().isNotEmpty
                                  ? nameController.text.trim()
                                  : host.name,
                              avatarUrl: host.avatarUrl,
                              voiceId: selectedVoice,
                              role: host.role,
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

  @override
  Widget build(BuildContext context) {
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
            // Series Title
            const Text(
              'Series Title',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _plan.seriesTitle),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Series Description
            const Text(
              'Series Description',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _plan.seriesDescription),
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Hosts & Voices
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
                // Resolve voice name
                final voiceName = _availableVoices
                    .where((v) => v['id'] == host.voiceId)
                    .map((v) => v['name']!)
                    .firstOrNull ?? host.voiceId ?? host.role;
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

            // Tone & Style
            const Text(
              'Tone & Style',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _plan.toneStyle),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // AI Generation
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
                    onChanged: (val) => setState(() => _autoGenerateImages = val),
                  ),
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                  _buildToggleRow(
                    icon: Icons.music_note_outlined,
                    title: 'Auto-generate Intro Music',
                    value: _autoGenerateIntroMusic,
                    onChanged: (val) => setState(() => _autoGenerateIntroMusic = val),
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

            // Episode cards from plan
            ..._plan.episodes.map((ep) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEpisodeEditorCard(
                num: '${ep.number}',
                title: ep.title,
                description: ep.description,
                duration: '${ep.estimatedDuration.inMinutes}',
                notes: ep.notes,
              ),
            )),
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
