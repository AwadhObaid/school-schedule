import 'package:flutter/material.dart';

import '../../../core/app_info.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final titleColor = isDark ? AppTheme.darkText : AppTheme.lightText;
    final subtitleColor =
        isDark ? AppTheme.darkSecondaryText : AppTheme.lightSecondaryText;
    final primary = isDark ? AppTheme.darkPrimary : AppTheme.primary;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    key: const Key('splash-brand-content'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SplashLogo(
                        surface: surface,
                        shadowColor: primary.withValues(alpha: 0.18),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        AppInfo.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 31,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'مساعدك اليومي للجدول والحصص',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 16,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'جارٍ التحميل...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Text(
                'إعداد وتطوير: ${AppInfo.developerName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo({
    required this.surface,
    required this.shadowColor,
  });

  final Color surface;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      height: 138,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/app_icon.png',
          key: const Key('splash-app-icon'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
