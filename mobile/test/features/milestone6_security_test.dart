import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/services/security_service.dart';

void main() {
  late AppDatabase db;
  late SecurityService securityService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    securityService = SecurityService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 6 — Security & PIN Protection Tests', () {
    test('PIN setup and successful verification with PBKDF2 hash', () async {
      expect(await securityService.isPinEnabled(), isFalse);

      await securityService.setupPin('123456');
      expect(await securityService.isPinEnabled(), isTrue);

      final result = await securityService.verifyPin('123456');
      expect(result.isSuccess, isTrue);
      expect(securityService.isAppLocked, isFalse);
    });

    test(
        'Random salts ensure identical PINs produce completely different hashes',
        () {
      final salt1 = SecurityService.generateSalt();
      final salt2 = SecurityService.generateSalt();

      expect(salt1, isNot(equals(salt2)));

      final hash1 = SecurityService.hashPin('1234', salt1);
      final hash2 = SecurityService.hashPin('1234', salt2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('Wrong PIN fails verification and tracks remaining attempts',
        () async {
      await securityService.setupPin('8888');

      final failResult = await securityService.verifyPin('1111');
      expect(failResult.isSuccess, isFalse);
      expect(failResult.errorMessage, contains('Sisa kesempatan: 4 kali'));
    });

    test('5 consecutive failed attempts triggers 30-second lockout', () async {
      await securityService.setupPin('9999');

      for (var i = 1; i <= 4; i++) {
        final res = await securityService.verifyPin('0000');
        expect(res.isSuccess, isFalse);
        expect(res.isLockedOut, isFalse);
      }

      // 5th attempt
      final lockoutRes = await securityService.verifyPin('0000');
      expect(lockoutRes.isSuccess, isFalse);
      expect(lockoutRes.isLockedOut, isTrue);
      expect(lockoutRes.remainingLockoutSeconds, greaterThan(0));
      expect(lockoutRes.errorMessage, contains('Aplikasi dikunci'));

      // Subsequent attempt while locked out is rejected immediately
      final blockedRes = await securityService.verifyPin('9999');
      expect(blockedRes.isSuccess, isFalse);
      expect(blockedRes.isLockedOut, isTrue);
    });

    test('Critical transaction flag prevents locking mid-transaction', () {
      expect(securityService.isAppLocked, isFalse);

      securityService.setCriticalTransactionActive(true);
      securityService.lockApp();
      // Should NOT lock because critical transaction is active
      expect(securityService.isAppLocked, isFalse);

      securityService.setCriticalTransactionActive(false);
      securityService.lockApp();
      // Now it should lock
      expect(securityService.isAppLocked, isTrue);
    });

    test('Disabling PIN removes protection and resets lockout state', () async {
      await securityService.setupPin('1234');
      expect(await securityService.isPinEnabled(), isTrue);

      await securityService.disablePin();
      expect(await securityService.isPinEnabled(), isFalse);
    });
  });
}
