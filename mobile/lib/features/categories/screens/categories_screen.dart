import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/data/repositories/category_repository.dart';

/// Layar Pengelolaan Kategori Pemasukan & Pengeluaran.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brandTeal,
          labelColor: AppColors.brandTeal,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(
                text: 'Pengeluaran',
                icon: Icon(Icons.arrow_upward_rounded, size: 18)),
            Tab(
                text: 'Pemasukan',
                icon: Icon(Icons.arrow_downward_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CategoryListView(type: CategoryType.expense),
          _CategoryListView(type: CategoryType.income),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final currentType = _tabController.index == 0
              ? CategoryType.expense
              : CategoryType.income;
          _showCreateOrEditDialog(context, type: currentType);
        },
        backgroundColor: AppColors.primaryDark,
        elevation: 2,
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: const Text(
          'Tambah Kategori',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showCreateOrEditDialog(
    BuildContext context, {
    required CategoryType type,
    Category? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryFormSheet(type: type, existing: existing),
    );
  }
}

class _CategoryListView extends ConsumerWidget {
  final CategoryType type;

  const _CategoryListView({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(categoryRepositoryProvider);

    return StreamBuilder<List<Category>>(
      stream: repo.watchAllCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCategories = snapshot.data ?? [];
        final categories = allCategories.where((c) => c.type == type).toList();

        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == CategoryType.income
                      ? Icons.savings_outlined
                      : Icons.shopping_bag_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Belum ada kategori ${type == CategoryType.income ? "pemasukan" : "pengeluaran"}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            return _CategoryItemTile(category: category);
          },
        );
      },
    );
  }
}

class _CategoryItemTile extends ConsumerWidget {
  final Category category;

  const _CategoryItemTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final repo = ref.watch(categoryRepositoryProvider);

    final color = category.color != null
        ? Color(int.parse(category.color!.replaceFirst('#', '0xFF')))
        : (category.type == CategoryType.income
            ? AppColors.income
            : AppColors.expense);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(
          color: category.isActive
              ? AppColors.border
              : AppColors.border.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(category.isActive ? 0.12 : 0.05),
              borderRadius: BorderRadius.circular(tokens.radiusControl),
            ),
            child: Text(
              category.icon ??
                  (category.type == CategoryType.income ? '💰' : '🏷️'),
              style: TextStyle(
                fontSize: 20,
                color: category.isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: category.isActive
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          decoration: category.isActive
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (category.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandTealWash,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Bawaan',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.brandTeal,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  category.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    fontSize: 11,
                    color: category.isActive
                        ? AppColors.income
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.textSecondary),
            tooltip: 'Ubah Kategori',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => _CategoryFormSheet(
                  type: category.type,
                  existing: category,
                ),
              );
            },
          ),
          Switch(
            value: category.isActive,
            activeColor: AppColors.brandTeal,
            onChanged: (val) async {
              await repo.toggleCategoryActive(category.id, val);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.expense),
            tooltip: 'Hapus Kategori',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => _confirmDelete(context, ref, category),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text(
          'Yakin ingin menghapus kategori "${category.name}"?\n\nKategori yang sudah digunakan oleh transaksi tidak dapat dihapus demi menjaga integritas data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final repo = ref.read(categoryRepositoryProvider);
              try {
                await repo.deleteCategory(category.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Kategori "${category.name}" berhasil dihapus.')),
                  );
                }
              } on CategoryInUseException {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (alertContext) => AlertDialog(
                      icon: const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 36),
                      title: const Text('Tidak Dapat Dihapus'),
                      content: Text(
                        'Kategori "${category.name}" sudah digunakan dalam catatan transaksi sebelumnya.\n\nUntuk menjaga keutuhan riwayat transaksi, silakan nonaktifkan (toggle off) kategori ini agar tidak muncul lagi pada pencatatan baru.',
                      ),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.pop(alertContext),
                          child: const Text('Mengerti'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus kategori: $e')),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  final CategoryType type;
  final Category? existing;

  const _CategoryFormSheet({required this.type, this.existing});

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;

  final List<String> _incomeIcons = [
    '💼',
    '💻',
    '🎁',
    '🏦',
    '📈',
    '🏷️',
    '💰',
    '💵',
    '🪙',
    '📥'
  ];
  final List<String> _expenseIcons = [
    '🍔',
    '🚗',
    '🏠',
    '📄',
    '🛍️',
    '🎬',
    '📚',
    '🏥',
    '📊',
    '☕',
    '✈️',
    '🎮',
    '📤'
  ];
  final List<String> _colors = [
    '#EF4444',
    '#F97316',
    '#F59E0B',
    '#10B981',
    '#06B6D4',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#6B7280'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedIcon = widget.existing?.icon ??
        (widget.type == CategoryType.income
            ? _incomeIcons.first
            : _expenseIcons.first);
    _selectedColor = widget.existing?.color ??
        (widget.type == CategoryType.income ? '#10B981' : '#EF4444');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isEdit = widget.existing != null;
    final icons =
        widget.type == CategoryType.income ? _incomeIcons : _expenseIcons;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEdit
                    ? 'Ubah Kategori'
                    : 'Tambah Kategori ${widget.type == CategoryType.income ? "Pemasukan" : "Pengeluaran"}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Kategori',
                  hintText: 'Contoh: Belanja Bulanan',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_selectedIcon,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama kategori wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Pilih Ikon',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: icons.map((icon) {
                  final isSelected = _selectedIcon == icon;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.15)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Pilih Warna',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((hex) {
                  final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  final isSelected = _selectedColor == hex;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.textPrimary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusControl),
                    ),
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final repo = ref.read(categoryRepositoryProvider);
                    if (isEdit) {
                      await repo.updateCategory(
                        widget.existing!.id,
                        name: _nameController.text.trim(),
                        icon: _selectedIcon,
                        color: _selectedColor,
                      );
                    } else {
                      await repo.createCategory(
                        name: _nameController.text.trim(),
                        type: widget.type,
                        icon: _selectedIcon,
                        color: _selectedColor,
                      );
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit
                              ? 'Kategori berhasil diperbarui'
                              : 'Kategori baru berhasil ditambahkan'),
                        ),
                      );
                    }
                  },
                  child: Text(
                    isEdit ? 'Simpan Perubahan' : 'Tambah Kategori',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
