import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleSettingsPage();
  }
}

class _SimpleSettingsPage extends StatelessWidget {
  const _SimpleSettingsPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_rounded, size: 62),
            SizedBox(height: 16),
            Text(
              'الإعدادات',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text(
              'سيتم نقل إعدادات الجرس، اختيار النغمة، مستوى الصوت، التنبيهات، والنسخ الاحتياطي تدريجيًا من النسخة الحالية.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
