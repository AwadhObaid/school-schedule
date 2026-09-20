import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_controller.dart';
import 'core/models/app_appearance.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/presentation/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SchoolScheduleApp());
}

class SchoolScheduleApp extends StatefulWidget {
  const SchoolScheduleApp({
    this.controller,
    super.key,
  });

  final AppController? controller;

  @override
  State<SchoolScheduleApp> createState() => _SchoolScheduleAppState();
}

class _SchoolScheduleAppState extends State<SchoolScheduleApp> {
  late final AppController _controller;
  late final bool _ownsController;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AppController();
    _ownsController = widget.controller == null;
    _initialization = _controller.initialize();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
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
          darkTheme: AppTheme.dark(),
          themeMode: switch (_controller.appearance) {
            AppAppearance.system => ThemeMode.system,
            AppAppearance.light => ThemeMode.light,
            AppAppearance.dark => ThemeMode.dark,
          },
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
      },
    );
  }
}
