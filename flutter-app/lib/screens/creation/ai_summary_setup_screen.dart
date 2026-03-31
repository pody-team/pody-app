import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _summaryCanvas = Color(0xFFFFFBF6);
const Color _summarySurface = Color(0xFFFFFEFC);
const Color _summarySurfaceStrong = Color(0xFFF2E6D9);
const Color _summaryPrimary = Color(0xFFBF5700);
const Color _summaryNeutral = Color(0xFF3E2723);
const Color _summaryMuted = Color(0xFF7E665F);

class AiSummarySetupScreen extends StatefulWidget {
  const AiSummarySetupScreen({super.key});

  @override
  State<AiSummarySetupScreen> createState() => _AiSummarySetupScreenState();
}

class _AiSummarySetupScreenState extends State<AiSummarySetupScreen> {
  final List<String> _allTopics = [
    'Tech',
    'Finance',
    'AI',
    'World',
    'Startups',
    'Crypto',
  ];
  final Set<String> _selectedTopics = {'Tech', 'Finance', 'AI'};

  String _deliveryTime = '08:00 AM';
  String _frequency = 'Daily';
  int _selectedDuration = 0;
  int _selectedTone = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _summaryCanvas,
      appBar: AppBar(
        backgroundColor: _summaryCanvas,
        surfaceTintColor: _summaryCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _summaryNeutral),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Thiết lập bản tin AI',
          style: GoogleFonts.newsreader(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _summaryNeutral,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
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
              border: Border.all(
                color: _summaryPrimary.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _summarySurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Daily digest',
                    style: GoogleFonts.workSans(
                      color: _summaryPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tùy chỉnh bản tin\ngiao mỗi ngày',
                  style: GoogleFonts.newsreader(
                    color: _summaryNeutral,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cá nhân hoá gói tin AI-generated bằng chủ đề, thời lượng và nhịp gửi phù hợp với bạn.',
                  style: GoogleFonts.workSans(
                    color: _summaryMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SummaryCard(
            title: 'Chủ đề',
            subtitle: 'Chọn các mảng nội dung bạn muốn nhận trong bản tóm tắt.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allTopics.map((topic) {
                final isSelected = _selectedTopics.contains(topic);
                return ChoiceChip(
                  label: Text(topic),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      if (isSelected) {
                        _selectedTopics.remove(topic);
                      } else {
                        _selectedTopics.add(topic);
                      }
                    });
                  },
                  selectedColor: _summaryPrimary.withValues(alpha: 0.14),
                  backgroundColor: _summarySurfaceStrong,
                  side: BorderSide(
                    color: isSelected
                        ? _summaryPrimary
                        : _summaryNeutral.withValues(alpha: 0.08),
                  ),
                  labelStyle: GoogleFonts.workSans(
                    color: isSelected ? _summaryPrimary : _summaryNeutral,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          _SummaryCard(
            title: 'Lịch gửi',
            subtitle:
                'Thiết lập thời điểm và tần suất Pody chuẩn bị bản tin cho bạn.',
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.schedule,
                  title: 'Giờ gửi',
                  subtitle: 'Khi nào bản tóm tắt sẵn sàng',
                  value: _deliveryTime,
                  onTap: _showTimePicker,
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  icon: Icons.calendar_today,
                  title: 'Tần suất',
                  subtitle: 'Mức độ lặp lại',
                  value: _frequency == 'Daily' ? 'Hàng ngày' : 'Hàng tuần',
                  onTap: _showFrequencyPicker,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SummaryCard(
            title: 'Thời lượng',
            subtitle: 'Chọn độ dài lý tưởng cho bản tin audio.',
            child: Row(
              children: List.generate(3, (index) {
                final labels = ['5 phút', '10 phút', '15 phút'];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                    child: _SegmentOption(
                      label: labels[index],
                      selected: _selectedDuration == index,
                      onTap: () => setState(() => _selectedDuration = index),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),
          _SummaryCard(
            title: 'Giọng điệu',
            subtitle: 'Quyết định cách hệ thống tóm tắt và kể lại bản tin.',
            child: Row(
              children: [
                Expanded(
                  child: _SegmentOption(
                    label: 'Nhanh gọn',
                    selected: _selectedTone == 0,
                    onTap: () => setState(() => _selectedTone = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SegmentOption(
                    label: 'Chi tiết',
                    selected: _selectedTone == 1,
                    onTap: () => setState(() => _selectedTone = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: _summaryPrimary,
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
            child: const Text('Lưu thiết lập'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _deliveryTime = picked.format(context);
    });
  }

  Future<void> _showFrequencyPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _summarySurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Daily'),
                onTap: () => Navigator.pop(context, 'Daily'),
              ),
              ListTile(
                title: const Text('Weekly'),
                onTap: () => Navigator.pop(context, 'Weekly'),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null) {
      return;
    }
    setState(() => _frequency = selected);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _summarySurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _summaryNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.newsreader(
              color: _summaryNeutral,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.workSans(
              color: _summaryMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _summarySurfaceStrong,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _summarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _summaryPrimary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.workSans(
                      color: _summaryNeutral,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.workSans(
                      color: _summaryMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: GoogleFonts.workSans(
                color: _summaryPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentOption extends StatelessWidget {
  const _SegmentOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _summaryPrimary : _summarySurfaceStrong,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.workSans(
            color: selected ? Colors.white : _summaryNeutral,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
