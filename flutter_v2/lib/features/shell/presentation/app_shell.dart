import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../home/presentation/home_screen.dart';
import '../../my_classes/presentation/my_classes_screen.dart';
import '../../schedule/presentation/schedule_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.controller,
    super.key,
  });

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        controller: widget.controller,
        onOpenMyClasses: () => _select(1),
        onOpenSettings: () => _select(3),
      ),
      MyClassesScreen(controller: widget.controller),
      ScheduleScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'حصصي',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'الجدول',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
