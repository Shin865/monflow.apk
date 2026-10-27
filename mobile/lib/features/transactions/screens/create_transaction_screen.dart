import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/formatting/thousand_separator_formatter.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';

/// Layar catat atau ubah transaksi (pemasukan/pengeluaran/refund).
///
/// Desain Achromatic Ledger:
/// - Urutan input logis: Tipe -> Jumlah -> Dompet -> Kategori -> Tanggal -> Deskripsi -> Catatan.
/// - Input nominal Rupiah kosong saat awal (bukan hardcoded "0").
/// - Pengetikan nominal dengan pemisah ribuan otomatis dan angka tabular.
/// - Validasi tepat di bawah field.
class CreateTransactionScreen extends ConsumerStatefulWidget {
  final int? editTransactionId;

  const CreateTransactionScreen({super.key, this.editTransactionId});

  @override
  ConsumerState<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState
    extends ConsumerState<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  int? _selectedAccountId;
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<Account> _accounts = [];
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final accounts =
        await ref.read(accountRepositoryProvider).getActiveAccounts();
    final categories =
        await ref.read(categoryRepositoryProvider).getActiveCategories();

    Transaction? editTxn;
    if (widget.editTransactionId != null) {
      editTxn = await ref
          .read(transactionRepositoryProvider)
          .getById(widget.editTransactionId!);
    }

    if (mounted) {
      setState(() {
        _accounts = accounts;
        _categories = categories;

        if (editTxn != null) {
          _selectedType = editTxn.type;
          _selectedAccountId = editTxn.accountId;
          _selectedCategoryId = editTxn.categoryId;
          _selectedDate = editTxn.date;
          _amountController.text = ThousandSeparatorInputFormatter()
              .formatEditUpdate(
                const TextEditingValue(),
                TextEditingValue(text: editTxn.amount.toString()),
              )
              .text;
          _descController.text = editTxn.description ?? '';
          _notesController.text = editTxn.notes ?? '';
        } else {
          if (accounts.isNotEmpty) _selectedAccountId = accounts.first.id;
          _updateCategoriesForType();
        }
      });
    }
  }

  void _updateCategoriesForType() {
    final catType = (_selectedType == TransactionType.income ||
            _selectedType == TransactionType.refund)
        ? CategoryType.income
        : CategoryType.expense;

    final filtered = _categories.where((c) => c.type == catType).toList();
    if (filtered.isNotEmpty &&
        !filtered.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = filtered.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _notesController.dispose();
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
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih dompet terlebih dahulu'),
        ),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori terlebih dahulu'),
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

      if (widget.editTransactionId != null) {
        await ref.read(transactionRepositoryProvider).updateTransaction(
              txnId: widget.editTransactionId!,
              type: _selectedType,
              accountId: _selectedAccountId,
              categoryId: _selectedCategoryId,
              amount: amount,
              date: _selectedDate,
              description: _descController.text.trim().isEmpty
                  ? null
                  : _descController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perubahan transaksi berhasil disimpan! ✅'),
            ),
          );
          context.pop();
        }
      } else {
        await ref.read(transactionRepositoryProvider).create(
              type: _selectedType,
              accountId: _selectedAccountId!,
              categoryId: _selectedCategoryId!,
              amount: amount,
              date: _selectedDate,
              description: _descController.text.trim().isEmpty
                  ? null
                  : _descController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

        if (mounted) {
          final typeLabel = _selectedType == TransactionType.income
              ? 'Pemasukan'
              : _selectedType == TransactionType.expense
                  ? 'Pengeluaran'
                  : 'Refund';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$typeLabel berhasil dicatat! ✅'),
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
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

    // Filter kategori berdasarkan tipe transaksi
    final catType = (_selectedType == TransactionType.income ||
            _selectedType == TransactionType.refund)
        ? CategoryType.income
        : CategoryType.expense;
    final filteredCategories =
        _categories.where((c) => c.type == catType).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editTransactionId != null
              ? 'Ubah Transaksi'
              : 'Catat Transaksi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: tokens.pad, vertical: 16),
          children: [
            // === Tipe Transaksi Segmented Control ===
            Text(
              'Tipe Transaksi',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(tokens.radiusControl),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  _TypeButton(
                    label: 'Pengeluaran',
                    icon: Icons.arrow_upward_rounded,
                    activeColor: tokens.expense,
                    isSelected: _selectedType == TransactionType.expense,
                    onTap: () {
                      setState(() {
                        _selectedType = TransactionType.expense;
                        _updateCategoriesForType();
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  _TypeButton(
                    label: 'Pemasukan',
                    icon: Icons.arrow_downward_rounded,
                    activeColor: tokens.income,
                    isSelected: _selectedType == TransactionType.income,
                    onTap: () {
                      setState(() {
                        _selectedType = TransactionType.income;
                        _updateCategoriesForType();
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  _TypeButton(
                    label: 'Refund',
                    icon: Icons.replay_rounded,
                    activeColor: tokens.warning,
                    isSelected: _selectedType == TransactionType.refund,
                    onTap: () {
                      setState(() {
                        _selectedType = TransactionType.refund;
                        _updateCategoriesForType();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // === Jumlah (Rp) Input ===
            Text(
              'Jumlah (Rp)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                hintText: '0',
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandSeparatorInputFormatter(),
              ],
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Jumlah wajib diisi';
                final amount =
                    int.tryParse(v.replaceAll('.', '').replaceAll(',', ''));
                if (amount == null || amount <= 0) {
                  return 'Jumlah harus lebih dari 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // === Dompet Picker ===
            Text(
              'Dompet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            if (_accounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(tokens.radiusControl),
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: tokens.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Buat dompet terlebih dahulu',
                        style: TextStyle(color: tokens.warning, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pushNamed('create_account'),
                      child: const Text('Buat'),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _accounts.map((account) {
                  final isSelected = _selectedAccountId == account.id;
                  return InkWell(
                    onTap: () =>
                        setState(() => _selectedAccountId = account.id),
                    borderRadius: BorderRadius.circular(tokens.radiusChip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? tokens.surfaceRaised : tokens.surface,
                        borderRadius: BorderRadius.circular(tokens.radiusChip),
                        border: Border.all(
                          color:
                              isSelected ? tokens.textPrimary : tokens.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: isSelected
                                ? tokens.textPrimary
                                : tokens.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            account.name,
                            style: TextStyle(
                              color: isSelected
                                  ? tokens.textPrimary
                                  : tokens.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // === Kategori Picker ===
            Text(
              'Kategori',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            if (filteredCategories.isEmpty)
              Text('Tidak ada kategori yang tersedia.',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filteredCategories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return InkWell(
                    onTap: () => setState(() => _selectedCategoryId = cat.id),
                    borderRadius: BorderRadius.circular(tokens.radiusChip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? tokens.surfaceRaised : tokens.surface,
                        borderRadius: BorderRadius.circular(tokens.radiusChip),
                        border: Border.all(
                          color:
                              isSelected ? tokens.textPrimary : tokens.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cat.icon != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(cat.icon!,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          Text(
                            cat.name,
                            style: TextStyle(
                              color: isSelected
                                  ? tokens.textPrimary
                                  : tokens.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // === Tanggal Transaksi ===
            Text(
              'Tanggal',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(tokens.radiusControl),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(tokens.radiusControl),
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
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: tokens.textMuted, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // === Deskripsi (Opsional) ===
            Text(
              'DESKRIPSI (OPSIONAL)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                hintText: 'Contoh: Belanja bulanan, Bonus proyek',
              ),
              maxLength: 500,
            ),
            const SizedBox(height: 12),

            // === Catatan (Opsional) ===
            Text(
              'CATATAN (OPSIONAL)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Keterangan tambahan...',
              ),
              maxLines: 2,
              maxLength: 1000,
            ),
            const SizedBox(height: 28),

            // === Tombol Simpan ===
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.editTransactionId != null
                            ? 'Simpan Perubahan'
                            : (_selectedType == TransactionType.income
                                ? 'Simpan Pemasukan'
                                : _selectedType == TransactionType.expense
                                    ? 'Simpan Pengeluaran'
                                    : 'Simpan Refund'),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color activeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? tokens.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.radiusControl),
            border: isSelected ? Border.all(color: tokens.border) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : tokens.textMuted,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? tokens.textPrimary : tokens.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
