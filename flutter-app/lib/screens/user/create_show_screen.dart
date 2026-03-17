import 'package:flutter/material.dart';
import 'package:pody/core/network/api_exception.dart';
import 'package:pody/features/content/domain/content_models.dart';
import 'package:pody/features/content/presentation/content_scope.dart';

class CreateShowScreen extends StatefulWidget {
  const CreateShowScreen({super.key});

  @override
  State<CreateShowScreen> createState() => _CreateShowScreenState();
}

class _CreateShowScreenState extends State<CreateShowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _coverImageUrlController = TextEditingController();
  final _aiHostNameController = TextEditingController();
  final _aiHostBioController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingCategories = false;
  bool _didLoadCategories = false;
  List<String> _suggestedCategories = const [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _coverImageUrlController.dispose();
    _aiHostNameController.dispose();
    _aiHostBioController.dispose();
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
      // Fallback to manual input. The text field stays usable even if this fails.
    } finally {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
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
          aiHost: ContentCreateAiHostInput(
            displayName: _aiHostNameController.text.trim(),
            bio: _aiHostBioController.text.trim(),
          ),
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
              _buildSectionTitle('AI host'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _aiHostNameController,
                label: 'Ten AI host',
                hintText: 'Vi du: Nova, Lumi, Mira...',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Hay nhap ten AI host chinh cho show nay.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _aiHostBioController,
                label: 'Persona summary',
                hintText: 'AI host nay se noi chuyen theo phong cach nao?',
                maxLines: 4,
              ),
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
                'Show moi se duoc tao voi AI host chinh o cap show. Episode va logic AI service se duoc mo rong sau.',
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
