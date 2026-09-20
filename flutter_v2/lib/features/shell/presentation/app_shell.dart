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

  Future<void> _select(int index) async {
    if (_index == index) return;

    if (index == 3) {
      final allowed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _SettingsPinDialog(
          controller: widget.controller,
        ),
      );

      if (!mounted || allowed != true) return;
    }

    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        controller: widget.controller,
        onOpenMyClasses: () {
          _select(1);
        },
        onOpenSettings: () {
          _select(3);
        },
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
        onDestinationSelected: (index) {
          _select(index);
        },
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

class _SettingsPinDialog extends StatefulWidget {
  const _SettingsPinDialog({
    required this.controller,
  });

  final AppController controller;

  @override
  State<_SettingsPinDialog> createState() => _SettingsPinDialogState();
}

class _SettingsPinDialogState extends State<_SettingsPinDialog> {
  final _pinController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('دخول الإعدادات'),
      content: TextField(
        controller: _pinController,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 12,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'رمز الدخول',
          hintText: 'الافتراضي أول مرة: 0000',
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('دخول'),
        ),
      ],
    );
  }

  void _submit() {
    final valid = widget.controller.verifySettingsPin(
      _pinController.text.trim(),
    );

    if (valid) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _errorText = 'رمز الدخول غير صحيح';
    });
  }
}
