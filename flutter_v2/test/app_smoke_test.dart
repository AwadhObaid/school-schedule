import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/main.dart';

void main() {
  testWidgets('Flutter V2 opens with Arabic teacher home shell', (tester) async {
    await tester.pumpWidget(const SchoolScheduleApp());
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('حصصي'), findsOneWidget);
    expect(find.text('الجدول'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('حصتي الآن'), findsOneWidget);
  });
}
