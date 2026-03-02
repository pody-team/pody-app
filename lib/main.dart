import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:pody/screens/home_screen.dart';
import 'package:pody/screens/news_screen.dart';
import 'package:pody/screens/create_screen.dart';
import 'package:pody/screens/notifications_screen.dart';
import 'package:pody/screens/profile_screen.dart';
import 'package:pody/widgets/mini_player.dart';
import 'package:pody/theme/app_colors.dart';

void main() {
  runApp(const PodyApp());
}

class PodyApp extends StatelessWidget {
  const PodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.white;

    // Create a dark theme matching the Stitch project theme configuration
    final ThemeData darkTheme = ThemeData.dark(useMaterial3: true).copyWith(
      primaryColor: primaryColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor.withOpacity(0.8),
        surface: kBgBlack,
        background: const Color(0xFF000000),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      // Round full for cards and dialogues
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0), // Round full styling
        ),
      ),
    );

    return MaterialApp(
      title: 'Remix of Immersive Podcast Player',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const NewsScreen(),
    const CreateScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          _screens[_currentIndex],
          if (_currentIndex != 1 && _currentIndex != 2)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 72, // Để 72 là khoảng an toàn vừa khít không bị lẹm viền
              child: MiniPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2), // Ép nhỏ chiều cao của bar
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                    _buildNavItem(
                      1,
                      Icons.newspaper_outlined,
                      Icons.newspaper,
                      'News',
                    ),
                    _buildNavItem(
                      2,
                      Icons.add_circle_outline,
                      Icons.add_circle,
                      'Create',
                      isCreate: true,
                    ),
                    _buildNavItem(
                      3,
                      Icons.mail_outline,
                      Icons.mail,
                      'Notify',
                    ),
                    _buildNavItem(
                      4,
                      Icons.person_outline,
                      Icons.person,
                      'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    bool isCreate = false,
  }) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: SizedBox(
        width: 60, // Tăng nhẹ width để icon và padding không bị bóp méo
        height: 44, // Giữ nguyên chiều cao
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? (isCreate ? 14 : 16) : 0,
              vertical: isActive ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? Colors.white : Colors.white54,
              size: isCreate ? 32 : 28, // Phóng to icon lên nhưng giữ nguyên height container
            ),
          ),
        ),
      ),
    );
  }
}
