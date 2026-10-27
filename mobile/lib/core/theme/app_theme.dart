import 'package:flutter/material.dart';

/// App color palette — Achromatic Ledger design system (SKILL.md / app-screens.md).
/// Tenang, tepercaya, berorientasi data tanpa ornamen dekoratif atau gradasi slop.
class AppColors {
  AppColors._();

  // Primary palette (Achromatic Ledger: Chrome bebas warna mencolok)
  // Tombol aksi utama menggunakan near-black di light mode dan white di dark mode.
  static const Color primary = Color(0xFF141414); // Near-black primary
  static const Color primaryLight = Color(0xFF262626);
  static const Color primaryDark = Color(0xFF000000);

  // Data / Accent hue (Satu rona aksen untuk elemen data utama, ~1% piksel)
  static const Color dataAccent = Color(0xFF1D5FBF); // Ledger blue accent

  // Neutral Backgrounds & Surfaces — Dark Mode (True neutral darks, no slate, no navy)
  static const Color darkGround = Color(0xFF111111);
  static const Color darkSurface = Color(0xFF171719);
  static const Color darkSurfaceRaised = Color(0xFF222224);
  static const Color darkBorder = Color(0xFF262628);
  static const Color darkRule = Color(0xFF1F1F21);

  // Neutral Backgrounds & Surfaces — Light Mode (Clean off-white ground)
  static const Color lightGround = Color(0xFFF8F8F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceRaised = Color(0xFFF0F0F2);
  static const Color lightBorder = Color(0xFFE6E6E6);
  static const Color lightRule = Color(0xFFF0F0F0);

  // Backward-compatibility defaults (defaulted to dark surface as app default)
  static const Color background = darkGround;
  static const Color surface = darkSurface;
  static const Color surfaceLight = darkSurfaceRaised;
  static const Color card = darkSurface;
  static const Color border = darkBorder;
  static const Color divider = darkRule;

  // Text tiers (High contrast, minimum 4.5:1 ratio)
  static const Color textPrimary = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFFB4B4B4);
  static const Color textMuted = Color(0xFF888888);

  // Light text tiers
  static const Color lightTextPrimary = Color(0xFF0A0A0A);
  static const Color lightTextSecondary = Color(0xFF5F6368);
  static const Color lightTextMuted = Color(0xFF8C8C8C);

  // Quiet Money Polarity (SKILL.md §9.2 & §9.3 & §13)
  // Pemasukan: Hijau berwibawa dengan tanda '+'
  // Pengeluaran: Teks normal atau quiet negative
  static const Color income = Color(0xFF2E7D32); // Emerald 5.2:1
  static const Color incomeDark = Color(0xFF3FC07A); // Mint pada latar gelap
  static const Color incomeBg = Color(0xFFDCFAE5);
  static const Color incomeBgDark = Color(0xFF172A1D);

  static const Color expense = Color(0xFFC4242A); // Quiet red
  static const Color expenseDark = Color(0xFFE5566F);
  static const Color expenseBg = Color(0xFFFFEDEA);
  static const Color expenseBgDark = Color(0xFF2C1A20);

  static const Color transfer = Color(0xFF1D5FBF); // Data hue
  static const Color transferDark = Color(0xFF60A5FA);
  static const Color transferBg = Color(0xFFEFF6FF);
  static const Color transferBgDark = Color(0xFF1E293B);

  static const Color warning = Color(0xFF92400E);
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBgDark = Color(0xFF2E200C);

  static const Color refund = Color(0xFF92400E);
  static const Color refundBg = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFC4242A);
  static const Color success = Color(0xFF2E7D32);
}

/// Token tema semantik terpusat (ThemeExtension) sesuai SKILL.md achromatic-ledger.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final Color ground;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color rule;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color income;
  final Color incomeBg;
  final Color expense;
  final Color expenseBg;
  final Color transfer;
  final Color transferBg;
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

  const AppThemeTokens({
    required this.ground,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.rule,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.income,
    required this.incomeBg,
    required this.expense,
    required this.expenseBg,
    required this.transfer,
    required this.transferBg,
    required this.warning,
    required this.warningBg,
    required this.dataHue,
    required this.primaryButtonBg,
    required this.primaryButtonInk,
    required this.secondaryButtonBg,
    required this.secondaryButtonInk,
    required this.pillNeutralBg,
    required this.pillNeutralInk,
    this.radiusCard = 10.0,
    this.radiusControl = 8.0,
    this.radiusChip = 6.0,
    this.gap = 12.0,
    this.pad = 16.0,
  });

  /// Alias untuk rule / hairline divider
  Color get borderHairline => rule;

  static AppThemeTokens of(BuildContext context) {
    return Theme.of(context).extension<AppThemeTokens>() ?? dark;
  }

  static const light = AppThemeTokens(
    ground: AppColors.lightGround,
    surface: AppColors.lightSurface,
    surfaceRaised: AppColors.lightSurfaceRaised,
    border: AppColors.lightBorder,
    rule: AppColors.lightRule,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    income: AppColors.income,
    incomeBg: AppColors.incomeBg,
    expense: AppColors.expense,
    expenseBg: AppColors.expenseBg,
    transfer: AppColors.transfer,
    transferBg: AppColors.transferBg,
    warning: AppColors.warning,
    warningBg: AppColors.warningBg,
    dataHue: AppColors.dataAccent,
    primaryButtonBg: Color(0xFF141414), // Near-black
    primaryButtonInk: Colors.white,
    secondaryButtonBg: Color(0xFFEEEEEE),
    secondaryButtonInk: Color(0xFF141414),
    pillNeutralBg: Color(0xFFEEEEEE),
    pillNeutralInk: Color(0xFF3D3D3D),
    radiusCard: 10.0,
    radiusControl: 8.0,
    radiusChip: 6.0,
    gap: 12.0,
    pad: 16.0,
  );

  static const dark = AppThemeTokens(
    ground: AppColors.darkGround,
    surface: AppColors.darkSurface,
    surfaceRaised: AppColors.darkSurfaceRaised,
    border: AppColors.darkBorder,
    rule: AppColors.darkRule,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    income: AppColors.incomeDark,
    incomeBg: AppColors.incomeBgDark,
    expense: AppColors.expenseDark,
    expenseBg: AppColors.expenseBgDark,
    transfer: AppColors.transferDark,
    transferBg: AppColors.transferBgDark,
    warning: AppColors.warningDark,
    warningBg: AppColors.warningBgDark,
    dataHue: Color(0xFF60A5FA),
    primaryButtonBg: Colors.white, // Inverted on dark
    primaryButtonInk: Color(0xFF0A0A0A),
    secondaryButtonBg: Color(0xFF222224),
    secondaryButtonInk: Colors.white,
    pillNeutralBg: Color(0xFF222224),
    pillNeutralInk: Color(0xFFD4D4D4),
    radiusCard: 10.0,
    radiusControl: 8.0,
    radiusChip: 6.0,
    gap: 12.0,
    pad: 16.0,
  );

  @override
  ThemeExtension<AppThemeTokens> copyWith({
    Color? ground,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? rule,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? income,
    Color? incomeBg,
    Color? expense,
    Color? expenseBg,
    Color? transfer,
    Color? transferBg,
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
      rule: rule ?? this.rule,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      income: income ?? this.income,
      incomeBg: incomeBg ?? this.incomeBg,
      expense: expense ?? this.expense,
      expenseBg: expenseBg ?? this.expenseBg,
      transfer: transfer ?? this.transfer,
      transferBg: transferBg ?? this.transferBg,
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
      rule: Color.lerp(rule, other.rule, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeBg: Color.lerp(incomeBg, other.incomeBg, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseBg: Color.lerp(expenseBg, other.expenseBg, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      transferBg: Color.lerp(transferBg, other.transferBg, t)!,
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

/// App typography and theme — Achromatic Ledger.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: const [AppThemeTokens.dark],
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Color(0xFF0A0A0A),
        secondary: Color(0xFF262626),
        onSecondary: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.textPrimary,
        error: AppColors.expenseDark,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.darkGround,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkGround,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0A0A0A),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
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
          foregroundColor: Colors.white,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0A0A0A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkGround,
        selectedItemColor: Colors.white,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkRule,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceRaised,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.darkSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        displayMedium:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        displaySmall:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        headlineLarge:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        headlineMedium:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        headlineSmall:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        titleLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        titleMedium: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        titleSmall: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary),
        bodyLarge: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        bodyMedium:
            TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
        bodySmall: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted),
        labelLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        labelMedium:
            TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
        labelSmall: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: const [AppThemeTokens.light],
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF141414), // Near-black primary
        onPrimary: Colors.white,
        secondary: Color(0xFFEEEEEE),
        onSecondary: Color(0xFF141414),
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.expense,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.lightGround,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightGround,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF141414), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle:
            const TextStyle(color: AppColors.lightTextMuted, fontSize: 14),
        labelStyle:
            const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF141414), // Near black
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
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
          foregroundColor: const Color(0xFF141414),
          side: const BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF141414),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF141414),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightGround,
        selectedItemColor: Color(0xFF141414),
        unselectedItemColor: AppColors.lightTextMuted,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightRule,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightSurfaceRaised,
        contentTextStyle: const TextStyle(color: AppColors.lightTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.lightSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.lightTextPrimary),
        displayMedium: TextStyle(color: AppColors.lightTextPrimary),
        displaySmall: TextStyle(color: AppColors.lightTextPrimary),
        headlineLarge: TextStyle(color: AppColors.lightTextPrimary),
        headlineMedium: TextStyle(color: AppColors.lightTextPrimary),
        headlineSmall: TextStyle(color: AppColors.lightTextPrimary),
        titleLarge: TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        titleMedium: TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        titleSmall: TextStyle(
            fontWeight: FontWeight.w500, color: AppColors.lightTextPrimary),
        bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(color: AppColors.lightTextSecondary),
        bodySmall: TextStyle(color: AppColors.lightTextMuted),
        labelLarge: TextStyle(
            fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        labelMedium: TextStyle(color: AppColors.lightTextSecondary),
        labelSmall: TextStyle(color: AppColors.lightTextMuted),
      ),
    );
  }
}
