import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/design_system.dart';
import '../core/user_service.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _userService = UserService();
  int _currentPage = 0;
  bool _isLoading = false;

  late AnimationController _iconAnimController;
  late AnimationController _glowAnimController;
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _glowPulse;

  final List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.psychology_rounded,
      title: 'Remember Everything',
      subtitle:
          'Rewise uses science-backed spaced repetition to help you retain what you learn — forever.',
      accentColor: const Color(0xFF6366F1), // Indigo
      gradientColors: [const Color(0xFF312E81), const Color(0xFF0F0F1A)],
    ),
    _OnboardingPageData(
      icon: Icons.insights_rounded,
      title: 'Track Your Memory',
      subtitle:
          'See real-time memory scores, streaks, and progress.\nKnow exactly what\'s fading and what\'s strong.',
      accentColor: const Color(0xFF10B981), // Emerald
      gradientColors: [const Color(0xFF064E3B), const Color(0xFF0F0F1A)],
    ),
    _OnboardingPageData(
      icon: Icons.auto_awesome_rounded,
      title: 'Study Smarter',
      subtitle:
          'AI schedules your reviews at the perfect moment.\nNo more cramming — just effortless learning.',
      accentColor: const Color(0xFFFACC15), // Amber
      gradientColors: [const Color(0xFF78350F), const Color(0xFF0F0F1A)],
    ),
    _OnboardingPageData(
      icon: Icons.waving_hand_rounded,
      title: "Let's Get Started",
      subtitle: 'Tell us your name and we\'ll set up your study space.',
      accentColor: const Color(0xFFF472B6), // Pink
      gradientColors: [const Color(0xFF831843), const Color(0xFF0F0F1A)],
      isNamePage: true,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _iconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconAnimController, curve: Curves.elasticOut),
    );
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconAnimController, curve: Curves.easeIn),
    );

    _glowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowAnimController, curve: Curves.easeInOut),
    );

    // Play initial animation
    _iconAnimController.forward();

    // Pre-fill name from OAuth if available
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final name = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '';
      if (name.isNotEmpty) {
        _nameController.text = _userService.sanitizeName(name);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _iconAnimController.dispose();
    _glowAnimController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _iconAnimController.reset();
    _iconAnimController.forward();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name to continue.'),
          backgroundColor: AppColors.fading,
        ),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Your session has expired. Please sign in again.'),
              backgroundColor: AppColors.urgent),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _userService.createUserProfile(name);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Unable to save your profile. Please check your connection.'),
              backgroundColor: AppColors.urgent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageData = _pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: pageData.gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, top: 8),
                  child: _currentPage < _pages.length - 1
                      ? TextButton(
                          onPressed: () {
                            _pageController.animateToPage(
                              _pages.length - 1,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : const SizedBox(height: 40),
                ),
              ),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _buildPage(page, index);
                  },
                ),
              ),

              // Bottom section: dots + button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (index) {
                        final isActive = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: isActive ? 32 : 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isActive
                                ? pageData.accentColor
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: pageData.accentColor,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: pageData.isNamePage ? _saveProfile : _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: pageData.accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    pageData.isNamePage ? 'Get Started' : 'Next',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: pageData.accentColor == const Color(0xFFFACC15)
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    pageData.isNamePage ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                                    size: 20,
                                    color: pageData.accentColor == const Color(0xFFFACC15)
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData page, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: page.isNamePage ? 40 : 80), // Less top spacing for name page

                // Animated icon with glow
                AnimatedBuilder(
                  animation: Listenable.merge([_iconAnimController, _glowAnimController]),
                  builder: (context, child) {
                    final useLogo = page.isNamePage || page.title.contains('Rewise');
                    return Transform.scale(
                      scale: _iconScale.value,
                      child: Opacity(
                        opacity: _iconFade.value.clamp(0.0, 1.0),
                        child: Container(
                          width: page.isNamePage ? 100 : 140,
                          height: page.isNamePage ? 100 : 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: page.accentColor.withValues(alpha: 0.12),
                            boxShadow: [
                              BoxShadow(
                                color: page.accentColor
                                    .withValues(alpha: 0.3 * _glowPulse.value),
                                blurRadius: 60 * _glowPulse.value,
                                spreadRadius: 10 * _glowPulse.value,
                              ),
                            ],
                          ),
                          child: useLogo
                              ? Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Image.asset('assets/icon.png'),
                                )
                              : Icon(
                                  page.icon,
                                  size: page.isNamePage ? 48 : 64,
                                  color: page.accentColor,
                                ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: page.isNamePage ? 32 : 48),

                // Title
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                if (page.isNamePage) ...[
                  const SizedBox(height: 48), // Direct space to input

                  // Name input
                  TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'What should we call you?',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: page.accentColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 18),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                    maxLength: 50,
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            required maxLength}) =>
                        null,
                  ),
                ],
                const SizedBox(height: 100), // Space for button section overlap
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureChip(String emoji, String label, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Color> gradientColors;
  final bool isNamePage;

  _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.gradientColors,
    this.isNamePage = false,
  });
}
