import 'package:flutter/material.dart';

import '../../../core/data/school_schedule_defaults.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_format.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const periods = SchoolScheduleDefaults.normalTeachingPeriods;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        Text(
          'أوقات الحصص',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'هذه الأوقات هي المرجع الذي تعتمد عليه ميزة «حصصي» لحساب الحصة الحالية والقادمة.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var index = 0; index < periods.length; index += 1) ...[
                  _PeriodRow(
                    number: index + 1,
                    name: periods[index].name,
                    start: ArabicFormat.minutesClock(
                      periods[index].startMinutes,
                    ),
                    end: ArabicFormat.minutesClock(
                      periods[index].endMinutes,
                    ),
                  ),
                  if (index != periods.length - 1) const Divider(height: 22),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6EE),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.link_rounded, color: AppTheme.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'أي حصة تضيفها في «حصصي» ترتبط برقم الحصة هنا، لذلك لا نكرر وقت البداية والنهاية داخل جدول المدرس.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.number,
    required this.name,
    required this.start,
    required this.end,
  });

  final int number;
  final String name;
  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: const Color(0xFFE6F4EB),
          child: Text(
            '$number',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$start ← $end',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '35 دقيقة',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}
