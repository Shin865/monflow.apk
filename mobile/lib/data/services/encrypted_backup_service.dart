import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:money_flow/data/services/backup_restore_service.dart';

/// Hasil operasi backup terenkripsi.
class EncryptedBackupResult {
  final bool success;
  final String message;
  final String? filePath;

  const EncryptedBackupResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

/// Pratinjau file backup terenkripsi (sebelum dekripsi).
class EncryptedBackupHeader {
  final String format;
  final int version;
  final String cipher;
  final String kdf;
  final int kdfIterations;
  final String saltBase64;
  final String nonceBase64;
  final DateTime exportedAt;
  final bool isValidFormat;
  final String? error;

  const EncryptedBackupHeader({
    required this.format,
    required this.version,
    required this.cipher,
    required this.kdf,
    required this.kdfIterations,
    required this.saltBase64,
    required this.nonceBase64,
    required this.exportedAt,
    required this.isValidFormat,
    this.error,
  });
}

/// Service untuk backup terenkripsi dengan algoritma standar industri:
/// - Enkripsi terautentikasi: AES-GCM (256-bit)
/// - Penurunan kunci (KDF): PBKDF2 dengan HMAC-SHA256 (10.000 iterasi)
/// - Salt acak 16 byte kriptografis & Nonce acak 12 byte
/// - Kata sandi TIDAK PERNAH disimpan dalam file backup
/// - Validasi dekripsi & autentikasi penuh sebelum menyentuh database aktif
class EncryptedBackupService {
  final BackupRestoreService _plainBackupService;

  static const String currentFormat = 'money-flow-encrypted-backup';
  static const int currentVersion = 1;
  static const int kdfIterations = 10000;

  final _aesGcm = AesGcm.with256bits();
  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: kdfIterations,
    bits: 256,
  );

  EncryptedBackupService(this._plainBackupService);

  /// Generate random bytes menggunakan Random.secure().
  static List<int> _generateRandomBytes(int length) {
    final rand = Random.secure();
    return List<int>.generate(length, (_) => rand.nextInt(256));
  }

  /// Periksa dan ekstrak metadata header backup terenkripsi tanpa memerlukan kata sandi.
  static EncryptedBackupHeader inspectHeader(String jsonString) {
    try {
      final parsed = jsonDecode(jsonString);
      if (parsed is! Map<String, dynamic>) {
        return EncryptedBackupHeader(
          format: 'unknown',
          version: 0,
          cipher: '',
          kdf: '',
          kdfIterations: 0,
          saltBase64: '',
          nonceBase64: '',
          exportedAt: DateTime.now(),
          isValidFormat: false,
          error: 'Format bukan berupa objek JSON yang valid.',
        );
      }

      final format = parsed['format'] as String? ?? '';
      if (format != currentFormat) {
        return EncryptedBackupHeader(
          format: format,
          version: 0,
          cipher: '',
          kdf: '',
          kdfIterations: 0,
          saltBase64: '',
          nonceBase64: '',
          exportedAt: DateTime.now(),
          isValidFormat: false,
          error: 'Format tidak dikenali. Diharapkan "$currentFormat".',
        );
      }

      final version = parsed['version'] as int? ?? 0;
      if (version != currentVersion) {
        return EncryptedBackupHeader(
          format: format,
          version: version,
          cipher: '',
          kdf: '',
          kdfIterations: 0,
          saltBase64: '',
          nonceBase64: '',
          exportedAt: DateTime.now(),
          isValidFormat: false,
          error:
              'Versi format ($version) tidak didukung oleh versi aplikasi ini.',
        );
      }

      return EncryptedBackupHeader(
        format: format,
        version: version,
        cipher: parsed['cipher'] as String? ?? 'AES-256-GCM',
        kdf: parsed['kdf'] as String? ?? 'PBKDF2-HMAC-SHA256',
        kdfIterations: parsed['kdf_iterations'] as int? ?? kdfIterations,
        saltBase64: parsed['salt'] as String? ?? '',
        nonceBase64: parsed['nonce'] as String? ?? '',
        exportedAt: DateTime.tryParse(parsed['exported_at'] as String? ?? '') ??
            DateTime.now(),
        isValidFormat: true,
      );
    } catch (e) {
      return EncryptedBackupHeader(
        format: 'unknown',
        version: 0,
        cipher: '',
        kdf: '',
        kdfIterations: 0,
        saltBase64: '',
        nonceBase64: '',
        exportedAt: DateTime.now(),
        isValidFormat: false,
        error: 'Gagal membaca header cadangan terenkripsi: $e',
      );
    }
  }

  /// Ekspor cadangan database ke format JSON terenkripsi AES-256-GCM.
  Future<String> exportEncryptedToJson(String password) async {
    if (password.length < 6) {
      throw ArgumentError('Kata sandi enkripsi minimal 6 karakter.');
    }

    // 1. Ekspor plain snapshot JSON
    final plainJson = await _plainBackupService.exportToJson();
    final plainBytes = utf8.encode(plainJson);

    // 2. Generate random 16-byte salt dan random 12-byte nonce
    final salt = _generateRandomBytes(16);
    final nonce = _generateRandomBytes(12);

    // 3. Turunkan encryption key dengan PBKDF2-HMAC-SHA256
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    // 4. Enkripsi plain snapshot dengan AES-GCM terautentikasi
    final secretBox = await _aesGcm.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 5. Rakit container JSON terenkripsi
    final now = DateTime.now();
    final payload = {
      'format': currentFormat,
      'version': currentVersion,
      'app': 'money_flow',
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'kdf_iterations': kdfIterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'ciphertext': base64Encode(secretBox.cipherText),
      'exported_at': now.toIso8601String(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Buat file cadangan terenkripsi dan simpan ke folder dokumen aplikasi.
  Future<EncryptedBackupResult> backupEncryptedToFile(String password) async {
    try {
      final encryptedJson = await exportEncryptedToJson(password);
      final dir = await getApplicationDocumentsDirectory();
      final backupDir =
          Directory(p.join(dir.path, 'money_flow_encrypted_backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'money-flow-backup-$timestamp.enc.json';
      final file = File(p.join(backupDir.path, fileName));
      await file.writeAsString(encryptedJson);

      return EncryptedBackupResult(
        success: true,
        message: 'Cadangan terenkripsi berhasil disimpan: $fileName',
        filePath: file.path,
      );
    } catch (e) {
      return EncryptedBackupResult(
        success: false,
        message: 'Gagal membuat cadangan terenkripsi: $e',
      );
    }
  }

  /// Dekripsi dan verifikasi keaslian cadangan tanpa mengubah database.
  Future<String> decryptToJson(
      String encryptedJsonString, String password) async {
    final parsed = jsonDecode(encryptedJsonString) as Map<String, dynamic>;

    final salt = base64Decode(parsed['salt'] as String);
    final nonce = base64Decode(parsed['nonce'] as String);
    final macBytes = base64Decode(parsed['mac'] as String);
    final cipherText = base64Decode(parsed['ciphertext'] as String);

    // Derivasi kunci yang sama
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    // Dekripsi dengan verifikasi autentikasi MAC
    try {
      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw const FormatException(
        'Kata sandi salah atau isi cadangan terenkripsi rusak / telah dimodifikasi.',
      );
    }
  }

  /// Pulihkan database dari string JSON terenkripsi secara atomik.
  /// Jika kata sandi salah, dekripsi gagal dan database TIDAK DISENTUH SAMA SEKALI.
  Future<BackupResult> restoreEncryptedFromJson(
    String encryptedJsonString,
    String password,
  ) async {
    final header = inspectHeader(encryptedJsonString);
    if (!header.isValidFormat) {
      return BackupResult(
        success: false,
        message: header.error ?? 'Format cadangan terenkripsi tidak valid.',
      );
    }

    String plainJson;
    try {
      plainJson = await decryptToJson(encryptedJsonString, password);
    } catch (e) {
      return BackupResult(
        success: false,
        message:
            'Dekripsi gagal: ${e is FormatException ? e.message : e.toString()}',
      );
    }

    // Eksekusi pemulihan snapshot menggunakan BackupRestoreService
    return _plainBackupService.restoreFromJson(plainJson);
  }

  /// Dapatkan daftar file cadangan terenkripsi yang ada di penyimpanan lokal.
  Future<List<File>> listEncryptedBackups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir =
          Directory(p.join(dir.path, 'money_flow_encrypted_backups'));
      if (!await backupDir.exists()) return [];

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.enc.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files;
    } catch (_) {
      return [];
    }
  }
}

final encryptedBackupServiceProvider = Provider<EncryptedBackupService>((ref) {
  final plainService = ref.watch(backupRestoreServiceProvider);
  return EncryptedBackupService(plainService);
});
