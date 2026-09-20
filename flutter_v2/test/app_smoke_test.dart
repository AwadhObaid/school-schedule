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

  testWidgets('saving a teacher class closes editor before state refresh', (tester) async {
    await tester.pumpWidget(const SchoolScheduleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('حصصي'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'الرياضيات');
    await tester.enterText(fields.at(1), 'الصف 8 / 2');

    await tester.tap(find.text('حفظ الحصة'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('الرياضيات'), findsOneWidget);
    expect(find.textContaining('لديك 1 حصة أسبوعيًا'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
