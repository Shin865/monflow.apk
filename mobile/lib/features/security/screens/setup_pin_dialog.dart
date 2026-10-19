import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/services/security_service.dart';

class SetupPinDialog extends ConsumerStatefulWidget {
  const SetupPinDialog({super.key});

  @override
  ConsumerState<SetupPinDialog> createState() => _SetupPinDialogState();
}

class _SetupPinDialogState extends ConsumerState<SetupPinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isConfirmStep = false;
  String _initialPin = '';
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onNext() {
    setState(() => _error = null);
    final pin = _pinController.text.trim();

    if (pin.length < 4 || pin.length > 8) {
      setState(() => _error = 'PIN harus 4 sampai 8 digit angka.');
      return;
    }

    if (!_isConfirmStep) {
      setState(() {
        _initialPin = pin;
        _isConfirmStep = true;
      });
    } else {
      final confirm = _confirmController.text.trim();
      if (confirm != _initialPin) {
        setState(() => _error = 'Konfirmasi PIN tidak cocok. Silakan ulangi.');
        return;
      }

      _savePin(_initialPin);
    }
  }

  Future<void> _savePin(String pin) async {
    try {
      final service = ref.read(securityServiceProvider);
      await service.setupPin(pin);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunci PIN berhasil diaktifkan.'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan PIN: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(_isConfirmStep ? 'Konfirmasi PIN' : 'Atur PIN Baru'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isConfirmStep
                ? 'Masukkan kembali PIN yang sama untuk konfirmasi:'
                : 'Masukkan 4-8 digit angka sebagai PIN keamanan aplikasi:',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _isConfirmStep ? _confirmController : _pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: InputDecoration(
              labelText: _isConfirmStep ? 'Konfirmasi PIN' : 'PIN Baru',
              counterText: '',
              errorText: _error,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onSubmitted: (_) => _onNext(),
          ),
          const SizedBox(height: 8),
          const Text(
            'Catatan: PIN melindungi akses lokal aplikasi dan bukan merupakan enkripsi file database.',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _onNext,
          child: Text(_isConfirmStep ? 'Simpan' : 'Lanjut'),
        ),
      ],
    );
  }
}
