import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Three-page "how it works" guide shown the first time the app is opened,
/// so a new farmer understands the app without needing someone to explain it.
/// It can be opened again from the login screen and the farmer home screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.openedFromApp = false});

  /// true when opened from a "How it works" link: finishing just goes back.
  final bool openedFromApp;

  static const String seenKey = 'onboarding_seen';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.message,
    this.image,
    this.icon,
  });

  final String title;
  final String message;
  final String? image;
  final IconData? icon;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      image: 'assets/crop_disease.png',
      title: "Is your crop sick?",
      message:
          "Take a photo of one leaf with your phone. The app checks it for disease in seconds.",
    ),
    _OnboardingPage(
      image: 'assets/disease_leaf.png',
      title: "Know what to do",
      message:
          "See the disease name, how serious it is, the signs to look for and how to treat it. Ask the AI for more advice.",
    ),
    _OnboardingPage(
      icon: Icons.storefront,
      title: "Stay informed",
      message:
          "Read market prices, seasonal tips and alerts from agriculture experts. Every leaf you check is saved in your history.",
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingScreen.seenKey, true);
    } catch (_) {
      // If saving fails the guide simply shows again next time.
    }
    if (!mounted) return;

    if (widget.openedFromApp) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _next() {
    if (_isLastPage) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(_isLastPage ? "" : "Skip"),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 6,
                          child: Center(
                            child: page.image != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: Image.asset(
                                      page.image!,
                                      fit: BoxFit.cover,
                                      width: width,
                                      // Decode at screen size to save memory.
                                      cacheWidth: (width * 2).round(),
                                    ),
                                  )
                                : Container(
                                    width: width * 0.6,
                                    height: width * 0.6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      page.icon,
                                      size: width * 0.28,
                                      color: AppColors.primary,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Step number
                        Text(
                          "STEP ${index + 1} OF ${_pages.length}",
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          flex: 2,
                          child: Text(
                            page.message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppColors.textMuted,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                final active = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 26 : 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : const Color(0xFFCFD8CC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _next,
                  icon: Icon(_isLastPage ? Icons.check : Icons.arrow_forward),
                  label: Text(_isLastPage ? "Get started" : "Next"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
