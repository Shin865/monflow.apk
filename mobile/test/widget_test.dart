import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/app.dart';

void main() {
  testWidgets('MoneyFlowApp initializes and renders successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MoneyFlowApp(),
      ),
    );

    // Verify root widget renders
    expect(find.byType(MoneyFlowApp), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
