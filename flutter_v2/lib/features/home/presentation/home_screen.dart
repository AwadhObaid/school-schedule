import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: const [
        _Header(),
        SizedBox(height: 18),
        _CurrentClassCard(),
        SizedBox(height: 14),
        _NextClassCard(),
        SizedBox(height: 14),
        _TodayScheduleCard(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الأحد 20 سبتمبر',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'السلام عليكم',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'مساعدك اليومي للحصص والتنبيهات',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () {},
          tooltip: 'الإعدادات',
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _CurrentClassCard extends StatelessWidget {
  const _CurrentClassCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE6F4EB), Color(0xFFF8FCF9)],
        ),
        border: Border.all(color: const Color(0xFFD7EBDD)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 11, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'حصتي الآن',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'الحصة الثانية',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'اللغة الإنجليزية',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 3),
          Text('الصف 8 / 2', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              children: [
                Text(
                  '32:18',
                  style: TextStyle(
                    fontSize: 45,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0E5F39),
                  ),
                ),
                Text('متبقي على نهاية الحصة'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const LinearProgressIndicator(
            value: .67,
            minHeight: 10,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ],
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xFFE6F4EB),
              child: Icon(
                Icons.schedule_rounded,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'القادمة',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'الحصة الرابعة • 10:15',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'الرياضيات • الصف 7/1',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.double_arrow_rounded, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _TodayScheduleCard extends StatelessWidget {
  const _TodayScheduleCard();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('الأولى', '07:30', 'رياضيات', true),
      ('الثانية', '08:15', 'إنجليزي', true),
      ('الثالثة', '—', 'لا توجد حصة', false),
      ('الرابعة', '10:15', 'رياضيات', true),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded),
                const SizedBox(width: 8),
                Text(
                  'جدول اليوم',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(6, (index) {
                final period = index + 1;
                final active = period == 2;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: index == 5 ? 0 : 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFE6F4EB)
                          : const Color(0xFFF3F5F6),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$period',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Icon(
                          active
                              ? Icons.circle
                              : (period == 1 || period == 4
                                  ? Icons.check_rounded
                                  : Icons.remove_rounded),
                          size: active ? 14 : 18,
                          color: active || period == 1 || period == 4
                              ? AppTheme.primary
                              : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            const Divider(),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        row.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: 64, child: Text(row.$2)),
                    Expanded(child: Text(row.$3)),
                    Icon(
                      row.$4
                          ? Icons.check_circle_rounded
                          : Icons.remove_circle_outline_rounded,
                      color: row.$4 ? AppTheme.primary : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
