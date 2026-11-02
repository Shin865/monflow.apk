import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/app.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/services/security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable edge-to-edge system mode so content seamlessly integrates with bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Set system UI overlay style matching the single light theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Initialize database
  final database = AppDatabase();

  // Seed default data if needed
  await database.seedDefaultCategories();
  await database.seedDefaultSettings();

  // Initialize security state BEFORE runApp — this ensures PIN lock is active
  // immediately if the user has PIN enabled, preventing the bypass bug where
  // _isAppLocked defaulted to false.
  final securityService = SecurityService(database);
  await securityService.initSecurityState();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        securityServiceProvider.overrideWith((ref) => securityService),
      ],
      child: const MoneyFlowApp(),
    ),
  );
}
