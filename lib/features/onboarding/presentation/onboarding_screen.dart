import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../providers/dependency_injection.dart';
import '../../../routes/app_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  List<_OnboardingPageData> _pages(BuildContext context) {
    final l10n = context.l10n;
    return [
      _OnboardingPageData(
        icon: Icons.eco,
        title: l10n.onboardingWelcomeTitle,
        description: l10n.onboardingWelcomeDesc,
        isWelcome: true,
      ),
      _OnboardingPageData(
        icon: Icons.report_outlined,
        title: l10n.onboardingReportTitle,
        description: l10n.onboardingReportDesc,
      ),
      _OnboardingPageData(
        icon: Icons.track_changes,
        title: l10n.onboardingTrackTitle,
        description: l10n.onboardingTrackDesc,
      ),
      _OnboardingPageData(
        icon: Icons.map_outlined,
        title: l10n.onboardingMapTitle,
        description: l10n.onboardingMapDesc,
      ),
      _OnboardingPageData(
        icon: Icons.phone_android,
        title: l10n.onboardingUssdTitle,
        description: l10n.onboardingUssdDesc(AppConstants.ussdShortCode),
      ),
    ];
  }

  void _completeIntro() {
    ref.read(introSessionCompleteProvider).value = true;
    context.go(AppRoutes.home);
  }

  void _onPrimaryAction(int pageCount) {
    if (_currentPage < pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeIntro();
    }
  }

  String _primaryButtonLabel(BuildContext context) {
    final l10n = context.l10n;
    final pages = _pages(context);
    if (_currentPage == 0 || _currentPage == pages.length - 1) {
      return l10n.getStarted;
    }
    return l10n.next;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = _pages(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Text(l10n.back),
                      )
                    else
                      const SizedBox(width: 80),
                    const Spacer(),
                    TextButton(
                      onPressed: _completeIntro,
                      child: Text(l10n.skip),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _OnboardingPage(page: pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _onPrimaryAction(pages.length),
                  child: Text(_primaryButtonLabel(context)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    this.isWelcome = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isWelcome;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});

  final _OnboardingPageData page;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bodyColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (page.isWelcome)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(page.icon, size: 72, color: primary),
            )
          else
            Icon(page.icon, size: 100, color: primary),
          const SizedBox(height: 32),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: page.isWelcome ? primary : null,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: bodyColor,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
