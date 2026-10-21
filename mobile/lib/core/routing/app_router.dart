import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/features/accounts/screens/accounts_screen.dart';
import 'package:money_flow/features/accounts/screens/create_account_screen.dart';
import 'package:money_flow/features/categories/screens/categories_screen.dart';
import 'package:money_flow/features/dashboard/screens/dashboard_screen.dart';
import 'package:money_flow/features/transactions/screens/transactions_screen.dart';
import 'package:money_flow/features/transactions/screens/create_transaction_screen.dart';
import 'package:money_flow/features/transfers/screens/create_transfer_screen.dart';
import 'package:money_flow/features/settings/screens/settings_screen.dart';
import 'package:money_flow/features/bills/screens/bills_screen.dart';
import 'package:money_flow/features/bills/screens/bill_detail_screen.dart';
import 'package:money_flow/features/debts/screens/debts_screen.dart';
import 'package:money_flow/features/debts/screens/debt_detail_screen.dart';
import 'package:money_flow/features/investments/screens/investments_deposits_screen.dart';
import 'package:money_flow/features/planning/screens/planning_screen.dart';
import 'package:money_flow/core/routing/shell_screen.dart';

import 'package:money_flow/features/reports/screens/reports_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/transactions',
            name: 'transactions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TransactionsScreen(),
            ),
          ),
          GoRoute(
            path: '/accounts',
            name: 'accounts',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AccountsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/accounts/create',
        name: 'create_account',
        builder: (context, state) => const CreateAccountScreen(),
      ),
      GoRoute(
        path: '/transactions/create',
        name: 'create_transaction',
        builder: (context, state) => const CreateTransactionScreen(),
      ),
      GoRoute(
        path: '/transfers/create',
        name: 'create_transfer',
        builder: (context, state) => const CreateTransferScreen(),
      ),
      GoRoute(
        path: '/categories',
        name: 'categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/bills',
        name: 'bills',
        builder: (context, state) => const BillsScreen(),
      ),
      GoRoute(
        path: '/bills/detail',
        name: 'bill_detail',
        builder: (context, state) {
          final billId = state.extra as int;
          return BillDetailScreen(billId: billId);
        },
      ),
      GoRoute(
        path: '/debts',
        name: 'debts',
        builder: (context, state) => const DebtsScreen(),
      ),
      GoRoute(
        path: '/debts/detail',
        name: 'debt_detail',
        builder: (context, state) {
          final debtId = state.extra as int;
          return DebtDetailScreen(debtId: debtId);
        },
      ),
      GoRoute(
        path: '/investments',
        name: 'investments',
        builder: (context, state) => const InvestmentsDepositsScreen(),
      ),
      GoRoute(
        path: '/planning',
        name: 'planning',
        builder: (context, state) => const PlanningScreen(),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),
    ],
  );
});
