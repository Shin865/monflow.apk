import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';

/// Layar catat transaksi baru (pemasukan/pengeluaran/refund).
class CreateTransactionScreen extends ConsumerStatefulWidget {
  const CreateTransactionScreen({super.key});

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

    if (mounted) {
      setState(() {
        _accounts = accounts;
        _categories = categories;
        if (accounts.isNotEmpty) _selectedAccountId = accounts.first.id;
        _updateCategoriesForType();
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
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih dompet terlebih dahulu'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori terlebih dahulu'),
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
            backgroundColor: AppColors.income,
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
    // Filter kategori berdasarkan tipe transaksi
    final catType = (_selectedType == TransactionType.income ||
            _selectedType == TransactionType.refund)
        ? CategoryType.income
        : CategoryType.expense;
    final filteredCategories =
        _categories.where((c) => c.type == catType).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catat Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // === Tipe Transaksi ===
            const Text('Tipe Transaksi',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeButton(
                  label: 'Pengeluaran',
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.expense,
                  isSelected: _selectedType == TransactionType.expense,
                  onTap: () {
                    setState(() {
                      _selectedType = TransactionType.expense;
                      _updateCategoriesForType();
                    });
                  },
                ),
                const SizedBox(width: 8),
                _TypeButton(
                  label: 'Pemasukan',
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.income,
                  isSelected: _selectedType == TransactionType.income,
                  onTap: () {
                    setState(() {
                      _selectedType = TransactionType.income;
                      _updateCategoriesForType();
                    });
                  },
                ),
                const SizedBox(width: 8),
                _TypeButton(
                  label: 'Refund',
                  icon: Icons.replay_rounded,
                  color: AppColors.refund,
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
            const SizedBox(height: 24),

            // === Jumlah ===
            const Text('Jumlah (Rp)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                hintText: '0',
                prefixText: 'Rp ',
                prefixIcon: Icon(
                  Icons.attach_money_rounded,
                  color: _selectedType == TransactionType.income
                      ? AppColors.income
                      : _selectedType == TransactionType.expense
                          ? AppColors.expense
                          : AppColors.refund,
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
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

            // === Dompet ===
            const Text('Dompet',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            if (_accounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Buat dompet terlebih dahulu',
                        style:
                            TextStyle(color: AppColors.warning, fontSize: 13),
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
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedAccountId = account.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        account.name,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // === Kategori ===
            const Text('Kategori',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            if (filteredCategories.isEmpty)
              const Text('Tidak ada kategori',
                  style: TextStyle(color: AppColors.textMuted))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filteredCategories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryId = cat.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cat.icon != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(cat.icon!,
                                  style: const TextStyle(fontSize: 16)),
                            ),
                          Text(
                            cat.name,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // === Tanggal ===
            const Text('Tanggal',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

            // === Deskripsi ===
            const Text('Deskripsi (opsional)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                hintText: 'Contoh: Makan siang, Gaji Oktober',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // === Catatan ===
            const Text('Catatan (opsional)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Catatan tambahan...',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
              maxLength: 1000,
            ),
            const SizedBox(height: 32),

            // === Submit ===
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedType == TransactionType.income
                      ? AppColors.income
                      : _selectedType == TransactionType.expense
                          ? AppColors.expense
                          : AppColors.refund,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _selectedType == TransactionType.income
                            ? 'Simpan Pemasukan'
                            : _selectedType == TransactionType.expense
                                ? 'Simpan Pengeluaran'
                                : 'Simpan Refund',
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withOpacity(0.15) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? color : AppColors.textMuted, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
