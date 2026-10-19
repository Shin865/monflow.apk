import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/transfer_repository.dart';

/// Layar transfer antar akun/dompet.
class CreateTransferScreen extends ConsumerStatefulWidget {
  const CreateTransferScreen({super.key});

  @override
  ConsumerState<CreateTransferScreen> createState() =>
      _CreateTransferScreenState();
}

class _CreateTransferScreenState extends ConsumerState<CreateTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  int? _fromAccountId;
  int? _toAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts =
        await ref.read(accountRepositoryProvider).getActiveAccounts();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        if (accounts.length >= 2) {
          _fromAccountId = accounts[0].id;
          _toAccountId = accounts[1].id;
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih akun asal dan tujuan'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun asal dan tujuan tidak boleh sama'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amountText =
          _amountController.text.replaceAll('.', '').replaceAll(',', '');
      final amount = int.tryParse(amountText);

      if (amount == null || amount <= 0) {
        throw ArgumentError('Jumlah harus lebih dari 0');
      }

      await ref.read(transferRepositoryProvider).create(
            fromAccountId: _fromAccountId!,
            toAccountId: _toAccountId!,
            amount: amount,
            date: _selectedDate,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer berhasil! ✅'),
            backgroundColor: AppColors.transfer,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _accounts.length < 2
          ? _buildNeedMoreAccounts()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Transfer illustration
                  _TransferVisual(
                    fromName: _accounts
                        .where((a) => a.id == _fromAccountId)
                        .map((a) => a.name)
                        .firstOrNull,
                    toName: _accounts
                        .where((a) => a.id == _toAccountId)
                        .map((a) => a.name)
                        .firstOrNull,
                  ),
                  const SizedBox(height: 24),

                  // Dari Akun
                  const Text('Dari Dompet',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  _AccountSelector(
                    accounts: _accounts,
                    selectedId: _fromAccountId,
                    excludeId: _toAccountId,
                    onSelected: (id) => setState(() => _fromAccountId = id),
                  ),
                  const SizedBox(height: 20),

                  // Tombol swap
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          final temp = _fromAccountId;
                          _fromAccountId = _toAccountId;
                          _toAccountId = temp;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.transfer.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.transfer.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.swap_vert_rounded,
                            color: AppColors.transfer, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Ke Akun
                  const Text('Ke Dompet',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  _AccountSelector(
                    accounts: _accounts,
                    selectedId: _toAccountId,
                    excludeId: _fromAccountId,
                    onSelected: (id) => setState(() => _toAccountId = id),
                  ),
                  const SizedBox(height: 24),

                  // Jumlah
                  const Text('Jumlah (Rp)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      hintText: '0',
                      prefixText: 'Rp ',
                      prefixIcon: Icon(Icons.swap_horiz_rounded,
                          color: AppColors.transfer),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Jumlah wajib diisi';
                      final amount = int.tryParse(v.replaceAll('.', ''));
                      if (amount == null || amount <= 0) {
                        return 'Jumlah harus lebih dari 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Tanggal
                  const Text('Tanggal',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 12),
                          Text(
                            formatDateFull(_selectedDate),
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Deskripsi
                  const Text('Deskripsi (opsional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Top up GoPay, Tarik tunai',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                    maxLength: 500,
                  ),
                  const SizedBox(height: 32),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.transfer,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Transfer Sekarang'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildNeedMoreAccounts() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz_rounded,
                size: 80, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 20),
            const Text(
              'Butuh minimal 2 dompet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Buat setidaknya 2 dompet untuk melakukan transfer',
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.pushNamed('create_account'),
              icon: const Icon(Icons.add),
              label: const Text('Buat Dompet'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual indicator showing transfer direction.
class _TransferVisual extends StatelessWidget {
  final String? fromName;
  final String? toName;

  const _TransferVisual({this.fromName, this.toName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.transfer.withOpacity(0.15),
            AppColors.transfer.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.transfer.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.expense, size: 28),
                const SizedBox(height: 6),
                Text(
                  fromName ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward_rounded,
                color: AppColors.transfer, size: 28),
          ),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.income, size: 28),
                const SizedBox(height: 6),
                Text(
                  toName ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Account selector chips.
class _AccountSelector extends StatelessWidget {
  final List<Account> accounts;
  final int? selectedId;
  final int? excludeId;
  final ValueChanged<int> onSelected;

  const _AccountSelector({
    required this.accounts,
    this.selectedId,
    this.excludeId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: accounts.map((account) {
        final isSelected = selectedId == account.id;
        final isExcluded = excludeId == account.id;

        return GestureDetector(
          onTap: isExcluded ? null : () => onSelected(account.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isExcluded
                  ? AppColors.surfaceLight.withOpacity(0.3)
                  : isSelected
                      ? AppColors.transfer.withOpacity(0.2)
                      : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.transfer : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.name,
                  style: TextStyle(
                    color: isExcluded
                        ? AppColors.textMuted.withOpacity(0.4)
                        : isSelected
                            ? AppColors.transfer
                            : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
                if (!isExcluded) ...[
                  const SizedBox(width: 6),
                  Text(
                    formatRupiah(account.balance),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? AppColors.transfer.withOpacity(0.7)
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
