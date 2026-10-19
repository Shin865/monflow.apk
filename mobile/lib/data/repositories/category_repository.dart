import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_flow/core/database/database.dart';

/// Exception ketika kategori tidak bisa dihapus karena sudah dipakai transaksi.
class CategoryInUseException implements Exception {
  final String message;
  const CategoryInUseException(
      [this.message =
          'Kategori tidak dapat dihapus karena sudah digunakan dalam transaksi. Nonaktifkan kategori ini sebagai alternatif.']);

  @override
  String toString() => message;
}

/// Repository untuk kategori transaksi.
class CategoryRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  CategoryRepository(this._db);

  /// Ambil semua kategori aktif.
  Future<List<Category>> getActiveCategories() {
    return (_db.select(_db.categories)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([
            (c) => OrderingTerm(expression: c.type),
            (c) => OrderingTerm(expression: c.name),
          ]))
        .get();
  }

  /// Ambil semua kategori (aktif & nonaktif) untuk manajemen.
  Future<List<Category>> getAllCategories() {
    return (_db.select(_db.categories)
          ..orderBy([
            (c) => OrderingTerm(expression: c.type),
            (c) => OrderingTerm(expression: c.name),
          ]))
        .get();
  }

  /// Ambil kategori berdasarkan tipe.
  Future<List<Category>> getByType(CategoryType type,
      {bool onlyActive = true}) {
    final query = _db.select(_db.categories)
      ..where((c) {
        final typeCond = c.type.equalsValue(type);
        return onlyActive ? (typeCond & c.isActive.equals(true)) : typeCond;
      })
      ..orderBy([(c) => OrderingTerm(expression: c.name)]);
    return query.get();
  }

  /// Ambil satu kategori berdasarkan ID.
  Future<Category?> getById(int id) {
    return (_db.select(_db.categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Stream kategori berdasarkan tipe (aktif saja).
  Stream<List<Category>> watchByType(CategoryType type) {
    return (_db.select(_db.categories)
          ..where((c) => c.isActive.equals(true) & c.type.equalsValue(type))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
  }

  /// Stream semua kategori untuk layar kelola kategori.
  Stream<List<Category>> watchAllCategories() {
    return (_db.select(_db.categories)
          ..orderBy([
            (c) => OrderingTerm(expression: c.type),
            (c) => OrderingTerm(expression: c.name),
          ]))
        .watch();
  }

  /// Stream semua kategori grouped berdasarkan tipe.
  Stream<Map<CategoryType, List<Category>>> watchGrouped(
      {bool onlyActive = true}) {
    final query = _db.select(_db.categories);
    if (onlyActive) {
      query.where((c) => c.isActive.equals(true));
    }
    query.orderBy([(c) => OrderingTerm(expression: c.name)]);

    return query.watch().map((categories) {
      final grouped = <CategoryType, List<Category>>{};
      for (final cat in categories) {
        grouped.putIfAbsent(cat.type, () => []).add(cat);
      }
      return grouped;
    });
  }

  /// Buat kategori baru.
  Future<Category> createCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
    int? parentId,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Nama kategori tidak boleh kosong');
    }

    final id = await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            uuid: Value(_uuid.v4()),
            name: trimmedName,
            type: type,
            icon: Value(icon ?? (type == CategoryType.income ? '💰' : '🏷️')),
            color: Value(
                color ?? (type == CategoryType.income ? '#10B981' : '#EF4444')),
            parentId: Value(parentId),
            isDefault: const Value(false),
            isActive: const Value(true),
          ),
        );

    return (await getById(id))!;
  }

  /// Perbarui kategori yang sudah ada.
  Future<Category> updateCategory(
    int id, {
    String? name,
    CategoryType? type,
    String? icon,
    String? color,
    bool? isActive,
    int? parentId,
  }) async {
    final existing = await getById(id);
    if (existing == null) {
      throw StateError('Kategori tidak ditemukan');
    }

    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isEmpty) {
      throw ArgumentError('Nama kategori tidak boleh kosong');
    }

    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: trimmedName != null ? Value(trimmedName) : const Value.absent(),
        type: type != null ? Value(type) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        parentId: parentId != null ? Value(parentId) : const Value.absent(),
      ),
    );

    return (await getById(id))!;
  }

  /// Aktifkan atau nonaktifkan kategori.
  Future<void> toggleCategoryActive(int id, bool isActive) async {
    final existing = await getById(id);
    if (existing == null) {
      throw StateError('Kategori tidak ditemukan');
    }

    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(isActive: Value(isActive)),
    );
  }

  /// Cek apakah kategori digunakan dalam transaksi.
  Future<bool> isCategoryInUse(int id) async {
    final countExp = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..where(_db.transactions.categoryId.equals(id))
      ..addColumns([countExp]);

    final result = await query.map((row) => row.read(countExp)).getSingle();
    return (result ?? 0) > 0;
  }

  /// Hapus kategori secara aman.
  /// Jika sudah digunakan transaksi lama, lempar [CategoryInUseException] untuk mencegah kerusakan relasi.
  Future<void> deleteCategory(int id) async {
    final inUse = await isCategoryInUse(id);
    if (inUse) {
      throw const CategoryInUseException();
    }

    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }
}

/// Provider untuk CategoryRepository.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
});
