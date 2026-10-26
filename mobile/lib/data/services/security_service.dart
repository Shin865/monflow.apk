import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:money_flow/core/database/database.dart';

/// Status autentikasi PIN
class PinAuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final bool isLockedOut;
  final int? remainingLockoutSeconds;

  const PinAuthResult({
    required this.isSuccess,
    this.errorMessage,
    this.isLockedOut = false,
    this.remainingLockoutSeconds,
  });
}

/// Service untuk keamanan PIN, Biometrik, dan lifecycle aplikasi.
///
/// Kebijakan Keamanan:
/// - PIN TIDAK PERNAH disimpan dalam bentuk teks biasa.
/// - Salt acak 16 byte (kriptografis) dibuat per pengguna dan disimpan bersama hash.
/// - Menggunakan KDF berbasis HMAC-SHA256 dengan 10.000 iterasi.
/// - Pembatasan percobaan: setelah 5 kali gagal berturut-turut, sistem dikunci selama 30 detik.
/// - PIN adalah kunci akses aplikasi (access lock), BUKAN enkripsi database SQLite.
class SecurityService extends ChangeNotifier {
  final AppDatabase _db;
  final LocalAuthentication _localAuth;

  static const String _keyPinHash = 'security_pin_hash';
  static const String _keyPinSalt = 'security_pin_salt';
  static const String _keyPinEnabled = 'security_pin_enabled';
  static const String _keyBiometricEnabled = 'security_biometric_enabled';
  static const String _keyLockOnBackground = 'security_lock_on_background';
  static const String _keyFailedAttempts = 'security_failed_attempts';
  static const String _keyLockoutUntil = 'security_lockout_until';

  static const int maxFailedAttempts = 5;
  static const int lockoutSeconds = 30;

  bool _isAppLocked = false;
  bool _isInitialized = false;
  bool _isCriticalTransactionActive = false;

  bool get isAppLocked => _isAppLocked;
  bool get isInitialized => _isInitialized;
  bool get isCriticalTransactionActive => _isCriticalTransactionActive;

  SecurityService(this._db, [LocalAuthentication? localAuth])
      : _localAuth = localAuth ?? LocalAuthentication();

  /// Inisialisasi status keamanan saat startup aplikasi
  Future<void> initSecurityState() async {
    final pinEnabled = await isPinEnabled();
    if (pinEnabled) {
      _isAppLocked = true;
    } else {
      _isAppLocked = false;
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Tandai transaksi database kritis sedang berjalan (jangan kunci layar di tengah proses).
  void setCriticalTransactionActive(bool active) {
    _isCriticalTransactionActive = active;
  }

  /// Cek apakah perlindungan PIN aktif.
  Future<bool> isPinEnabled() async {
    final setting = await _getSetting(_keyPinEnabled);
    return setting?.value == 'true';
  }

  /// Cek apakah biometrik aktif.
  Future<bool> isBiometricEnabled() async {
    final setting = await _getSetting(_keyBiometricEnabled);
    return setting?.value == 'true';
  }

  /// Cek apakah kunci saat latar belakang aktif.
  Future<bool> isLockOnBackgroundEnabled() async {
    final setting = await _getSetting(_keyLockOnBackground);
    return setting?.value != 'false'; // default true jika PIN aktif
  }

  /// Kunci aplikasi secara manual atau saat lifecycle latar belakang.
  void lockApp() {
    if (_isCriticalTransactionActive) {
      // Abaikan kunci layar jika ada transaksi database penting yang belum selesai
      return;
    }
    _isAppLocked = true;
    notifyListeners();
  }

  /// Buka kunci aplikasi.
  void unlockApp() {
    _isAppLocked = false;
    notifyListeners();
  }

  /// Derivasi hash PIN dengan random salt menggunakan PBKDF2 (10,000 iterasi HMAC-SHA256).
  static String hashPin(String pin, Uint8List salt) {
    var key = utf8.encode(pin);
    var hmac = Hmac(sha256, key);
    var current = hmac.convert(salt).bytes;

    for (var i = 1; i < 10000; i++) {
      current = Hmac(sha256, key).convert(current).bytes;
    }

    return base64Encode(current);
  }

  /// Buat salt kriptografis acak 16 byte.
  static Uint8List generateSalt() {
    final rand = Random.secure();
    final salt = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      salt[i] = rand.nextInt(256);
    }
    return salt;
  }

  /// Atur PIN baru atau ubah PIN.
  Future<void> setupPin(String pin) async {
    if (pin.length < 4 || pin.length > 8) {
      throw ArgumentError('PIN harus terdiri dari 4 hingga 8 digit angka.');
    }

    final salt = generateSalt();
    final hash = hashPin(pin, salt);

    await _db.transaction(() async {
      await _setSetting(_keyPinHash, hash, 'Hash PIN pengguna terenkripsi KDF');
      await _setSetting(
          _keyPinSalt, base64Encode(salt), 'Salt unik per pengguna');
      await _setSetting(_keyPinEnabled, 'true', 'Status aktifasi PIN');
      await _setSetting(
          _keyFailedAttempts, '0', 'Jumlah percobaan gagal berturut-turut');
      await _setSetting(_keyLockoutUntil, '', 'Waktu pembukaan blokir');
    });

    _isAppLocked = false;
    notifyListeners();
  }

  /// Nonaktifkan PIN.
  Future<void> disablePin() async {
    await _db.transaction(() async {
      await _setSetting(_keyPinEnabled, 'false', 'Status aktifasi PIN');
      await _setSetting(
          _keyBiometricEnabled, 'false', 'Status aktifasi Biometrik');
      await _setSetting(_keyFailedAttempts, '0', 'Jumlah percobaan gagal');
      await _setSetting(_keyLockoutUntil, '', 'Waktu pembukaan blokir');
    });

    _isAppLocked = false;
    notifyListeners();
  }

  /// Verifikasi PIN yang dimasukkan pengguna.
  Future<PinAuthResult> verifyPin(String enteredPin) async {
    // 1. Cek lockout status
    final lockoutUntilStr = (await _getSetting(_keyLockoutUntil))?.value;
    if (lockoutUntilStr != null && lockoutUntilStr.isNotEmpty) {
      final lockoutUntil = DateTime.tryParse(lockoutUntilStr);
      if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
        final diffSeconds =
            lockoutUntil.difference(DateTime.now()).inSeconds + 1;
        return PinAuthResult(
          isSuccess: false,
          isLockedOut: true,
          remainingLockoutSeconds: diffSeconds,
          errorMessage:
              'Terlalu banyak percobaan gagal. Silakan coba lagi dalam $diffSeconds detik.',
        );
      }
    }

    final storedHash = (await _getSetting(_keyPinHash))?.value;
    final storedSaltStr = (await _getSetting(_keyPinSalt))?.value;

    if (storedHash == null || storedSaltStr == null) {
      return const PinAuthResult(
        isSuccess: false,
        errorMessage: 'PIN belum dikonfigurasi.',
      );
    }

    final salt = base64Decode(storedSaltStr);
    final calculatedHash = hashPin(enteredPin, salt);

    if (calculatedHash == storedHash) {
      // Reset failed attempts
      await _setSetting(_keyFailedAttempts, '0', 'Jumlah percobaan gagal');
      await _setSetting(_keyLockoutUntil, '', 'Waktu pembukaan blokir');
      unlockApp();
      return const PinAuthResult(isSuccess: true);
    } else {
      // Tingkatkan hitungan gagal
      final currentAttemptsStr =
          (await _getSetting(_keyFailedAttempts))?.value ?? '0';
      final attempts = (int.tryParse(currentAttemptsStr) ?? 0) + 1;
      await _setSetting(
          _keyFailedAttempts, attempts.toString(), 'Jumlah percobaan gagal');

      if (attempts >= maxFailedAttempts) {
        final lockoutTime =
            DateTime.now().add(const Duration(seconds: lockoutSeconds));
        await _setSetting(_keyLockoutUntil, lockoutTime.toIso8601String(),
            'Waktu pembukaan blokir');
        return const PinAuthResult(
          isSuccess: false,
          isLockedOut: true,
          remainingLockoutSeconds: lockoutSeconds,
          errorMessage:
              'Batas percobaan terlampaui. Aplikasi dikunci selama 30 detik.',
        );
      } else {
        final remaining = maxFailedAttempts - attempts;
        return PinAuthResult(
          isSuccess: false,
          errorMessage: 'PIN salah. Sisa kesempatan: $remaining kali.',
        );
      }
    }
  }

  /// Cek apakah perangkat mendukung autentikasi biometrik.
  Future<bool> canAuthenticateBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Otentikasi dengan biometrik. Fallback otomatis ke PIN bila gagal/dibatalkan.
  Future<bool> authenticateBiometric(
      {String reason = 'Buka kunci Money Flow'}) async {
    try {
      final canAuth = await canAuthenticateBiometric();
      if (!canAuth) return false;

      final success = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (success) {
        unlockApp();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Atur konfigurasi biometrik.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _setSetting(
      _keyBiometricEnabled,
      enabled ? 'true' : 'false',
      'Status otentikasi biometrik',
    );
    notifyListeners();
  }

  /// Atur konfigurasi kunci saat aplikasi masuk latar belakang.
  Future<void> setLockOnBackgroundEnabled(bool enabled) async {
    await _setSetting(
      _keyLockOnBackground,
      enabled ? 'true' : 'false',
      'Kunci aplikasi saat minimize/background',
    );
    notifyListeners();
  }

  // Helper SQLite Settings
  Future<Setting?> _getSetting(String key) async {
    return (_db.select(_db.settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
  }

  Future<void> _setSetting(String key, String value, String description) async {
    final existing = await _getSetting(key);
    if (existing == null) {
      await _db.into(_db.settings).insert(
            SettingsCompanion.insert(
              key: key,
              value: Value(value),
              description: Value(description),
            ),
          );
    } else {
      await (_db.update(_db.settings)..where((s) => s.key.equals(key))).write(
        SettingsCompanion(
          value: Value(value),
          description: Value(description),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}

final securityServiceProvider = ChangeNotifierProvider<SecurityService>((ref) {
  final db = ref.watch(databaseProvider);
  return SecurityService(db);
});
