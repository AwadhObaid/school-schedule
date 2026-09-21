import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/theme/app_theme.dart';
import 'package:schedule/features/splash/presentation/splash_screen.dart';

void main() {
  test('light identity uses the approved green palette', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary, AppTheme.primary);
    expect(theme.colorScheme.primaryContainer, AppTheme.primaryContainer);
    expect(theme.scaffoldBackgroundColor, AppTheme.lightBackground);
    expect(theme.colorScheme.surface, AppTheme.lightSurface);
    expect(theme.colorScheme.onSurface, AppTheme.lightText);
    expect(theme.colorScheme.secondary, AppTheme.accentGold);
  });

  test('dark identity stays green instead of returning to navy', () {
    final theme = AppTheme.dark();

    expect(theme.colorScheme.primary, AppTheme.darkPrimary);
    expect(theme.colorScheme.primaryContainer, AppTheme.darkPrimaryContainer);
    expect(theme.scaffoldBackgroundColor, AppTheme.darkBackground);
    expect(theme.colorScheme.surface, AppTheme.darkSurface);
    expect(theme.colorScheme.onSurface, AppTheme.darkText);
  });

  testWidgets('splash brand content is centered horizontally and vertically',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const SplashScreen(),
      ),
    );

    final brand = find.byKey(const Key('splash-brand-content'));
    expect(brand, findsOneWidget);

    final brandCenter = tester.getCenter(brand);
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);

    expect((brandCenter.dx - screenCenter.dx).abs(), lessThan(1.0));
    expect((brandCenter.dy - screenCenter.dy).abs(), lessThan(2.0));
    expect(find.byKey(const Key('splash-app-icon')), findsOneWidget);
    expect(find.text('جارٍ التحميل...'), findsOneWidget);
  });
}
