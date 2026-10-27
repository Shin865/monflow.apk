import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/providers/balance_visibility_provider.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/core/widgets/common_widgets.dart';
import 'package:money_flow/data/repositories/account_repository.dart';

/// Layar daftar akun/dompet dengan pengelompokan jenis akun.
///
/// Desain Achromatic Ledger:
/// - Saldo total dalam MfCard tenang bebas gradien slop.
/// - Angka tabular sejajar kanan untuk memudahkan verifikasi nominal.
/// - Pengelompokan jenis akun yang rapi.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final accountsStream =
        ref.watch(accountRepositoryProvider).watchActiveAccounts();
    final isBalanceHidden = ref.watch(balanceVisibilityProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dompet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Dompet',
            onPressed: () => context.pushNamed('create_account'),
          ),
        ],
      ),
      body: StreamBuilder<List<Account>>(
        stream: accountsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MfLoading(message: 'Memuat data dompet...');
          }

          final accounts = snapshot.data ?? [];

          if (accounts.isEmpty) {
            return MfEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Belum ada dompet',
              subtitle:
                  'Mulai dengan membuat dompet pertamamu untuk mencatat keuangan',
              actionLabel: 'Buat Dompet',
              onAction: () => context.pushNamed('create_account'),
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
            padding: EdgeInsets.symmetric(horizontal: tokens.pad, vertical: 12),
            children: [
              // Total balance header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  border: Border.all(color: tokens.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL SALDO DOMPET',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            isBalanceHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: tokens.textSecondary,
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
                    const SizedBox(height: 6),
                    Text(
                      BalanceVisibilityNotifier.formatOrMask(
                        totalBalance,
                        isHidden: isBalanceHidden,
                      ),
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${accounts.length} dompet aktif',
                      style: TextStyle(color: tokens.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
        backgroundColor: tokens.primaryButtonBg,
        foregroundColor: tokens.primaryButtonInk,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusControl),
        ),
        onPressed: () => context.pushNamed('create_account'),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Dompet Baru',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
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
        return Icons.payments_outlined;
      case AccountType.bank:
        return Icons.account_balance_outlined;
      case AccountType.ewallet:
        return Icons.phone_android_outlined;
      case AccountType.savings:
        return Icons.savings_outlined;
      case AccountType.other:
        return Icons.wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final subtotal = accounts.fold<int>(0, (sum, a) => sum + a.balance);
    final isBalanceHidden = ref.watch(balanceVisibilityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            children: [
              Icon(_getTypeIcon(type), size: 16, color: tokens.textMuted),
              const SizedBox(width: 8),
              Text(
                _getTypeLabel(type),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                BalanceVisibilityNotifier.formatOrMask(
                  subtotal,
                  isHidden: isBalanceHidden,
                ),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        ...accounts.map((a) => _AccountCard(account: a)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final Account account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final isBalanceHidden = ref.watch(balanceVisibilityProvider);

    return Dismissible(
      key: Key('account_${account.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showConfirmDialog(
          context,
          title: 'Hapus Dompet',
          message: 'Apakah kamu yakin ingin menghapus "${account.name}"?',
          confirmLabel: 'Hapus',
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
          color: tokens.expenseBg,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
        ),
        child: Icon(Icons.delete_outline_rounded, color: tokens.expense),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(tokens.radiusControl),
                border: Border.all(color: tokens.border),
              ),
              child: account.icon != null
                  ? Text(account.icon!, style: const TextStyle(fontSize: 18))
                  : Icon(Icons.account_balance_wallet_outlined,
                      color: tokens.textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  if (account.description != null &&
                      account.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        account.description!,
                        style: TextStyle(fontSize: 11, color: tokens.textMuted),
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
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
