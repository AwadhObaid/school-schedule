import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/models/school_period.dart';
import '../../../core/services/teacher_schedule_engine.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_format.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.controller,
    required this.onOpenMyClasses,
    required this.onOpenSettings,
    super.key,
  });

  final AppController controller;
  final VoidCallback onOpenMyClasses;
  final VoidCallback onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _ticker;
  String? _lastBellStateKey;
  DateTime? _lastBellTick;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    final now = DateTime.now();
    _lastBellStateKey = widget.controller.schoolBellStateKeyAt(now);
    _lastBellTick = now;
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      final now = DateTime.now();
      _lastBellStateKey = widget.controller.schoolBellStateKeyAt(now);
      _lastBellTick = now;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    final now = DateTime.now();
    _lastBellStateKey = widget.controller.schoolBellStateKeyAt(now);
    _lastBellTick = now;
    if (mounted) setState(() {});
  }

  void _onTick(Timer timer) {
    final now = DateTime.now();
    final stateKey = widget.controller.schoolBellStateKeyAt(now);
    final lastTick = _lastBellTick;
    final previousKey = _lastBellStateKey;

    final continuousTick = lastTick != null &&
        now.difference(lastTick).inMilliseconds.abs() <= 3500;

    if (continuousTick &&
        previousKey != null &&
        previousKey != stateKey) {
      unawaited(widget.controller.playAutomaticSchoolBell());
    }

    _lastBellStateKey = stateKey;
    _lastBellTick = now;

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeline = widget.controller.timelineAt(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
      children: [
        _Header(
          date: ArabicFormat.date(now),
          onOpenSettings: widget.onOpenSettings,
        ),
        const SizedBox(height: 18),
        if (widget.controller.activeClassCount == 0)
          _EmptyTeacherSchedule(onOpenMyClasses: widget.onOpenMyClasses)
        else if (timeline.current != null)
          _CurrentClassCard(
            current: timeline.current!,
            now: now,
          )
        else
          _FreeStateCard(
            next: timeline.next,
            now: now,
            onOpenMyClasses: widget.onOpenMyClasses,
          ),
        if (timeline.current != null && timeline.next != null) ...[
          const SizedBox(height: 14),
          _NextClassCard(next: timeline.next!, now: now),
        ],
        const SizedBox(height: 14),
        _TodayScheduleCard(
          timeline: timeline,
          currentPeriodId: timeline.current?.period.id,
          periods: widget.controller.teachingPeriodsForDate(now),
          onOpenMyClasses: widget.onOpenMyClasses,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.onOpenSettings,
  });

  final String date;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: Theme.of(context).textTheme.bodyMedium),
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
          onPressed: onOpenSettings,
          tooltip: 'الإعدادات',
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _EmptyTeacherSchedule extends StatelessWidget {
  const _EmptyTeacherSchedule({required this.onOpenMyClasses});

  final VoidCallback onOpenMyClasses;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.school_rounded,
                size: 34,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ابدأ بإضافة حصصك',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'حدد حصصك الأسبوعية مرة واحدة، وسيتابع التطبيق الحصة الحالية والقادمة تلقائيًا.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onOpenMyClasses,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إدارة حصصي'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentClassCard extends StatelessWidget {
  const _CurrentClassCard({
    required this.current,
    required this.now,
  });

  final ScheduledTeacherClass current;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final remaining = current.end.difference(now);
    final totalSeconds = current.end.difference(current.start).inSeconds;
    final elapsedSeconds = now.difference(current.start).inSeconds;
    final progress = totalSeconds <= 0
        ? 0.0
        : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0).toDouble();

    final classroom = current.assignment.classroom?.trim();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surfaceContainerLow,
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
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
            current.period.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            current.assignment.subject,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (classroom != null && classroom.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              classroom,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Text(
                  ArabicFormat.countdown(remaining),
                  style: TextStyle(
                    fontSize: 45,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Text('متبقي على نهاية الحصة'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          const SizedBox(height: 10),
          Text(
            '${ArabicFormat.clock(current.start)} – ${ArabicFormat.clock(current.end)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _FreeStateCard extends StatelessWidget {
  const _FreeStateCard({
    required this.next,
    required this.now,
    required this.onOpenMyClasses,
  });

  final ScheduledTeacherClass? next;
  final DateTime now;
  final VoidCallback onOpenMyClasses;

  @override
  Widget build(BuildContext context) {
    final item = next;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(Icons.coffee_rounded, color: AppTheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد لديك حصة الآن',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (item != null) ...[
              const SizedBox(height: 12),
              Text(
                'القادمة: ${item.period.name}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.assignment.subject,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if ((item.assignment.classroom ?? '').trim().isNotEmpty)
                Text(
                  item.assignment.classroom!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 8),
              Text(
                '${ArabicFormat.dayName(item.start.weekday)} • ${ArabicFormat.clock(item.start)} • ${ArabicFormat.relative(item.start.difference(now))}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'لا توجد حصص قادمة ضمن جدولك الأسبوعي.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onOpenMyClasses,
                icon: const Icon(Icons.edit_calendar_rounded),
                label: const Text('تعديل حصصي'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({
    required this.next,
    required this.now,
  });

  final ScheduledTeacherClass next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final classroom = next.assignment.classroom?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.schedule_rounded, color: AppTheme.primary),
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
                    '${next.period.name} • ${ArabicFormat.clock(next.start)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      next.assignment.subject,
                      if (classroom != null && classroom.isNotEmpty) classroom,
                    ].join(' • '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ArabicFormat.relative(next.start.difference(now)),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _TodayScheduleCard extends StatelessWidget {
  const _TodayScheduleCard({
    required this.timeline,
    required this.currentPeriodId,
    required this.periods,
    required this.onOpenMyClasses,
  });

  final TeacherTimeline timeline;
  final String? currentPeriodId;
  final List<SchoolPeriod> periods;
  final VoidCallback onOpenMyClasses;

  @override
  Widget build(BuildContext context) {
    final byPeriod = {
      for (final item in timeline.today) item.period.id: item,
    };
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
                Expanded(
                  child: Text(
                    'جدول اليوم',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: onOpenMyClasses,
                  child: const Text('تعديل'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: periods.map((period) {
                final assignment = byPeriod[period.id];
                final active = currentPeriodId == period.id;

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      left: period == periods.last ? 0 : 6,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      children: [
                        Text(
                          period.id.substring(1),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Icon(
                          active
                              ? Icons.circle
                              : assignment != null
                                  ? Icons.check_rounded
                                  : Icons.remove_rounded,
                          size: active ? 14 : 18,
                          color: active || assignment != null
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 14),
            const Divider(),
            ...periods.map((period) {
              final item = byPeriod[period.id];
              final isCurrent = currentPeriodId == period.id;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 82,
                      child: Text(
                        period.name.replaceFirst('الحصة ', ''),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? AppTheme.primary : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      child: Text(ArabicFormat.minutesClock(period.startMinutes)),
                    ),
                    Expanded(
                      child: Text(item?.assignment.subject ?? 'لا توجد حصة'),
                    ),
                    Icon(
                      item != null
                          ? Icons.check_circle_rounded
                          : Icons.remove_circle_outline_rounded,
                      color: item != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
