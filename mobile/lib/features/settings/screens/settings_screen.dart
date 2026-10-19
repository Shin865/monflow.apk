import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/services/backup_restore_service.dart';
import 'package:money_flow/data/services/encrypted_backup_service.dart';
import 'package:money_flow/data/services/security_service.dart';
import 'package:money_flow/features/security/screens/setup_pin_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;

  bool _isPinEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isLockOnBackground = true;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final sec = ref.read(securityServiceProvider);
    final pin = await sec.isPinEnabled();
    final bio = await sec.isBiometricEnabled();
    final lockBg = await sec.isLockOnBackgroundEnabled();
    final canBio = await sec.canAuthenticateBiometric();

    if (mounted) {
      setState(() {
        _isPinEnabled = pin;
        _isBiometricEnabled = bio;
        _isLockOnBackground = lockBg;
        _canCheckBiometrics = canBio;
      });
    }
  }

  // ============================================================
  // KEAMANAN & PIN
  // ============================================================

  Future<void> _togglePin(bool value) async {
    final sec = ref.read(securityServiceProvider);
    if (value) {
      final success = await showDialog<bool>(
        context: context,
        builder: (ctx) => const SetupPinDialog(),
      );
      if (success == true) {
        _loadSecuritySettings();
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nonaktifkan Kunci PIN?'),
          content: const Text(
            'Aplikasi tidak akan meminta PIN saat dibuka kembali. Anda yakin ingin mematikan kunci keamanan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Nonaktifkan'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await sec.disablePin();
        _loadSecuritySettings();
      }
    }
  }

  // ============================================================
  // BACKUP BIASA
  // ============================================================

  Future<void> _performBackup() async {
    setState(() => _isBackingUp = true);

    try {
      final service = ref.read(backupRestoreServiceProvider);
      final result = await service.backupToFile();

      if (mounted) {
        if (result.success) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.income, size: 28),
                  SizedBox(width: 10),
                  Text('Cadangan Berhasil'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.message),
                  if (result.filePath != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        result.filePath!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _performRestore() async {
    final service = ref.read(backupRestoreServiceProvider);
    final backups = await service.listBackups();

    if (!mounted) return;

    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Belum ada file cadangan tersedia. Buat cadangan terlebih dahulu.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final selectedFile = await showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih File Cadangan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih file untuk melihat pratinjau sebelum pemulihan',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: backups.length,
                  itemBuilder: (context, index) {
                    final file = backups[index];
                    final fileName =
                        file.path.split(Platform.pathSeparator).last;
                    final stat = file.statSync();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined,
                            color: AppColors.primary),
                        title: Text(
                          fileName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${(stat.size / 1024).toStringAsFixed(1)} KB • Diubah ${formatDate(stat.modified)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            size: 20, color: AppColors.textMuted),
                        onTap: () => Navigator.pop(context, file),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedFile == null || !mounted) return;

    String fileContent = '';
    try {
      fileContent = await selectedFile.readAsString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal membaca file cadangan: $e'),
              backgroundColor: AppColors.expense),
        );
      }
      return;
    }

    final preview = service.inspectBackup(fileContent);

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              preview.isValid
                  ? Icons.preview_rounded
                  : Icons.error_outline_rounded,
              color: preview.isValid ? AppColors.primary : AppColors.expense,
              size: 26,
            ),
            const SizedBox(width: 8),
            const Text('Pratinjau Cadangan'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!preview.isValid) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.expense.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning,
                          color: AppColors.expense, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          preview.validationError ??
                              'Format cadangan tidak valid.',
                          style: const TextStyle(
                              color: AppColors.expense, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _PreviewItemRow(label: 'Format', value: preview.format),
                _PreviewItemRow(
                    label: 'Versi Skema', value: 'v${preview.schemaVersion}'),
                _PreviewItemRow(
                    label: 'Waktu Ekspor',
                    value: formatDate(preview.exportedAt)),
                const Divider(height: 20),
                _PreviewItemRow(
                    label: 'Jumlah Akun',
                    value: '${preview.accountsCount} akun'),
                _PreviewItemRow(
                    label: 'Jumlah Kategori',
                    value: '${preview.categoriesCount} kategori'),
                _PreviewItemRow(
                    label: 'Jumlah Transaksi',
                    value: '${preview.transactionsCount} transaksi'),
                _PreviewItemRow(
                    label: 'Jumlah Transfer',
                    value: '${preview.transfersCount} transfer'),
                _PreviewItemRow(
                  label: 'Total Saldo Cadangan',
                  value: formatRupiah(preview.totalBalance),
                  isBold: true,
                ),
                const Divider(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode: Ganti Seluruh Data (Full Replace)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Seluruh data aktif saat ini akan diganti secara atomik. '
                        'Jika proses gagal, database aktif tetap utuh.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          if (preview.isValid)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Ya, Pulihkan Sekarang'),
            ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);

    try {
      final result = await service.restoreFromJson(fileContent);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              result.success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: result.success ? AppColors.income : AppColors.expense,
              size: 40,
            ),
            title:
                Text(result.success ? 'Pemulihan Berhasil' : 'Pemulihan Gagal'),
            content: Text(result.message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  // ============================================================
  // CADANGAN TERENKRIPSI (AES-256-GCM + PBKDF2)
  // ============================================================

  Future<void> _performEncryptedBackup() async {
    final passwordController = TextEditingController();
    String? error;

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.enhanced_encryption_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Cadangan Terenkripsi'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Data cadangan akan dienkripsi dengan AES-256-GCM & PBKDF2. '
                'Kata sandi ini WAJIB diingat untuk memulihkan cadangan. '
                'Kehilangan kata sandi membuat data tidak dapat dipulihkan.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Enkripsi (min. 6 karakter)',
                  errorText: error,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final p = passwordController.text.trim();
                if (p.length < 6) {
                  setDlgState(() => error = 'Kata sandi minimal 6 karakter.');
                  return;
                }
                Navigator.pop(ctx, p);
              },
              child: const Text('Enkripsi & Simpan'),
            ),
          ],
        ),
      ),
    );

    if (password == null || !mounted) return;

    setState(() => _isBackingUp = true);

    try {
      final encService = ref.read(encryptedBackupServiceProvider);
      final res = await encService.backupEncryptedToFile(password);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              res.success ? Icons.shield_rounded : Icons.error_outline_rounded,
              color: res.success ? AppColors.income : AppColors.expense,
              size: 40,
            ),
            title: Text(res.success
                ? 'Cadangan Terenkripsi Berhasil'
                : 'Gagal Enkripsi'),
            content: Text(res.message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _performEncryptedRestore() async {
    final encService = ref.read(encryptedBackupServiceProvider);
    final files = await encService.listEncryptedBackups();

    if (!mounted) return;

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Belum ada file cadangan terenkripsi (.enc.json) tersedia.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final selectedFile = await showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih File Cadangan Terenkripsi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final f = files[index];
                    final name = f.path.split(Platform.pathSeparator).last;
                    return ListTile(
                      leading: const Icon(Icons.enhanced_encryption_rounded,
                          color: Colors.amber),
                      title: Text(name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${(f.statSync().size / 1024).toStringAsFixed(1)} KB'),
                      onTap: () => Navigator.pop(ctx, f),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedFile == null || !mounted) return;

    final content = await selectedFile.readAsString();
    if (!mounted) return;
    final header = EncryptedBackupService.inspectHeader(content);
    if (!header.isValidFormat) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(header.error ?? 'Format tidak valid.'),
            backgroundColor: AppColors.expense),
      );
      return;
    }

    final passwordController = TextEditingController();
    String? error;

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Masukkan Kata Sandi Dekripsi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cadangan dibuat pada: ${formatDate(header.exportedAt)}\nAlgoritma: ${header.cipher} + ${header.kdf}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Cadangan',
                  errorText: error,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final p = passwordController.text.trim();
                if (p.isEmpty) {
                  setDlgState(() => error = 'Kata sandi tidak boleh kosong.');
                  return;
                }
                Navigator.pop(ctx, p);
              },
              child: const Text('Dekripsi & Pulihkan'),
            ),
          ],
        ),
      ),
    );

    if (password == null || !mounted) return;

    setState(() => _isRestoring = true);

    try {
      final res = await encService.restoreEncryptedFromJson(content, password);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              res.success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: res.success ? AppColors.income : AppColors.expense,
              size: 40,
            ),
            title: Text(res.success ? 'Pemulihan Berhasil' : 'Pemulihan Gagal'),
            content: Text(res.message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.show_chart_rounded, color: Colors.white, size: 36),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Money Flow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Versi 1.0.0+1 • Standalone Offline',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Master Data Section
          const Text(
            'MASTER DATA & KEUANGAN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.category_rounded,
            iconColor: AppColors.primary,
            title: 'Kelola Kategori',
            subtitle: 'Atur kategori pemasukan & pengeluaran',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => context.pushNamed('categories'),
          ),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.pie_chart_outline_rounded,
            iconColor: AppColors.income,
            title: 'Anggaran (Budget)',
            subtitle: 'Pantau batas pengeluaran bulanan per kategori',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => context.pushNamed('budgets'),
          ),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.receipt_long_rounded,
            iconColor: AppColors.warning,
            title: 'Tagihan (Bills)',
            subtitle: 'Kelola tagihan sekali bayar & rutin',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => context.pushNamed('bills'),
          ),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.handshake_outlined,
            iconColor: AppColors.transfer,
            title: 'Hutang & Piutang',
            subtitle: 'Catat pinjaman, piutang, dan jadwal cicilan',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => context.pushNamed('debts'),
          ),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.analytics_rounded,
            iconColor: Colors.cyan,
            title: 'Laporan Keuangan',
            subtitle: 'Grafik arus kas, kategori, dan ekspor CSV/PDF',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => context.pushNamed('reports'),
          ),
          const SizedBox(height: 24),

          // Keamanan & Privasi Section
          const Text(
            'KEAMANAN & PRIVASI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.primary,
            title: 'Kunci Aplikasi dengan PIN',
            subtitle:
                _isPinEnabled ? 'PIN aktif (Salted PBKDF2 Hash)' : 'Nonaktif',
            trailing: Switch(
              value: _isPinEnabled,
              onChanged: _togglePin,
            ),
            onTap: () => _togglePin(!_isPinEnabled),
          ),
          if (_isPinEnabled) ...[
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.fingerprint_rounded,
              iconColor: Colors.tealAccent,
              title: 'Buka Kunci dengan Biometrik',
              subtitle: _canCheckBiometrics
                  ? 'Gunakan sidik jari atau wajah jika tersedia'
                  : 'Perangkat tidak memiliki sensor biometrik',
              trailing: Switch(
                value: _isBiometricEnabled,
                onChanged: _canCheckBiometrics
                    ? (val) async {
                        final sec = ref.read(securityServiceProvider);
                        await sec.setBiometricEnabled(val);
                        _loadSecuritySettings();
                      }
                    : null,
              ),
              onTap: null,
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.screen_lock_portrait_rounded,
              iconColor: Colors.deepPurpleAccent,
              title: 'Kunci Otomatis Saat Keluar',
              subtitle: 'Kunci layar ketika aplikasi beralih ke latar belakang',
              trailing: Switch(
                value: _isLockOnBackground,
                onChanged: (val) async {
                  final sec = ref.read(securityServiceProvider);
                  await sec.setLockOnBackgroundEnabled(val);
                  _loadSecuritySettings();
                },
              ),
              onTap: null,
            ),
          ],
          const SizedBox(height: 24),

          // Backup & Restore Section
          const Text(
            'DATA & CADANGAN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.enhanced_encryption_rounded,
            iconColor: Colors.amber,
            title: 'Cadangan Terenkripsi (AES-GCM)',
            subtitle:
                'Enkripsi data dengan kata sandi (Aman untuk media eksternal)',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: _isBackingUp ? null : _performEncryptedBackup,
          ),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.lock_open_rounded,
            iconColor: Colors.amberAccent,
            title: 'Pulihkan Cadangan Terenkripsi',
            subtitle:
                'Buka dan pulihkan data dari file .enc.json dengan kata sandi',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: _isRestoring ? null : _performEncryptedRestore,
          ),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.backup_rounded,
            iconColor: AppColors.income,
            title: 'Cadangkan Data (JSON)',
            subtitle:
                'Ekspor seluruh data ke file snapshot JSON standar (biasa)',
            trailing: _isBackingUp
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.income),
                  )
                : const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
            onTap: _isBackingUp ? null : _performBackup,
          ),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.restore_rounded,
            iconColor: AppColors.transfer,
            title: 'Pulihkan Data (Restore)',
            subtitle:
                'Pratinjau & pulihkan data dari file cadangan standar (biasa)',
            trailing: _isRestoring
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.transfer),
                  )
                : const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
            onTap: _isRestoring ? null : _performRestore,
          ),
          const SizedBox(height: 24),

          // About Section
          const Text(
            'TENTANG',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.primary,
            title: 'Tentang Aplikasi',
            subtitle: 'Sistem manajemen keuangan offline-first',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Money Flow',
                applicationVersion: '1.0.0+1',
                applicationIcon: const Icon(Icons.show_chart_rounded,
                    color: AppColors.primary, size: 48),
                children: const [
                  Text(
                    'Aplikasi manajemen keuangan pribadi yang bekerja 100% offline.\n\n'
                    'Semua kalkulasi dilakukan lokal dengan presisi integer Rupiah, '
                    'dilengkapi sistem backup & restore snapshot yang aman, '
                    'serta proteksi enkripsi AES-256-GCM.',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          const _SettingsTile(
            icon: Icons.offline_bolt_rounded,
            iconColor: AppColors.income,
            title: 'Mode Offline',
            subtitle: '100% mandiri tanpa koneksi server eksternal',
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _PreviewItemRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _PreviewItemRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
