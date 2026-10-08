import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/models/teacher_class.dart';
import 'package:schedule/core/storage/teacher_schedule_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('teacher schedule persists locally', () async {
    final store = TeacherScheduleStore();

    await store.save(
      const <TeacherClass>[
        TeacherClass(
          weekday: DateTime.sunday,
          periodId: 'p2',
          subject: 'اللغة الإنجليزية',
          classroom: 'الصف 8 / 2',
        ),
      ],
    );

    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded.single.weekday, DateTime.sunday);
    expect(loaded.single.periodId, 'p2');
    expect(loaded.single.subject, 'اللغة الإنجليزية');
    expect(loaded.single.classroom, 'الصف 8 / 2');
  });
}
