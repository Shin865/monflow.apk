import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/app.dart';
import 'package:money_flow/core/database/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final database = AppDatabase();

  // Seed default data if needed
  await database.seedDefaultCategories();
  await database.seedDefaultSettings();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: const MoneyFlowApp(),
    ),
  );
}
