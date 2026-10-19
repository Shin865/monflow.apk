import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/services/security_service.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricIfAvailable();
    });
  }

  Future<void> _tryBiometricIfAvailable() async {
    final service = ref.read(securityServiceProvider);
    final bioEnabled = await service.isBiometricEnabled();
    if (bioEnabled) {
      await service.authenticateBiometric();
    }
  }

  void _onKeyPress(String digit) {
    if (_isChecking || _enteredPin.length >= 8) return;
    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length >= 4) {
      // Auto-submit saat mencapai panjang normal atau user menekan enter
      // Tapi untuk fleksibilitas 4-8 digit, sediakan tombol OK atau auto check pada panjang 6
      if (_enteredPin.length == 6) {
        _submitPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty || _isChecking) return;
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _submitPin() async {
    if (_enteredPin.length < 4) {
      setState(() => _errorMessage = 'Masukkan minimal 4 digit PIN.');
      return;
    }

    setState(() => _isChecking = true);
    final service = ref.read(securityServiceProvider);
    final result = await service.verifyPin(_enteredPin);

    if (mounted) {
      setState(() {
        _isChecking = false;
        if (!result.isSuccess) {
          _errorMessage = result.errorMessage;
          _enteredPin = '';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Money Flow Terkunci',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Masukkan PIN keamanan Anda untuk melanjutkan',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),

                // PIN dots indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final isFilled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? AppColors.primary : AppColors.border,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: AppColors.expense,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  const SizedBox(height: 16),

                const Spacer(flex: 1),

                // Numeric Keypad
                _buildKeypad(),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSpecialKey(
              icon: Icons.fingerprint_rounded,
              onTap: _tryBiometricIfAvailable,
            ),
            _buildNumberKey('0'),
            _buildSpecialKey(
              icon: Icons.backspace_outlined,
              onTap: _onBackspace,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_enteredPin.length >= 4)
          TextButton.icon(
            onPressed: _submitPin,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Buka Kunci',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildNumberKey).toList(),
    );
  }

  Widget _buildNumberKey(String digit) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).cardColor,
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSpecialKey(
      {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: Icon(icon, size: 28, color: AppColors.textPrimary),
      ),
    );
  }
}
