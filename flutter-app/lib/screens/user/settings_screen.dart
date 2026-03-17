import 'package:flutter/material.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/screens/user/change_password_screen.dart';
import 'package:pody/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;

  Future<void> _handleSignOut() async {
    final authController = AuthScope.of(context);
    await authController.signOut();
    if (!mounted) {
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E13),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white54),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 160),
        children: [
          // Account
          _buildSectionHeader('Account'),
          _buildSettingsItem(
            icon: Icons.lock_outline,
            title: 'Change Password',
            trailing: _chevron(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              );
            },
          ),

          _buildDivider(),

          // Notifications
          _buildSectionHeader('Notifications'),
          _buildSettingsItem(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            trailing: Switch(
              value: _pushNotifications,
              onChanged: (val) => setState(() => _pushNotifications = val),
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.white38,
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
            ),
          ),
          _buildSettingsItem(
            icon: Icons.mail_outline,
            title: 'Email Notifications',
            trailing: _chevron(),
          ),

          _buildDivider(),

          // Privacy & Security
          _buildSectionHeader('Privacy & Security'),
          _buildSettingsItem(
            icon: Icons.security,
            title: 'Privacy Center',
            trailing: _chevron(),
          ),
          _buildSettingsItem(
            icon: Icons.visibility_off_outlined,
            title: 'Block List',
            trailing: _chevron(),
          ),

          _buildDivider(),

          // Storage & Data
          _buildSectionHeader('Storage & Data'),
          _buildSettingsItem(
            icon: Icons.storage,
            title: 'Clear Cache',
            subtitle: 'Used: 1.2 GB',
            trailing: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: kBgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Clear Cache?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: const Text(
                      'This will free up 1.2 GB of storage.',
                      style: TextStyle(color: Colors.white54),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white24,
                size: 22,
              ),
            ),
          ),
          _buildSettingsItem(
            icon: Icons.network_check,
            title: 'Download Quality',
            trailingText: 'High',
            trailing: _chevron(),
          ),

          _buildDivider(),

          // Help & Support
          _buildSectionHeader('Help & Support'),
          _buildSettingsItem(
            icon: Icons.help_outline,
            title: 'Help Center',
            trailing: const Icon(
              Icons.open_in_new,
              color: Colors.white24,
              size: 18,
            ),
          ),
          _buildSettingsItem(
            icon: Icons.info_outline,
            title: 'About',
            trailingText: 'v2.4.1',
            trailing: _chevron(),
          ),

          // Log Out
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: kBgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Log Out?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: const Text(
                      'Are you sure you want to log out?',
                      style: TextStyle(color: Colors.white54),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _handleSignOut();
                        },
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: kBgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white24,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white24,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingText != null) ...[
                  Text(
                    trailingText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chevron() {
    return const Icon(Icons.chevron_right, color: Colors.white24, size: 20);
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
    );
  }
}
