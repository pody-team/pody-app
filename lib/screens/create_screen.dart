import 'package:flutter/material.dart';
import 'package:pody/theme/app_colors.dart';

import 'package:flutter/cupertino.dart';
import 'package:pody/screens/edit_plan_screen.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final List<String> _attachedFiles = [];

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBgCard,
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.white),
                title: const Text(
                  'Upload Image',
                  style: TextStyle(color: Colors.white),
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
                leading: const Icon(Icons.description, color: Colors.white),
                title: const Text(
                  'Upload Document',
                  style: TextStyle(color: Colors.white),
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
                leading: const Icon(Icons.audiotrack, color: Colors.white),
                title: const Text(
                  'Upload Audio',
                  style: TextStyle(color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBlack, // ChatGPT dark mode background
      appBar: AppBar(
        backgroundColor: kBgBlack,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Production Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.square_pencil,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 768),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  reverse: true,
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16,
                  ),
                  children: [
                    // User chat message
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2F2F2F,
                          ), // ChatGPT User bubble color
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Make it more professional and focus on the early investment years for the first episode.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // AI message (text part)
                    const Text(
                      'Sure, I\'ve refined the tone to be more analytical and adjusted the episode breakdown to emphasize the formative years. Here is the updated production plan:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI message (card part)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: kBgCard, // Slightly lighter dark
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'The Oracle Portfolio',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '3 Episodes • 45 min total',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_note,
                                    color: Colors.white70,
                                    size: 24,
                                  ),
                                  onPressed: _showEditPlanDialog,
                                  tooltip: 'Edit Plan',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Tags
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _buildTag('Analytical'),
                                const SizedBox(width: 8),
                                _buildTag('Professional'),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.group,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Sarah & Marcus',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Episodes
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildEpisodeRow('1', 'The Foundation years'),
                                const SizedBox(height: 8),
                                _buildEpisodeRow('2', 'Growth & Acquisition'),
                                const SizedBox(height: 12),
                                Text(
                                  '+ 1 more episode',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Process Button
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 16,
                            ),
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.play_arrow, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Start Production',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ].reversed.toList(),
                ),
              ),

              // Bottom floating input component (ChatGPT style)
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? 16
                      : 100,
                  top: 16,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: kBgCard,
                    borderRadius: BorderRadius.circular(24),
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
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
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
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      file,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
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
                                        color: Colors.white54,
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
                          color: Colors.white.withOpacity(0.05),
                          margin: const EdgeInsets.only(bottom: 8),
                        ),
                      ],
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: _showAttachmentOptions,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const Expanded(
                            child: TextField(
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Message Assistant...',
                                hintStyle: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_upward,
                                color: Colors.black,
                                size: 18,
                              ),
                              onPressed: () {},
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
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
            color: Colors.white,
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
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditPlanDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditPlanScreen()),
    );
  }
}
