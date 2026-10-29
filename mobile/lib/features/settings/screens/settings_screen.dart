import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
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
                if (result.filePath != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Bagikan / Simpan'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Share.shareXFiles([XFile(result.filePath!)],
                          subject: 'Money Flow Backup JSON');
                    },
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

    File? selectedFile;

    final selected = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih file untuk melihat pratinjau sebelum pemulihan',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                tileColor: AppColors.primary.withOpacity(0.08),
                leading: const Icon(Icons.file_open_rounded,
                    color: AppColors.primary, size: 28),
                title: const Text('Pilih File dari Perangkat...',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                    'Cari file .json di folder Download/Dokumen',
                    style: TextStyle(fontSize: 12)),
                trailing:
                    const Icon(Icons.chevron_right, color: AppColors.primary),
                onTap: () => Navigator.pop(ctx, '__PICK_FILE__'),
              ),
              const SizedBox(height: 12),
              const Text(
                'CADANGAN LOKAL TERSIMPAN',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              if (backups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Belum ada cadangan lokal di folder internal.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ),
                )
              else
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
                          color: Theme.of(context).cardColor,
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
                          onTap: () => Navigator.pop(ctx, file),
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

    if (selected == null || !mounted) return;

    if (selected == '__PICK_FILE__') {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result != null && result.files.single.path != null) {
          selectedFile = File(result.files.single.path!);
        } else {
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal memilih file: $e'),
                backgroundColor: AppColors.expense),
          );
        }
        return;
      }
    } else if (selected is File) {
      selectedFile = selected;
    }

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
              Icon(Icons.enhanced_encryption_rounded, color: AppColors.warning),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
              if (res.success && res.filePath != null)
                FilledButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Bagikan / Simpan'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Share.shareXFiles([XFile(res.filePath!)],
                        subject: 'Money Flow Encrypted Backup');
                  },
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

    File? selectedFile;

    final selected = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
              const SizedBox(height: 4),
              const Text(
                'Pilih file terenkripsi (.enc.json) dari penyimpanan',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: AppColors.warning.withOpacity(0.5), width: 1.5),
                ),
                tileColor: AppColors.warningBg,
                leading: const Icon(Icons.file_open_rounded,
                    color: AppColors.warning, size: 28),
                title: const Text('Pilih File dari Perangkat...',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Cari file .json / .enc.json di perangkat',
                    style: TextStyle(fontSize: 12)),
                trailing:
                    const Icon(Icons.chevron_right, color: AppColors.warning),
                onTap: () => Navigator.pop(ctx, '__PICK_FILE__'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cadangan terenkripsi lokal',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0),
              ),
              const SizedBox(height: 8),
              if (files.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                        'Belum ada file cadangan terenkripsi di folder internal.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final f = files[index];
                      final name = f.path.split(Platform.pathSeparator).last;
                      return ListTile(
                        leading: const Icon(Icons.enhanced_encryption_rounded,
                            color: AppColors.warning),
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

    if (selected == null || !mounted) return;

    if (selected == '__PICK_FILE__') {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result != null && result.files.single.path != null) {
          selectedFile = File(result.files.single.path!);
        } else {
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal memilih file: $e'),
                backgroundColor: AppColors.expense),
          );
        }
        return;
      }
    } else if (selected is File) {
      selectedFile = selected;
    }

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
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: tokens.pad, vertical: 12),
        children: [
          // App Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(tokens.radiusCard),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(tokens.radiusControl),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Icon(Icons.show_chart_rounded,
                      color: tokens.dataHue, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Money Flow',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Versi 2.1.1+4 • Standalone Offline',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Master Data Section
          Text(
            'Master Data & Keuangan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
              letterSpacing: 0,
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
            iconColor: AppColors.brandTeal,
            title: 'Laporan Keuangan',
            subtitle: 'Grafik arus kas, kategori, dan ekspor CSV/PDF',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => context.pushNamed('reports'),
          ),
          const SizedBox(height: 24),

          // Keamanan & Privasi Section
          Text(
            'Keamanan & Privasi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
              letterSpacing: 0,
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
              iconColor: AppColors.brandTeal,
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
              iconColor: AppColors.transfer,
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
          Text(
            'Data & Cadangan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.enhanced_encryption_rounded,
            iconColor: AppColors.warning,
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
            iconColor: AppColors.warning,
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
          Text(
            'Tentang',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.primary,
            title: 'Tentang Aplikasi',
            subtitle: 'Versi, developer, GitHub, dan lisensi',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => context.pushNamed('about'),
          ),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.system_update_rounded,
            iconColor: AppColors.transfer,
            title: 'Cek Pembaruan APK',
            subtitle: 'Lihat rilis terbaru di GitHub Releases',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => context.pushNamed('about'),
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
              color: isBold
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurface,
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
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusCard),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(tokens.radiusControl),
                border: Border.all(color: tokens.border),
              ),
              child: Icon(icon, color: tokens.textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textMuted,
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
