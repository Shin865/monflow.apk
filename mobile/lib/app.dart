import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/core/routing/app_router.dart';
import 'package:money_flow/data/services/security_service.dart';
import 'package:money_flow/features/security/screens/pin_lock_screen.dart';

class MoneyFlowApp extends ConsumerStatefulWidget {
  const MoneyFlowApp({super.key});

  @override
  ConsumerState<MoneyFlowApp> createState() => _MoneyFlowAppState();
}

class _MoneyFlowAppState extends ConsumerState<MoneyFlowApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
    final router = ref.watch(appRouterProvider);
    final sec = ref.watch(securityServiceProvider);

    return MaterialApp.router(
      title: 'Money Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
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
            if (sec.isAppLocked)
              const Positioned.fill(
                child: PinLockScreen(),
              ),
          ],
        );
      },
    );
  }
}
