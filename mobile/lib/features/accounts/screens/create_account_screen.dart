import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/thousand_separator_formatter.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/core/widgets/common_widgets.dart';
import 'package:money_flow/data/repositories/account_repository.dart';

/// Layar buat akun/dompet baru (Finsave Reference & Taste-Skill).
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _descController = TextEditingController();

  AccountType _selectedType = AccountType.cash;
  String? _selectedIcon;
  String _selectedColor = '#0F6B5F';
  bool _isLoading = false;

  final _typeOptions = [
    (AccountType.cash, 'Uang Tunai', Icons.payments_outlined),
    (AccountType.bank, 'Rekening Bank', Icons.account_balance_outlined),
    (AccountType.ewallet, 'E-Wallet', Icons.phone_android_outlined),
    (AccountType.savings, 'Tabungan', Icons.savings_outlined),
    (AccountType.other, 'Lainnya', Icons.wallet_outlined),
  ];

  final _colorOptions = [
    '#0F6B5F', // Finsave Teal
    '#18181B', // Charcoal
    '#16A34A', // Emerald
    '#2563EB', // Blue
    '#D97706', // Amber
    '#DC2626', // Red
    '#7C3AED', // Purple
    '#DB2777', // Pink
    '#475569', // Slate
    '#64748B', // Neutral
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
            content: Text('Dompet berhasil dibuat'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat dompet: $e'),
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
        title: const Text('Buat Dompet Baru'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Nama Dompet
            Text(
              'Nama Dompet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Contoh: Dompet Utama, BCA, GoPay',
                prefixIcon: Icon(Icons.edit_outlined),
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
            const SizedBox(height: 16),

            // Tipe Dompet
            Text(
              'Tipe Dompet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _typeOptions.map((option) {
                final isSelected = _selectedType == option.$1;
                return InkWell(
                  onTap: () => setState(() => _selectedType = option.$1),
                  borderRadius: BorderRadius.circular(tokens.radiusChip),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? tokens.brandWash : tokens.surface,
                      borderRadius: BorderRadius.circular(tokens.radiusChip),
                      border: Border.all(
                        color: isSelected ? tokens.brand : tokens.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option.$3,
                          size: 16,
                          color:
                              isSelected ? tokens.brand : tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          option.$2,
                          style: TextStyle(
                            color:
                                isSelected ? tokens.brand : tokens.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Saldo Awal
            Text(
              'Saldo Awal (Rp)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _balanceController,
              decoration: const InputDecoration(
                hintText: 'Masukkan nominal saldo',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandSeparatorInputFormatter(),
              ],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Saldo awal wajib diisi';
                }
                final parsed =
                    int.tryParse(v.replaceAll('.', '').replaceAll(',', ''));
                if (parsed == null || parsed < 0) {
                  return 'Nominal saldo tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Warna Tag
            Text(
              'Warna Tag Identitas',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
                fontSize: 12,
              ),
            ),
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
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? tokens.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
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
                hintText: 'Keterangan atau nomor rekening...',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              maxLines: 2,
              maxLength: 255,
            ),
            const SizedBox(height: 20),

            // Submit Button
            MfButton.primary(
              label: 'Simpan Dompet',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
