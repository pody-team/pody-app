import 'package:flutter/material.dart';
import 'package:pody/theme/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _displayNameController = TextEditingController(text: 'Minh Nguyen');
  final _usernameController = TextEditingController(text: 'minhdev');
  final _bioController = TextEditingController(
    text:
        'Tech enthusiast, coffee lover, and weekend podcaster. Exploring the future of audio.',
  );
  final _durationController = TextEditingController(text: '15 min');
  final _toneController = TextEditingController(text: 'Professional');
  final _audienceController = TextEditingController(text: 'Investors');

  final List<String> _allInterests = [
    'True Crime',
    'Tech',
    'Comedy',
    'History',
    'Business',
    'Science',
  ];
  final Set<String> _selectedInterests = {'True Crime', 'Tech', 'Business'};

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _durationController.dispose();
    _toneController.dispose();
    _audienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E13),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white54,
                ),
              ),
            ),
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Profile saved'),
                    backgroundColor: kBgCard,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 60),
        children: [
          // Avatar Section
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: Image.network(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuAWGX1z6hXmkcfBIlhDnk0zE9cv8lX5A5B_hsXdZwH57h3bdtokrT2CGW01UyaWneHx-8azq8ciqAjJQe3nJ7y5tREangqFs1BmRkWxfA98Mt0qCf5PuiB9U1DGLRFd9qOwV25TMb1uyyjoWi6gXf10TJRWnKursAmQTO0bgJ8Vqu9aPD_3OlBzSyKZSuntBKn6nEek-FUektilhtlyXBb3aUAj9Y3Zt1y_xgR7IvsTaWFf4UILkhoKo_6OpaEJJYqFpgedWemeUfoo',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Camera overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: const Icon(
                          Icons.photo_camera,
                          color: Colors.white70,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Change Photo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Display Name
          _buildFieldLabel('DISPLAY NAME'),
          const SizedBox(height: 6),
          _buildTextField(_displayNameController),
          const SizedBox(height: 24),

          // Username
          _buildFieldLabel('USERNAME'),
          const SizedBox(height: 6),
          _buildTextField(_usernameController, prefix: '@'),
          const SizedBox(height: 24),

          // Bio
          _buildFieldLabel('BIO'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: kBgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: TextField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 150,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.4,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: const TextStyle(
                  fontSize: 11,
                  color: Colors.white24,
                ),
                counterText: '${_bioController.text.length}/150',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 28),

          // Podcast Interests
          _buildFieldLabel('PODCAST INTERESTS'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allInterests.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedInterests.remove(interest);
                    } else {
                      _selectedInterests.add(interest);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.12)
                        : kBgCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    interest,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text(
              'Select topics to personalize your feed.',
              style: TextStyle(fontSize: 12, color: Colors.white24),
            ),
          ),
          const SizedBox(height: 32),

          // Divider
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 24),

          // Default Podcast Preferences
          _buildFieldLabel('DEFAULT PODCAST PREFERENCES'),
          const SizedBox(height: 20),

          // Duration
          _buildSmallLabel('DEFAULT DURATION'),
          const SizedBox(height: 6),
          _buildTextField(_durationController, suffixIcon: Icons.schedule),
          const SizedBox(height: 20),

          // Tone
          _buildSmallLabel('DEFAULT TONE'),
          const SizedBox(height: 6),
          _buildTextField(_toneController, suffixIcon: Icons.graphic_eq),
          const SizedBox(height: 20),

          // Target Audience
          _buildSmallLabel('TARGET AUDIENCE'),
          const SizedBox(height: 6),
          _buildTextField(_audienceController, suffixIcon: Icons.group),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Text(
              'These settings will be used as defaults for new episodes.',
              style: TextStyle(fontSize: 12, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white38,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSmallLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white24,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    String? prefix,
    IconData? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixText: prefix,
          prefixStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white38,
          ),
          suffixIcon: suffixIcon != null
              ? Icon(suffixIcon, color: Colors.white24, size: 20)
              : null,
        ),
      ),
    );
  }
}
