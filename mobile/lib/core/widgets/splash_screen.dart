import 'package:flutter/material.dart';
import 'package:money_flow/core/theme/app_theme.dart';

/// Halaman splash/loading awal saat aplikasi pertama kali dibuka.
///
/// Menampilkan identitas visual Money Flow dengan indikator loading halus,
/// mendukung tema terang dan gelap, serta menyediakan tampilan error
/// dengan tombol coba lagi (retry) jika proses inisialisasi gagal.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Logo Container
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5)
                            .withOpacity(isDark ? 0.35 : 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.show_chart_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // App Title
                Text(
                  'Money Flow',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Tagline
                Text(
                  'Pencatatan Keuangan Mandiri & Aman',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),

                // Loading Indicator or Error State
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.expense.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.expense,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: AppColors.expense,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Menyiapkan data...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],

                const Spacer(flex: 2),

                // Subtle footer
                Text(
                  'v1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted.withOpacity(0.6),
                    fontSize: 11,
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
