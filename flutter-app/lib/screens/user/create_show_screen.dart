import 'package:flutter/material.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_scope.dart';

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
      final categories = await ContentScope.of(context).listCreateShowCategories();
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
      _hosts.add(
        _HostDraftForm(displayName: '', bio: '', role: 'co_host'),
      );
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
        const SnackBar(content: Text('Can it nhat 1 host hop le.')),
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
    return 'Khong the tao show luc nay. Thu lai sau it phut nua.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E13),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tao show moi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _buildSectionTitle('Thong tin show'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _titleController,
                label: 'Ten show',
                hintText: 'Vi du: Future Builders',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Hay nhap ten show.';
                  }
                  if (value.trim().length < 3) {
                    return 'Ten show nen dai it nhat 3 ky tu.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _descriptionController,
                label: 'Mo ta ngan',
                hintText: 'Show nay se ke dieu gi va phuc vu ai?',
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _coverImageUrlController,
                label: 'Anh bia (tuy chon)',
                hintText: 'https://...',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Dinh dang'),
              const SizedBox(height: 12),
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
              const SizedBox(height: 24),
              _buildSectionTitle('Phan loai'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _categoryController,
                label: 'Category chinh',
                hintText: 'Vi du: Cong nghe',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Hay chon hoac nhap category chinh.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              if (_isLoadingCategories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Dang tai goi y category...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              if (_suggestedCategories.isNotEmpty)
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
                      selectedColor: const Color(0xFFE7C6A0),
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF1A171E)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFFE7C6A0)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildSectionTitle(
                    _contentType == 'storytelling' ? 'Narrator' : 'Hosts',
                  ),
                  const Spacer(),
                  if (_contentType == 'podcast')
                    TextButton.icon(
                      onPressed: _hosts.length >= 3 || _isSubmitting ? null : _addHost,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Them host'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(_hosts.length, (index) {
                final host = _hosts[index];
                final isStorytelling = _contentType == 'storytelling';
                final roleLabel = isStorytelling
                    ? 'Narrator'
                    : (index == 0 ? 'Host chinh' : 'Co-host');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              roleLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (_contentType == 'podcast' && _hosts.length > 1)
                              IconButton(
                                onPressed: _isSubmitting ? null : () => _removeHost(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white54,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: host.displayNameController,
                          label: 'Ten host',
                          hintText: index == 0 ? 'Vi du: Nova' : 'Vi du: Atlas',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Hay nhap ten host.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: host.bioController,
                          label: 'Persona summary',
                          hintText: 'Host nay noi chuyen theo phong cach nao?',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE7C6A0),
                  foregroundColor: const Color(0xFF1A171E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Tao show',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                _contentType == 'storytelling'
                    ? 'Storytelling duoc tao voi 1 narrator o cap show. Episode se ke thua narrator nay.'
                    : 'Podcast duoc tao voi 1 den 3 host o cap show. Episode se ke thua danh sach host nay.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE7C6A0)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFFE7C6A0)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF1A171E) : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE7C6A0)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF8A80)),
        ),
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
