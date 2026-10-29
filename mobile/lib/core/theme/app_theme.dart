import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App color palette — Finsave Reference & Taste-Skill (Single Light Palette).
/// Bersih, fungsional, berwibawa dengan aksen tunggal Deep Teal Green (#0F6B5F)
/// dan tombol primer charcoal (#18181B).
class AppColors {
  AppColors._();

  // Brand / Single Accent Hue (Finsave Deep Teal)
  static const Color brandTeal = Color(0xFF0F6B5F);
  static const Color brandTealDark = Color(0xFF0B5249);
  static const Color brandTealWash = Color(0xFFE8F3F1);

  // Primary Buttons & Heavy Chrome (Charcoal / Near-black)
  static const Color primary = Color(0xFF18181B);
  static const Color primaryLight = Color(0xFF27272A);
  static const Color primaryDark = Color(0xFF09090B);

  // Data / Accent hue
  static const Color dataAccent = Color(0xFF0F6B5F);

  // Single Light Backgrounds & Surfaces (Clean white and subtle off-white ground)
  static const Color lightGround = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceRaised = Color(0xFFF3F4F6);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightBorderStrong = Color(0xFFD1D5DB);
  static const Color lightRule = Color(0xFFF1F5F9);

  // Compatibility aliases
  static const Color background = lightGround;
  static const Color surface = lightSurface;
  static const Color surfaceLight = lightSurfaceRaised;
  static const Color surfaceVariant = lightSurfaceRaised;
  static const Color card = lightSurface;
  static const Color border = lightBorder;
  static const Color divider = lightRule;

  // Text tiers (High contrast, WCAG AAA/AA compliant)
  static const Color textPrimary = Color(0xFF111827); // Charcoal near-black
  static const Color textSecondary = Color(0xFF6B7280); // Neutral gray
  static const Color textMuted = Color(0xFF9CA3AF); // Muted gray

  static const Color lightTextPrimary = textPrimary;
  static const Color lightTextSecondary = textSecondary;
  static const Color lightTextMuted = textMuted;

  // Financial Semantic Colors (Terpisah jelas dari Brand Teal #0F6B5F)
  // Pemasukan: Emerald green segar (#16A34A)
  static const Color income = Color(0xFF16A34A);
  static const Color incomeBg = Color(0xFFDCFCE7);
  static const Color incomeInk = Color(0xFF14532D);

  // Pengeluaran: Soft deep red (#DC2626)
  static const Color expense = Color(0xFFDC2626);
  static const Color expenseBg = Color(0xFFFEE2E2);
  static const Color expenseInk = Color(0xFF7F1D1D);

  // Transfer: Slate blue-gray (#475569)
  static const Color transfer = Color(0xFF475569);
  static const Color transferBg = Color(0xFFF1F5F9);
  static const Color transferInk = Color(0xFF1E293B);

  // Warning & Notifikasi
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningInk = Color(0xFF78350F);

  static const Color orange = Color(0xFFEA580C);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF16A34A);
  static const Color refund = Color(0xFFD97706);
  static const Color refundBg = Color(0xFFFEF3C7);

  // Chart category neutrals (Taste-Skill §6.4 & §13)
  static const List<Color> chartNeutrals = [
    Color(0xFF475569), // slate
    Color(0xFF78716C), // stone
    Color(0xFF6B7280), // gray
    Color(0xFF64748B), // slate-500
    Color(0xFF9CA3AF), // gray-400
    Color(0xFFA8A29E), // stone-400
    Color(0xFFD1D5DB), // gray-300
  ];
}

/// Token tema semantik terpusat (ThemeExtension) — Finsave Design System.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final Color ground;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color rule;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color brand;
  final Color brandWash;
  final Color income;
  final Color incomeBg;
  final Color incomeInk;
  final Color expense;
  final Color expenseBg;
  final Color expenseInk;
  final Color transfer;
  final Color transferBg;
  final Color transferInk;
  final Color warning;
  final Color warningBg;
  final Color dataHue;
  final Color primaryButtonBg;
  final Color primaryButtonInk;
  final Color secondaryButtonBg;
  final Color secondaryButtonInk;
  final Color pillNeutralBg;
  final Color pillNeutralInk;
  final double radiusCard;
  final double radiusControl;
  final double radiusChip;
  final double gap;
  final double pad;

  // Spacing scale
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;

  const AppThemeTokens({
    required this.ground,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.rule,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brand,
    required this.brandWash,
    required this.income,
    required this.incomeBg,
    required this.incomeInk,
    required this.expense,
    required this.expenseBg,
    required this.expenseInk,
    required this.transfer,
    required this.transferBg,
    required this.transferInk,
    required this.warning,
    required this.warningBg,
    required this.dataHue,
    required this.primaryButtonBg,
    required this.primaryButtonInk,
    required this.secondaryButtonBg,
    required this.secondaryButtonInk,
    required this.pillNeutralBg,
    required this.pillNeutralInk,
    this.radiusCard = 12.0,
    this.radiusControl = 10.0,
    this.radiusChip = 6.0,
    this.gap = 12.0,
    this.pad = 14.0,
  });

  Color get borderHairline => rule;

  static AppThemeTokens of(BuildContext context) {
    return Theme.of(context).extension<AppThemeTokens>() ?? light;
  }

  static const light = AppThemeTokens(
    ground: AppColors.lightGround,
    surface: AppColors.lightSurface,
    surfaceRaised: AppColors.lightSurfaceRaised,
    border: AppColors.lightBorder,
    borderStrong: AppColors.lightBorderStrong,
    rule: AppColors.lightRule,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    brand: AppColors.brandTeal,
    brandWash: AppColors.brandTealWash,
    income: AppColors.income,
    incomeBg: AppColors.incomeBg,
    incomeInk: AppColors.incomeInk,
    expense: AppColors.expense,
    expenseBg: AppColors.expenseBg,
    expenseInk: AppColors.expenseInk,
    transfer: AppColors.transfer,
    transferBg: AppColors.transferBg,
    transferInk: AppColors.transferInk,
    warning: AppColors.warning,
    warningBg: AppColors.warningBg,
    dataHue: AppColors.dataAccent,
    primaryButtonBg: AppColors.primary,
    primaryButtonInk: Colors.white,
    secondaryButtonBg: Colors.white,
    secondaryButtonInk: AppColors.textPrimary,
    pillNeutralBg: Color(0xFFF1F5F9),
    pillNeutralInk: Color(0xFF334155),
    radiusCard: 12.0,
    radiusControl: 10.0,
    radiusChip: 6.0,
    gap: 12.0,
    pad: 14.0,
  );

  @override
  ThemeExtension<AppThemeTokens> copyWith({
    Color? ground,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? rule,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? brand,
    Color? brandWash,
    Color? income,
    Color? incomeBg,
    Color? incomeInk,
    Color? expense,
    Color? expenseBg,
    Color? expenseInk,
    Color? transfer,
    Color? transferBg,
    Color? transferInk,
    Color? warning,
    Color? warningBg,
    Color? dataHue,
    Color? primaryButtonBg,
    Color? primaryButtonInk,
    Color? secondaryButtonBg,
    Color? secondaryButtonInk,
    Color? pillNeutralBg,
    Color? pillNeutralInk,
    double? radiusCard,
    double? radiusControl,
    double? radiusChip,
    double? gap,
    double? pad,
  }) {
    return AppThemeTokens(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      rule: rule ?? this.rule,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brand: brand ?? this.brand,
      brandWash: brandWash ?? this.brandWash,
      income: income ?? this.income,
      incomeBg: incomeBg ?? this.incomeBg,
      incomeInk: incomeInk ?? this.incomeInk,
      expense: expense ?? this.expense,
      expenseBg: expenseBg ?? this.expenseBg,
      expenseInk: expenseInk ?? this.expenseInk,
      transfer: transfer ?? this.transfer,
      transferBg: transferBg ?? this.transferBg,
      transferInk: transferInk ?? this.transferInk,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      dataHue: dataHue ?? this.dataHue,
      primaryButtonBg: primaryButtonBg ?? this.primaryButtonBg,
      primaryButtonInk: primaryButtonInk ?? this.primaryButtonInk,
      secondaryButtonBg: secondaryButtonBg ?? this.secondaryButtonBg,
      secondaryButtonInk: secondaryButtonInk ?? this.secondaryButtonInk,
      pillNeutralBg: pillNeutralBg ?? this.pillNeutralBg,
      pillNeutralInk: pillNeutralInk ?? this.pillNeutralInk,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusControl: radiusControl ?? this.radiusControl,
      radiusChip: radiusChip ?? this.radiusChip,
      gap: gap ?? this.gap,
      pad: pad ?? this.pad,
    );
  }

  @override
  ThemeExtension<AppThemeTokens> lerp(
      covariant ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandWash: Color.lerp(brandWash, other.brandWash, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeBg: Color.lerp(incomeBg, other.incomeBg, t)!,
      incomeInk: Color.lerp(incomeInk, other.incomeInk, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseBg: Color.lerp(expenseBg, other.expenseBg, t)!,
      expenseInk: Color.lerp(expenseInk, other.expenseInk, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      transferBg: Color.lerp(transferBg, other.transferBg, t)!,
      transferInk: Color.lerp(transferInk, other.transferInk, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      dataHue: Color.lerp(dataHue, other.dataHue, t)!,
      primaryButtonBg: Color.lerp(primaryButtonBg, other.primaryButtonBg, t)!,
      primaryButtonInk:
          Color.lerp(primaryButtonInk, other.primaryButtonInk, t)!,
      secondaryButtonBg:
          Color.lerp(secondaryButtonBg, other.secondaryButtonBg, t)!,
      secondaryButtonInk:
          Color.lerp(secondaryButtonInk, other.secondaryButtonInk, t)!,
      pillNeutralBg: Color.lerp(pillNeutralBg, other.pillNeutralBg, t)!,
      pillNeutralInk: Color.lerp(pillNeutralInk, other.pillNeutralInk, t)!,
      radiusCard: radiusCard,
      radiusControl: radiusControl,
      radiusChip: radiusChip,
      gap: gap,
      pad: pad,
    );
  }
}

/// Extension helper di BuildContext untuk akses instan token tema
extension AppThemeContextExtension on BuildContext {
  AppThemeTokens get tokens => AppThemeTokens.of(this);
}

/// Tema aplikasi tunggal (Light Theme only — Finsave Reference).
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: const [AppThemeTokens.light],
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.brandTeal,
        onSecondary: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.textPrimary,
        error: AppColors.expense,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.lightGround,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightGround,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brandTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.expense),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.lightBorder),
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandTeal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.brandTeal,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightRule,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.textPrimary),
        displayMedium: TextStyle(color: AppColors.textPrimary),
        displaySmall: TextStyle(color: AppColors.textPrimary),
        headlineLarge: TextStyle(
            fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineMedium: TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        headlineSmall: TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge: TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleSmall: TextStyle(
            fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
        bodySmall: TextStyle(color: AppColors.textMuted),
        labelLarge: TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        labelMedium: TextStyle(color: AppColors.textSecondary),
        labelSmall: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
