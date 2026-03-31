import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_scope.dart';

const Color _createCanvas = Color(0xFFFFFBF6);
const Color _createSurface = Color(0xFFFFFEFC);
const Color _createSurfaceStrong = Color(0xFFF2E6D9);
const Color _createPrimary = Color(0xFFBF5700);
const Color _createSecondary = Color(0xFFE1AD01);
const Color _createNeutral = Color(0xFF3E2723);
const Color _createMuted = Color(0xFF7E665F);

class CreateShowScreen extends StatefulWidget {
  const CreateShowScreen({this.initialSeed, super.key});

  final ContentCreateShowSeed? initialSeed;

  @override
  State<CreateShowScreen> createState() => _CreateShowScreenState();
}

class _CreateShowScreenState extends State<CreateShowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _coverImageUrlController = TextEditingController();
  final List<_HostDraftForm> _hosts = [];

  bool _isSubmitting = false;
  bool _isLoadingCategories = false;
  bool _didLoadCategories = false;
  String _contentType = 'podcast';
  List<String> _suggestedCategories = const [];

  @override
  void initState() {
    super.initState();
    final initialSeed = widget.initialSeed;
    if (initialSeed != null) {
      _titleController.text = initialSeed.title;
      _descriptionController.text = initialSeed.description ?? '';
      _categoryController.text = initialSeed.primaryCategory;
      _coverImageUrlController.text = initialSeed.coverImageUrl ?? '';
      _contentType = initialSeed.contentType;
      for (final host in initialSeed.hosts) {
        _hosts.add(
          _HostDraftForm(
            displayName: host.displayName,
            bio: host.bio ?? '',
            role: host.role ?? 'host',
            voiceProfileId: host.voiceProfileId,
          ),
        );
      }
    }

    if (_hosts.isEmpty) {
      _hosts.add(_HostDraftForm(displayName: '', bio: '', role: 'host'));
    }
    _normalizeHostsForContentType();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _coverImageUrlController.dispose();
    for (final host in _hosts) {
      host.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadCategories) {
      return;
    }
    _didLoadCategories = true;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await ContentScope.of(
        context,
      ).listCreateShowCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _suggestedCategories = categories;
        if (_categoryController.text.trim().isEmpty && categories.isNotEmpty) {
          _categoryController.text = categories.first;
        }
      });
    } catch (_) {
      // Manual input remains available.
    } finally {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  void _normalizeHostsForContentType() {
    if (_contentType == 'storytelling') {
      while (_hosts.length > 1) {
        _hosts.removeLast().dispose();
      }
      if (_hosts.isEmpty) {
        _hosts.add(_HostDraftForm(displayName: '', bio: '', role: 'narrator'));
      }
      _hosts.first.role = 'narrator';
      return;
    }

    for (var index = 0; index < _hosts.length; index++) {
      _hosts[index].role = index == 0 ? 'host' : 'co_host';
    }
  }

  void _setContentType(String contentType) {
    setState(() {
      _contentType = contentType;
      _normalizeHostsForContentType();
    });
  }

  void _addHost() {
    if (_contentType != 'podcast' || _hosts.length >= 3) {
      return;
    }
    setState(() {
      _hosts.add(_HostDraftForm(displayName: '', bio: '', role: 'co_host'));
      _normalizeHostsForContentType();
    });
  }

  void _removeHost(int index) {
    if (_hosts.length <= 1 || index < 0 || index >= _hosts.length) {
      return;
    }
    setState(() {
      _hosts.removeAt(index).dispose();
      _normalizeHostsForContentType();
    });
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final hosts = _buildHostsInput();
    if (hosts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần ít nhất 1 host hợp lệ.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final show = await ContentScope.of(context).createShow(
        ContentCreateShowInput(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          primaryCategory: _categoryController.text.trim(),
          coverImageUrl: _coverImageUrlController.text.trim(),
          contentType: _contentType,
          hosts: hosts,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(show);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  List<ContentCreateHostInput> _buildHostsInput() {
    final result = <ContentCreateHostInput>[];
    for (final host in _hosts) {
      final name = host.displayNameController.text.trim();
      if (name.isEmpty) {
        continue;
      }
      result.add(
        ContentCreateHostInput(
          displayName: name,
          role: host.role,
          voiceProfileId: host.voiceProfileId,
          bio: host.bioController.text.trim(),
        ),
      );
    }
    return result;
  }

  String _humanizeError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tạo show lúc này. Thử lại sau ít phút nữa.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _createCanvas,
      appBar: AppBar(
        backgroundColor: _createCanvas,
        surfaceTintColor: _createCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _createNeutral),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tạo show mới',
          style: GoogleFonts.newsreader(
            color: _createNeutral,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF4E6), Color(0xFFF3E5D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _createPrimary.withValues(alpha: 0.10),
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
                        color: _createSurface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Creator studio',
                        style: GoogleFonts.workSans(
                          color: _createPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Định nghĩa show\nngay từ đầu',
                      style: GoogleFonts.newsreader(
                        color: _createNeutral,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Điền thông tin cốt lõi để tạo một show dùng dữ liệu thật trên content service.',
                      style: GoogleFonts.workSans(
                        color: _createMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Thông tin show',
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: 'Tên show',
                    hintText: 'Ví dụ: Future Builders',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Hãy nhập tên show.';
                      }
                      if (value.trim().length < 3) {
                        return 'Tên show nên dài ít nhất 3 ký tự.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Mô tả ngắn',
                    hintText: 'Show này sẽ kể điều gì và phục vụ ai?',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _coverImageUrlController,
                    label: 'Ảnh bìa',
                    hintText: 'https://... (tuỳ chọn)',
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Định dạng',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeChip(
                          label: 'Podcast',
                          value: 'podcast',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTypeChip(
                          label: 'Storytelling',
                          value: 'storytelling',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Phân loại',
                children: [
                  _buildTextField(
                    controller: _categoryController,
                    label: 'Category chính',
                    hintText: 'Ví dụ: Công nghệ',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Hãy chọn hoặc nhập category chính.';
                      }
                      return null;
                    },
                  ),
                  if (_isLoadingCategories)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Đang tải gợi ý category...',
                        style: GoogleFonts.workSans(
                          color: _createMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_suggestedCategories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedCategories.map((category) {
                        final selected =
                            _categoryController.text.trim().toLowerCase() ==
                            category.trim().toLowerCase();
                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _categoryController.text = category;
                            });
                          },
                          selectedColor: _createSecondary.withValues(
                            alpha: 0.18,
                          ),
                          backgroundColor: _createSurfaceStrong,
                          labelStyle: GoogleFonts.workSans(
                            color: selected ? _createPrimary : _createNeutral,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: selected
                                ? _createSecondary
                                : _createNeutral.withValues(alpha: 0.08),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              _SectionCard(
                title: _contentType == 'storytelling' ? 'Narrator' : 'Hosts',
                trailing: _contentType == 'podcast'
                    ? TextButton.icon(
                        onPressed: _hosts.length >= 3 || _isSubmitting
                            ? null
                            : _addHost,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Thêm host'),
                      )
                    : null,
                children: [
                  ...List.generate(_hosts.length, (index) {
                    final host = _hosts[index];
                    final isStorytelling = _contentType == 'storytelling';
                    final roleLabel = isStorytelling
                        ? 'Narrator'
                        : (index == 0 ? 'Host chính' : 'Co-host');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _createSurfaceStrong,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  roleLabel,
                                  style: GoogleFonts.workSans(
                                    color: _createNeutral,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (_contentType == 'podcast' &&
                                    _hosts.length > 1)
                                  IconButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _removeHost(index),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: _createMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: host.displayNameController,
                              label: 'Tên host',
                              hintText: index == 0
                                  ? 'Ví dụ: Nova'
                                  : 'Ví dụ: Atlas',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Hãy nhập tên host.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: host.bioController,
                              label: 'Persona summary',
                              hintText:
                                  'Host này nói chuyện theo phong cách nào?',
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _createPrimary,
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
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Tạo show'),
              ),
              const SizedBox(height: 12),
              Text(
                _contentType == 'storytelling'
                    ? 'Storytelling được tạo với 1 narrator ở cấp show. Episode sẽ kế thừa narrator này.'
                    : 'Podcast được tạo với 1 đến 3 host ở cấp show. Episode sẽ kế thừa danh sách host này.',
                textAlign: TextAlign.center,
                style: GoogleFonts.workSans(
                  color: _createMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip({required String label, required String value}) {
    final selected = _contentType == value;
    return InkWell(
      onTap: _isSubmitting ? null : () => _setContentType(value),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _createPrimary : _createSurfaceStrong,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.workSans(
              color: selected ? Colors.white : _createNeutral,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.workSans(color: _createNeutral),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: GoogleFonts.workSans(color: _createMuted),
        hintStyle: GoogleFonts.workSans(
          color: _createMuted.withValues(alpha: 0.72),
        ),
        filled: true,
        fillColor: _createSurfaceStrong,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _createNeutral.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _createNeutral.withValues(alpha: 0.08)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          borderSide: BorderSide(color: _createPrimary, width: 1.4),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          borderSide: BorderSide(color: Color(0xFFC16452)),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _createSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _createNeutral.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.newsreader(
                  color: _createNeutral,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              switch (trailing) {
                final widget? => widget,
                null => const SizedBox.shrink(),
              },
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _HostDraftForm {
  _HostDraftForm({
    required String displayName,
    required String bio,
    required this.role,
    this.voiceProfileId,
  }) : displayNameController = TextEditingController(text: displayName),
       bioController = TextEditingController(text: bio);

  final TextEditingController displayNameController;
  final TextEditingController bioController;
  final String? voiceProfileId;
  String role;

  void dispose() {
    displayNameController.dispose();
    bioController.dispose();
  }
}
