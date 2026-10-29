import 'package:flutter/material.dart';
import 'package:money_flow/core/theme/app_theme.dart';

/// Halaman splash/loading awal saat aplikasi pertama kali dibuka (Finsave style).
class SplashScreen extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const SplashScreen({
    super.key,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.ground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Logo Brand Container (Official Project Icon)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: tokens.brand,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // App Title
                Text(
                  'Money Flow',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                // Tagline
                Text(
                  'Pencatatan Keuangan Mandiri & Aman',
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),

                // Loading Indicator or Error State
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.expenseBg,
                      borderRadius: BorderRadius.circular(tokens.radiusControl),
                      border: Border.all(
                        color: tokens.expense.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: tokens.expense,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: tokens.expenseInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Menyiapkan data...',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],

                const Spacer(flex: 2),

                // Footer Version
                Text(
                  'v2.1.1',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
