import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/presentation/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SchoolScheduleApp());
}

class SchoolScheduleApp extends StatefulWidget {
  const SchoolScheduleApp({super.key});

  @override
  State<SchoolScheduleApp> createState() => _SchoolScheduleAppState();
}

class _SchoolScheduleAppState extends State<SchoolScheduleApp> {
  late final AppController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _initialization = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<void>(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'تعذر تحميل بيانات التطبيق المحلية.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            return AppShell(controller: _controller);
          },
        ),
      ),
    );
  }
}
