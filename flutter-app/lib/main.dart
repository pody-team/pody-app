import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:pody/screens/show/home_screen.dart';
import 'package:pody/screens/news/news_screen.dart';
import 'package:pody/screens/creation/create_screen.dart';
import 'package:pody/screens/social/notifications_screen.dart';
import 'package:pody/screens/user/profile_screen.dart';
import 'package:pody/widgets/mini_player.dart';
import 'package:pody/theme/app_theme.dart';
import 'package:pody/screens/auth/sign_in_screen.dart';
import 'package:pody/data/mock_data.dart';

void main() {
  runApp(const PodyApp());
}

class PodyApp extends StatelessWidget {
  const PodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pody',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SignInScreen(),
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

  // A navigator key per tab so each tab has its own navigation stack
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (_) => GlobalKey<NavigatorState>(),
  );

  final List<Widget> _screens = const [
    HomeScreen(),
    NewsScreen(),
    CreateScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        // Let the current tab's navigator handle back first
        final navigatorState = _navigatorKeys[_currentIndex].currentState;
        if (navigatorState != null && navigatorState.canPop()) {
          navigatorState.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: Stack(
          children: [
            // IndexedStack keeps all tab states alive
            IndexedStack(
              index: _currentIndex,
              children: List.generate(5, (index) {
                return Navigator(
                  key: _navigatorKeys[index],
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute(builder: (_) => _screens[index]);
                  },
                );
              }),
            ),
            if (_currentIndex != 2)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 72,
                child: MiniPlayer(),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
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
                        badgeCount: MockData.notifications
                            .where((n) => n.isUnread)
                            .length,
                      ),
                      _buildNavItem(
                        4,
                        Icons.account_circle_outlined,
                        Icons.account_circle,
                        'Profile',
                      ),
                    ],
                  ),
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
    int badgeCount = 0,
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
        width: 60,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
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
                size: isCreate ? 32 : 28,
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: 2,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFE2C55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
