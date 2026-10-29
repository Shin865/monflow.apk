import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/core/theme/theme_provider.dart';
import 'package:money_flow/core/routing/app_router.dart';
import 'package:money_flow/core/widgets/splash_screen.dart';
import 'package:money_flow/data/services/security_service.dart';
import 'package:money_flow/features/security/screens/pin_lock_screen.dart';

class MoneyFlowApp extends ConsumerStatefulWidget {
  const MoneyFlowApp({super.key});

  @override
  ConsumerState<MoneyFlowApp> createState() => _MoneyFlowAppState();
}

class _MoneyFlowAppState extends ConsumerState<MoneyFlowApp>
    with WidgetsBindingObserver {
  bool _showSplash = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _splashTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      try {
        final sec = ref.read(securityServiceProvider);
        sec.isLockOnBackgroundEnabled().then((enabled) {
          if (!mounted) return;
          if (enabled) {
            sec.isPinEnabled().then((pinEnabled) {
              if (mounted && pinEnabled) {
                sec.lockApp();
              }
            }).catchError((_) {});
          }
        }).catchError((_) {});
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeMigrationProvider);
    final router = ref.watch(appRouterProvider);
    final sec = ref.watch(securityServiceProvider);

    return MaterialApp.router(
      title: 'Money Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      locale: const Locale('id', 'ID'),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,

            // PIN lock overlay — tampil di atas konten saat app terkunci
            if (!_showSplash && sec.isAppLocked)
              const Positioned.fill(
                child: PinLockScreen(),
              ),

            // Splash screen — tampil saat startup, transisi fade-out halus
            if (_showSplash)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _showSplash ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: const SplashScreen(),
                ),
              ),
          ],
        );
      },
    );
  }
}
