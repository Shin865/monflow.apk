import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:money_flow/core/theme/app_theme.dart';

/// Halaman Tentang Aplikasi — menampilkan informasi developer, versi,
/// tautan GitHub, dan mekanisme cek pembaruan APK dari GitHub Releases.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = '...';
  String _buildNumber = '...';
  bool _isCheckingUpdate = false;

  static const String _githubRepo = 'Shin865/monflow.apk';
  static const String _githubUrl = 'https://github.com/$_githubRepo';
  static const String _releasesUrl = '$_githubUrl/releases/latest';
  static const String _developerName = 'Shin865';
  static const String _developerGithub = 'https://github.com/Shin865';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersion = '1.0.0';
          _buildNumber = '1';
        });
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Tidak dapat membuka tautan. Periksa koneksi internet.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka tautan: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);

    try {
      // Buka halaman rilis resmi di GitHub — pengguna bisa membandingkan versi
      // dan mengunduh APK langsung dari repositori resmi
      await _openUrl(_releasesUrl);
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _showLicenseDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lisensi & Hak Cipta'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lisensi Proyek Money Flow:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Hak Cipta © 2024-2026 Shin865. Lisensi spesifik proyek ini belum ditentukan secara publik di repository dan merupakan hak prerogatif pemilik proyek.',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 16),
            Text(
              'Pustaka Pihak Ketiga (Open Source):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Aplikasi ini menggunakan berbagai pustaka open source seperti Flutter SDK, Drift, Riverpod, Local Auth, dan pustaka lainnya dengan lisensi masing-masing.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              showLicensePage(
                context: context,
                applicationName: 'Money Flow',
                applicationVersion: '$_appVersion+$_buildNumber',
              );
            },
            child: const Text('Lihat Semua Lisensi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Logo & Identity
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
            const SizedBox(height: 20),

            Text(
              'Money Flow',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),

            Text(
              'Versi $_appVersion+$_buildNumber',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),

            Text(
              'Pencatatan Keuangan Mandiri & Aman',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: 32),

            // About Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tentang',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Money Flow adalah aplikasi pengelolaan keuangan pribadi '
                    'yang membantu pengguna mencatat dan memantau kondisi keuangan. '
                    'Semua data tersimpan secara aman di perangkat Anda demi privasi maksimal.\n\n'
                    'Fitur utama meliputi pengelolaan dompet & akun, pencatatan pemasukan & pengeluaran, '
                    'riwayat transaksi, transfer dana, utang & piutang, simpanan deposito & investasi, '
                    'rencana pembelian, laporan keuangan, serta backup & pemulihan data.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Developer Info
            _buildInfoTile(
              icon: Icons.person_rounded,
              iconColor: AppColors.primary,
              title: 'Pengembang',
              subtitle: _developerName,
              onTap: () => _openUrl(_developerGithub),
            ),
            const SizedBox(height: 8),

            _buildInfoTile(
              icon: Icons.code_rounded,
              iconColor: Colors.white,
              title: 'Repository GitHub',
              subtitle: _githubRepo,
              onTap: () => _openUrl(_githubUrl),
            ),
            const SizedBox(height: 8),

            _buildInfoTile(
              icon: Icons.bug_report_rounded,
              iconColor: AppColors.warning,
              title: 'Laporkan Masalah',
              subtitle: 'Buka issue di GitHub',
              onTap: () => _openUrl('$_githubUrl/issues'),
            ),
            const SizedBox(height: 8),

            // License Info
            _buildInfoTile(
              icon: Icons.description_outlined,
              iconColor: AppColors.income,
              title: 'Lisensi & Hak Cipta',
              subtitle: 'Lisensi aplikasi dan pustaka pihak ketiga',
              onTap: () => _showLicenseDetails(context),
            ),

            const SizedBox(height: 24),

            // Check for Updates
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isCheckingUpdate ? null : _checkForUpdate,
                icon: _isCheckingUpdate
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.system_update_rounded, size: 20),
                label: Text(
                  _isCheckingUpdate
                      ? 'Mengecek...'
                      : 'Cek Pembaruan di GitHub Releases',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Footer
            Text(
              '© 2024-2026 $_developerName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dibuat dengan Flutter & Drift (SQLite)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
