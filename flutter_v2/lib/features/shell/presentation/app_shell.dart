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
      final allowed = await _requestSettingsPin();
      if (!allowed || !mounted) return;
    }

    setState(() => _index = index);
  }

  Future<bool> _requestSettingsPin() async {
    final pinController = TextEditingController();

    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final valid = widget.controller.verifySettingsPin(
                pinController.text.trim(),
              );

              if (valid) {
                Navigator.pop(dialogContext, true);
                return;
              }

              setDialogState(() {
                errorText = 'رمز الدخول غير صحيح';
              });
            }

            return AlertDialog(
              title: const Text('دخول الإعدادات'),
              content: TextField(
                controller: pinController,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  labelText: 'رمز الدخول',
                  hintText: 'الافتراضي: 0000',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('دخول'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    return allowed == true;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        controller: widget.controller,
        onOpenMyClasses: () => _select(1),
        onOpenSettings: () { _select(3); },
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
        onDestinationSelected: (index) { _select(index); },
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
