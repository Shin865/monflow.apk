import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/core/providers/balance_visibility_provider.dart';

/// Layar daftar akun/dompet.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsStream =
        ref.watch(accountRepositoryProvider).watchActiveAccounts();
    final isBalanceHidden = ref.watch(balanceVisibilityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.pushNamed('create_account'),
          ),
        ],
      ),
      body: StreamBuilder<List<Account>>(
        stream: accountsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final accounts = snapshot.data ?? [];

          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 80, color: AppColors.textMuted.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  const Text(
                    'Belum ada dompet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mulai dengan membuat dompet pertamamu',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.pushNamed('create_account'),
                    icon: const Icon(Icons.add),
                    label: const Text('Buat Dompet'),
                  ),
                ],
              ),
            );
          }

          // Group accounts by type
          final grouped = <AccountType, List<Account>>{};
          int totalBalance = 0;
          for (final a in accounts) {
            grouped.putIfAbsent(a.type, () => []).add(a);
            totalBalance += a.balance;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Total balance header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Saldo',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            isBalanceHidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          tooltip: isBalanceHidden
                              ? 'Tampilkan Saldo'
                              : 'Sembunyikan Saldo',
                          onPressed: () => ref
                              .read(balanceVisibilityProvider.notifier)
                              .toggle(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      BalanceVisibilityNotifier.formatOrMask(
                        totalBalance,
                        isHidden: isBalanceHidden,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${accounts.length} dompet aktif',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account groups
              ...grouped.entries.map((entry) => _AccountGroup(
                    type: entry.key,
                    accounts: entry.value,
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('create_account'),
        icon: const Icon(Icons.add),
        label: const Text('Dompet Baru'),
      ),
    );
  }
}

class _AccountGroup extends ConsumerWidget {
  final AccountType type;
  final List<Account> accounts;

  const _AccountGroup({required this.type, required this.accounts});

  String _getTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return 'Uang Tunai';
      case AccountType.bank:
        return 'Rekening Bank';
      case AccountType.ewallet:
        return 'E-Wallet';
      case AccountType.savings:
        return 'Tabungan';
      case AccountType.other:
        return 'Lainnya';
    }
  }

  IconData _getTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_rounded;
      case AccountType.bank:
        return Icons.account_balance_rounded;
      case AccountType.ewallet:
        return Icons.phone_android_rounded;
      case AccountType.savings:
        return Icons.savings_rounded;
      case AccountType.other:
        return Icons.wallet_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtotal = accounts.fold<int>(0, (sum, a) => sum + a.balance);
    final isBalanceHidden = ref.watch(balanceVisibilityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(_getTypeIcon(type), size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(
                _getTypeLabel(type),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                BalanceVisibilityNotifier.formatOrMask(
                  subtotal,
                  isHidden: isBalanceHidden,
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        ...accounts.map((a) => _AccountCard(account: a)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final Account account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = account.color != null
        ? Color(int.parse(account.color!.replaceFirst('#', '0xFF')))
        : AppColors.primary;
    final isBalanceHidden = ref.watch(balanceVisibilityProvider);

    return Dismissible(
      key: Key('account_${account.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Dompet'),
            content:
                Text('Apakah kamu yakin ingin menghapus "${account.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final message =
            await ref.read(accountRepositoryProvider).delete(account.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: account.icon != null
                  ? Text(account.icon!, style: const TextStyle(fontSize: 24))
                  : Icon(Icons.account_balance_wallet, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (account.description != null &&
                      account.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        account.description!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              BalanceVisibilityNotifier.formatOrMask(
                account.balance,
                isHidden: isBalanceHidden,
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color:
                    account.balance >= 0 ? AppColors.income : AppColors.expense,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
