import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('CategoryRepository — CRUD & Keamanan Relasi', () {
    test('Tambah kategori pemasukan dan pengeluaran baru', () async {
      final incomeCat = await categoryRepo.createCategory(
        name: 'Dividen Saham',
        type: CategoryType.income,
        icon: '📈',
        color: '#10B981',
      );

      final expenseCat = await categoryRepo.createCategory(
        name: 'Langganan SaaS',
        type: CategoryType.expense,
        icon: '💻',
        color: '#EF4444',
      );

      expect(incomeCat.name, 'Dividen Saham');
      expect(incomeCat.type, CategoryType.income);
      expect(incomeCat.isActive, isTrue);

      expect(expenseCat.name, 'Langganan SaaS');
      expect(expenseCat.type, CategoryType.expense);
      expect(expenseCat.isActive, isTrue);

      final allActive = await categoryRepo.getActiveCategories();
      expect(allActive.length, 2);
    });

    test('Validasi: nama kategori tidak boleh kosong', () async {
      expect(
        () => categoryRepo.createCategory(
          name: '   ',
          type: CategoryType.expense,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Ubah kategori yang sudah ada', () async {
      final cat = await categoryRepo.createCategory(
        name: 'Kopi',
        type: CategoryType.expense,
        icon: '☕',
      );

      final updated = await categoryRepo.updateCategory(
        cat.id,
        name: 'Ngopi & Kafe',
        color: '#F97316',
      );

      expect(updated.name, 'Ngopi & Kafe');
      expect(updated.color, '#F97316');
      expect(updated.icon, '☕');
    });

    test('Aktifkan dan nonaktifkan kategori (toggle is_active)', () async {
      final cat = await categoryRepo.createCategory(
        name: 'Kategori Sementara',
        type: CategoryType.expense,
      );

      expect(cat.isActive, isTrue);

      await categoryRepo.toggleCategoryActive(cat.id, false);
      final disabled = await categoryRepo.getById(cat.id);
      expect(disabled?.isActive, isFalse);

      // Kategori nonaktif tidak muncul di getActiveCategories
      final activeList = await categoryRepo.getActiveCategories();
      expect(activeList.any((c) => c.id == cat.id), isFalse);

      // Tetapi muncul di getAllCategories
      final allList = await categoryRepo.getAllCategories();
      expect(allList.any((c) => c.id == cat.id), isTrue);

      // Aktifkan kembali
      await categoryRepo.toggleCategoryActive(cat.id, true);
      final reEnabled = await categoryRepo.getById(cat.id);
      expect(reEnabled?.isActive, isTrue);
    });

    test('Hapus kategori yang BELUM dipakai transaksi → Berhasil', () async {
      final cat = await categoryRepo.createCategory(
        name: 'Kategori Kosong',
        type: CategoryType.expense,
      );

      expect(await categoryRepo.isCategoryInUse(cat.id), isFalse);
      await categoryRepo.deleteCategory(cat.id);

      final deleted = await categoryRepo.getById(cat.id);
      expect(deleted, isNull);
    });

    test(
        'CEGAH HAPUS kategori yang SUDAH digunakan transaksi lama → CategoryInUseException',
        () async {
      // 1. Buat akun dan kategori
      final account = await accountRepo.create(
        name: 'Dompet Utama',
        type: AccountType.cash,
        initialBalance: 1000000,
      );
      final cat = await categoryRepo.createCategory(
        name: 'Makan Siang',
        type: CategoryType.expense,
      );

      // 2. Buat transaksi yang mengacu ke kategori ini
      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: account.id,
        categoryId: cat.id,
        amount: 25000,
        date: DateTime.now(),
      );

      // 3. Verifikasi isCategoryInUse bernilai true
      final inUse = await categoryRepo.isCategoryInUse(cat.id);
      expect(inUse, isTrue);

      // 4. Percobaan hapus kategori HARUS melempar CategoryInUseException
      expect(
        () => categoryRepo.deleteCategory(cat.id),
        throwsA(isA<CategoryInUseException>()),
      );

      // 5. Pastikan kategori dan transaksi masih utuh di database
      final stillExists = await categoryRepo.getById(cat.id);
      expect(stillExists, isNotNull);
      expect(stillExists?.name, 'Makan Siang');

      final txns = await transactionRepo.getTransactions(categoryId: cat.id);
      expect(txns.length, 1);
      expect(txns.first.transaction.amount, 25000);
    });
  });
}
