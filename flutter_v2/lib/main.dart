import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/presentation/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SchoolScheduleApp());
}

class SchoolScheduleApp extends StatelessWidget {
  const SchoolScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'التوقيت المدرسي',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: AppShell(),
      ),
    );
  }
}
