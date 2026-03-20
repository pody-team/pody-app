import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:pody/screens/show/content_home_screen.dart';
import 'package:pody/screens/news/news_screen.dart';
import 'package:pody/screens/creation/create_screen.dart';
import 'package:pody/screens/social/notifications_screen.dart';
import 'package:pody/screens/user/profile_screen.dart';
import 'package:pody/widgets/mini_player.dart';
import 'package:pody/theme/app_theme.dart';
import 'package:pody/core/config/app_environment.dart';
import 'package:pody/core/network/api_client.dart';
import 'package:pody/data/article_service.dart';
import 'package:pody/data/article_scope.dart';
import 'package:pody/features/ai/data/ai_remote_data_source.dart';
import 'package:pody/features/ai/data/ai_repository.dart';
import 'package:pody/features/ai/presentation/ai_scope.dart';
import 'package:pody/features/auth/application/auth_controller.dart';
import 'package:pody/features/auth/data/auth_local_data_source.dart';
import 'package:pody/features/auth/data/auth_remote_data_source.dart';
import 'package:pody/features/auth/data/auth_repository.dart';
import 'package:pody/features/auth/data/google_auth_data_source.dart';
import 'package:pody/features/auth/presentation/auth_scope.dart';
import 'package:pody/features/content/data/content_remote_data_source.dart';
import 'package:pody/features/content/data/content_repository.dart';
import 'package:pody/features/content/presentation/content_scope.dart';
import 'package:pody/features/notifications/data/notification_remote_data_source.dart';
import 'package:pody/features/notifications/data/notification_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient(baseUrl: AppEnvironment.apiBaseUrl);
  final authLocalDataSource = AuthLocalDataSource();
  final authRemoteDataSource = AuthRemoteDataSource(apiClient);
  final authRepository = AuthRepository(
    remoteDataSource: authRemoteDataSource,
    localDataSource: authLocalDataSource,
    googleAuthDataSource: GoogleSignInDataSource(
      serverClientId: AppEnvironment.googleServerClientId,
    ),
  );
  apiClient.attachAuthenticator(
    getValidAccessToken: authRepository.getValidAccessToken,
    refreshAccessToken: authRepository.refreshAccessTokenForApiClient,
    clearSession: authRepository.clearSessionForApiClient,
  );
  final authController = AuthController(authRepository)..initialize();
  final contentRepository = ContentRepository(
    ContentRemoteDataSource(apiClient),
  );
  final aiRepository = AIRepository(AIRemoteDataSource(apiClient));
  final notificationRepository = NotificationRepository(
    NotificationRemoteDataSource(apiClient),
  );
  final articleApiService = ArticleApiService(apiClient);

  runApp(
    PodyApp(
      authController: authController,
      aiRepository: aiRepository,
      contentRepository: contentRepository,
      notificationRepository: notificationRepository,
      articleApiService: articleApiService,
    ),
  );
}

class PodyApp extends StatelessWidget {
  PodyApp({
    required this.authController,
    required this.aiRepository,
    required this.contentRepository,
    required this.notificationRepository,
    required this.articleApiService,
    super.key,
  }) : navigatorKey = GlobalKey<NavigatorState>();

  final AuthController authController;
  final AIRepository aiRepository;
  final ContentRepository contentRepository;
  final NotificationRepository notificationRepository;
  final ArticleApiService articleApiService;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return ArticleScope(
      service: articleApiService,
      child: AIScope(
      repository: aiRepository,
      child: ContentScope(
        repository: contentRepository,
        child: AuthScope(
          controller: authController,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Pody',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: AppShell(
              navigatorKey: navigatorKey,
              notificationRepository: notificationRepository,
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.navigatorKey,
    required this.notificationRepository,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final NotificationRepository notificationRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSubscription;
  String? _lastHandledNoticeKey;
  String? _authNoticeMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeDeepLinks());
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDeepLinks() async {
    try {
      if (kIsWeb) {
        _handleIncomingUri(Uri.base);
        return;
      }

      final initialUri = await _appLinks.getInitialLink();
      _handleIncomingUri(initialUri);
      _deepLinkSubscription = _appLinks.uriLinkStream.listen(
        _handleIncomingUri,
      );
    } catch (_) {
      // Ignore deep-link bootstrap issues in unsupported or test environments.
    }
  }

  void _handleIncomingUri(Uri? uri) {
    _maybeShowAuthNotice(uri);
  }

  void _maybeShowAuthNotice(Uri? uri) {
    final notice = _extractAuthNotice(uri);
    if (notice == null || notice == _lastHandledNoticeKey) {
      return;
    }

    _lastHandledNoticeKey = notice;
    setState(() {
      _authNoticeMessage = notice;
    });
  }

  String? _extractAuthNotice(Uri? uri) {
    if (uri == null || uri.scheme != 'pody') {
      return null;
    }

    final matchesSignInRoute =
        uri.host == 'sign-in' ||
        uri.path == '/sign-in' ||
        uri.path == 'sign-in';
    if (!matchesSignInRoute) {
      return null;
    }

    final verified = uri.queryParameters['verified']?.trim().toLowerCase();
    if (verified == '1' || verified == 'true') {
      return 'Email đã được xác thực. Bạn có thể đăng nhập ngay bây giờ.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);

    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        if (authController.status == AuthStatus.initializing) {
          return const _SplashScreen();
        }

        return MainNavigationScreen(
          notificationRepository: widget.notificationRepository,
          authNoticeMessage: _authNoticeMessage,
          onAuthNoticeDismissed: () {
            setState(() {
              _authNoticeMessage = null;
            });
          },
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    required this.notificationRepository,
    this.authNoticeMessage,
    this.onAuthNoticeDismissed,
    super.key,
  });

  final NotificationRepository notificationRepository;
  final String? authNoticeMessage;
  final VoidCallback? onAuthNoticeDismissed;

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

  @override
  Widget build(BuildContext context) {
    final isCreateTab = _currentIndex == 2;
    final screens = [
      const ContentHomeScreen(),
      const NewsScreen(),
      const CreateScreen(),
      NotificationsScreen(repository: widget.notificationRepository),
      ProfileScreen(
        noticeMessage: widget.authNoticeMessage,
        onNoticeDismissed: widget.onAuthNoticeDismissed,
      ),
    ];

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
                    return MaterialPageRoute(builder: (_) => screens[index]);
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
        bottomNavigationBar: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isCreateTab ? Colors.white : const Color(0xFF0F1115),
            border: Border(
              top: BorderSide(
                color: isCreateTab
                    ? const Color(0xFFE5E7EB)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isCreateTab
                    ? const Color(0x140F172A)
                    : Colors.black.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
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
    final isCreateTab = _currentIndex == 2;
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
                    ? (isCreateTab
                        ? const Color(0xFFF3F4F6)
                        : Colors.white.withValues(alpha: 0.12))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? (isCreateTab
                        ? const Color(0xFF111827)
                        : Colors.white)
                    : (isCreateTab
                        ? const Color(0xFF6B7280)
                        : Colors.white54),
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
