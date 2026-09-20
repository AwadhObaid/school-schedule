import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Flutter V2 opens with Arabic teacher home shell', (tester) async {
    await tester.pumpWidget(const SchoolScheduleApp());
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('حصصي'), findsOneWidget);
    expect(find.text('الجدول'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('ابدأ بإضافة حصصك'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
