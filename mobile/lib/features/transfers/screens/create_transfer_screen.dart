import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/formatting/thousand_separator_formatter.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/core/widgets/common_widgets.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/transfer_repository.dart';

/// Layar transfer antar dompet/rekening (Finsave Reference & Taste-Skill).
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
          content: Text('Pilih dompet asal dan tujuan'),
        ),
      );
      return;
    }

    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dompet asal dan tujuan tidak boleh sama'),
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
            content: Text('Transfer antar dompet berhasil dicatat'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencatat transfer: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Antar Dompet'),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Transfer visual card
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
                  const SizedBox(height: 16),

                  // Dari Dompet
                  Text(
                    'Dari Dompet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AccountSelector(
                    accounts: _accounts,
                    selectedId: _fromAccountId,
                    excludeId: _toAccountId,
                    onSelected: (id) => setState(() => _fromAccountId = id),
                  ),
                  const SizedBox(height: 12),

                  // Tombol tukar arah transfer
                  Center(
                    child: IconButton(
                      tooltip: 'Tukar Dompet Asal dan Tujuan',
                      onPressed: () {
                        setState(() {
                          final temp = _fromAccountId;
                          _fromAccountId = _toAccountId;
                          _toAccountId = temp;
                        });
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.surfaceRaised,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.border),
                        ),
                        child: Icon(
                          Icons.swap_vert_rounded,
                          color: tokens.brand,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Ke Dompet
                  Text(
                    'Ke Dompet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AccountSelector(
                    accounts: _accounts,
                    selectedId: _toAccountId,
                    excludeId: _fromAccountId,
                    onSelected: (id) => setState(() => _toAccountId = id),
                  ),
                  const SizedBox(height: 16),

                  // Jumlah Nominal
                  Text(
                    'Jumlah (Rp)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      hintText: 'Masukkan nominal',
                      prefixText: 'Rp ',
                      prefixIcon:
                          Icon(Icons.swap_horiz_rounded, color: tokens.brand),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandSeparatorInputFormatter(),
                    ],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Jumlah transfer wajib diisi';
                      }
                      final amount = int.tryParse(
                          v.replaceAll('.', '').replaceAll(',', ''));
                      if (amount == null || amount <= 0) {
                        return 'Jumlah transfer harus lebih dari 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tanggal
                  Text(
                    'Tanggal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(tokens.radiusControl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius:
                            BorderRadius.circular(tokens.radiusControl),
                        border: Border.all(color: tokens.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 16, color: tokens.textSecondary),
                          const SizedBox(width: 10),
                          Text(
                            formatDateFull(_selectedDate),
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: tokens.textMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Deskripsi
                  Text(
                    'Deskripsi (opsional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Top up e-wallet, Ambil tunai',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                    maxLength: 500,
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  MfButton.primary(
                    label: 'Transfer Sekarang',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _submit,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildNeedMoreAccounts() {
    return MfEmptyState(
      icon: Icons.swap_horiz_rounded,
      title: 'Butuh minimal 2 dompet',
      subtitle:
          'Buat setidaknya 2 dompet aktif untuk dapat melakukan transfer antar akun',
      actionLabel: 'Buat Dompet',
      onAction: () => context.pushNamed('create_account'),
    );
  }
}

/// Visualisasi arah transfer yang bersih dan datar tanpa gradasi neon.
class _TransferVisual extends StatelessWidget {
  final String? fromName;
  final String? toName;

  const _TransferVisual({this.fromName, this.toName});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: tokens.expense,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  fromName ?? 'Pilih Dompet',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Sumber',
                  style: TextStyle(
                    fontSize: 10,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: tokens.brand,
              size: 22,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: tokens.income,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  toName ?? 'Pilih Dompet',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Tujuan',
                  style: TextStyle(
                    fontSize: 10,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector akun/dompet dalam bentuk chip rapat.
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
    final tokens = context.tokens;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: accounts.map((account) {
        final isSelected = selectedId == account.id;
        final isExcluded = excludeId == account.id;

        return InkWell(
          onTap: isExcluded ? null : () => onSelected(account.id),
          borderRadius: BorderRadius.circular(tokens.radiusChip),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? tokens.brandWash : tokens.surface,
              borderRadius: BorderRadius.circular(tokens.radiusChip),
              border: Border.all(
                color: isSelected
                    ? tokens.brand
                    : (isExcluded ? tokens.borderHairline : tokens.border),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.name,
                  style: TextStyle(
                    color: isExcluded
                        ? tokens.textMuted
                        : (isSelected ? tokens.brand : tokens.textPrimary),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
                if (!isExcluded) ...[
                  const SizedBox(width: 6),
                  Text(
                    formatRupiah(account.balance),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? tokens.brand : tokens.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
