import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/account_repository.dart';

/// Layar buat akun/dompet baru.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  final _descController = TextEditingController();

  AccountType _selectedType = AccountType.cash;
  String? _selectedIcon;
  String _selectedColor = '#6366F1';
  bool _isLoading = false;

  final _typeOptions = [
    (AccountType.cash, 'Uang Tunai', Icons.payments_rounded),
    (AccountType.bank, 'Rekening Bank', Icons.account_balance_rounded),
    (AccountType.ewallet, 'E-Wallet', Icons.phone_android_rounded),
    (AccountType.savings, 'Tabungan', Icons.savings_rounded),
    (AccountType.other, 'Lainnya', Icons.wallet_rounded),
  ];

  final _colorOptions = [
    '#6366F1',
    '#3B82F6',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#EC4899',
    '#8B5CF6',
    '#F97316',
    '#14B8A6',
    '#6B7280',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final balanceText =
          _balanceController.text.replaceAll('.', '').replaceAll(',', '');
      final balance = int.tryParse(balanceText) ?? 0;

      await ref.read(accountRepositoryProvider).create(
            name: _nameController.text.trim(),
            type: _selectedType,
            initialBalance: balance,
            icon: _selectedIcon,
            color: _selectedColor,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dompet berhasil dibuat! 🎉'),
            backgroundColor: AppColors.income,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat dompet: $e'),
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
        title: const Text('Buat Dompet Baru'),
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
            // Nama
            const Text('Nama Dompet',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Contoh: BCA, GoPay, Dompet',
                prefixIcon: Icon(Icons.edit_rounded),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Nama dompet wajib diisi';
                }
                if (v.trim().length > 100) {
                  return 'Nama terlalu panjang (maks 100 karakter)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Tipe
            const Text('Tipe Dompet',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _typeOptions.map((option) {
                final isSelected = _selectedType == option.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = option.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.2)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(option.$3,
                            size: 18,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          option.$2,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
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

            // Saldo awal
            const Text('Saldo Awal (Rp)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _balanceController,
              decoration: const InputDecoration(
                hintText: '0',
                prefixIcon: Icon(Icons.attach_money_rounded),
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Saldo awal wajib diisi';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Warna
            const Text('Warna',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorOptions.map((colorHex) {
                final color =
                    Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                final isSelected = _selectedColor == colorHex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorHex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: color.withOpacity(0.5), blurRadius: 8)
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
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
                hintText: 'Catatan tambahan...',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
              maxLength: 255,
            ),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan Dompet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
