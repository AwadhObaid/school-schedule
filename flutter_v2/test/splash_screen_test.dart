import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/app_info.dart';
import 'package:schedule/features/splash/presentation/splash_screen.dart';

void main() {
  testWidgets('splash screen shows app identity and developer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    expect(find.text(AppInfo.appName), findsOneWidget);
    expect(
      find.text('إعداد وتطوير: ${AppInfo.developerName}'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
