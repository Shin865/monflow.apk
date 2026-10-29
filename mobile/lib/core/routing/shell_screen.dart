import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/theme/app_theme.dart';

/// Shell screen with bottom navigation bar (Finsave 4-tab style).
class ShellScreen extends StatelessWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/accounts')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.goNamed('dashboard');
        break;
      case 1:
        context.goNamed('transactions');
        break;
      case 2:
        context.goNamed('accounts');
        break;
      case 3:
        context.goNamed('settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final tokens = context.tokens;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border(
            top: BorderSide(color: tokens.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => _onItemTapped(context, index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined, size: 22),
              activeIcon: Icon(Icons.grid_view_rounded, size: 22),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined, size: 22),
              activeIcon: Icon(Icons.receipt_long_rounded, size: 22),
              label: 'Transaksi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined, size: 22),
              activeIcon: Icon(Icons.account_balance_wallet_rounded, size: 22),
              label: 'Dompet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined, size: 22),
              activeIcon: Icon(Icons.tune_rounded, size: 22),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}
