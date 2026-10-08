import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_controller.dart';
import 'core/models/app_appearance.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/update/presentation/update_dialog.dart';

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

class _SchoolScheduleAppState extends State<SchoolScheduleApp>
    with WidgetsBindingObserver {
  late final AppController _controller;
  late final bool _ownsController;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AppController();
    _ownsController = widget.controller == null;
    WidgetsBinding.instance.addObserver(this);

    if (_ownsController) {
      _initialization = Future.wait<void>([
        _controller.initialize(),
        Future<void>.delayed(const Duration(milliseconds: 1400)),
      ]).then((_) {});
    } else {
      _initialization = _controller.initialize();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.handleAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
                  return const SplashScreen();
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

                return _StartupShell(
                  controller: _controller,
                  checkUpdatesAutomatically: _ownsController,
                );
              },
            ),
          ),
        );
      },
    );
  }
}


class _StartupShell extends StatefulWidget {
  const _StartupShell({
    required this.controller,
    required this.checkUpdatesAutomatically,
  });

  final AppController controller;
  final bool checkUpdatesAutomatically;

  @override
  State<_StartupShell> createState() => _StartupShellState();
}

class _StartupShellState extends State<_StartupShell> {
  bool _startedUpdateCheck = false;

  @override
  void initState() {
    super.initState();

    if (widget.checkUpdatesAutomatically) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runAutomaticUpdateCheck();
      });
    }
  }

  Future<void> _runAutomaticUpdateCheck() async {
    if (_startedUpdateCheck) return;
    _startedUpdateCheck = true;

    final result = await widget.controller.checkForUpdates(
      silent: true,
      respectIgnored: true,
    );

    if (!mounted || !result.hasUpdate) return;

    await showAppUpdateDialog(
      context,
      controller: widget.controller,
      update: result.update!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(controller: widget.controller);
  }
}
