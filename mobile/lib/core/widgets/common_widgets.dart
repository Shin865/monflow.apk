/// Reusable UI components for Money Flow — Finsave Reference & Taste-Skill.
library;

import 'package:flutter/material.dart';
import 'package:money_flow/core/theme/app_theme.dart';

/// Card container datar putih dengan border 1px halus (tanpa bayangan/gradient).
class MfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  final double? radius;

  const MfCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.border,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final r = radius ?? tokens.radiusCard;

    final cardWidget = Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(tokens.pad),
      decoration: BoxDecoration(
        color: color ?? tokens.surface,
        borderRadius: BorderRadius.circular(r),
        border: border ?? Border.all(color: tokens.border, width: 1),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(r),
          child: cardWidget,
        ),
      );
    }
    return cardWidget;
  }
}

/// Tombol terstandarisasi Finsave:
/// Primer = Charcoal (#18181B) dengan teks putih
/// Sekunder = Putih dengan border tipis 1px (#E5E7EB)
class MfButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;

  const MfButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.icon,
    this.isLoading = false,
    this.height = 48.0,
    this.width,
  });

  factory MfButton.primary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    double height = 48.0,
    double? width,
  }) {
    return MfButton(
      label: label,
      onPressed: onPressed,
      isPrimary: true,
      icon: icon,
      isLoading: isLoading,
      height: height,
      width: width,
    );
  }

  factory MfButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool isLoading = false,
    double height = 48.0,
    double? width,
  }) {
    return MfButton(
      label: label,
      onPressed: onPressed,
      isPrimary: false,
      icon: icon,
      isLoading: isLoading,
      height: height,
      width: width,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final childWidget = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPrimary ? Colors.white : tokens.textPrimary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isPrimary ? Colors.white : tokens.textPrimary,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : tokens.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          );

    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: Material(
        color: isPrimary ? tokens.primaryButtonBg : tokens.secondaryButtonBg,
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(tokens.radiusControl),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radiusControl),
              border:
                  isPrimary ? null : Border.all(color: tokens.border, width: 1),
            ),
            child: childWidget,
          ),
        ),
      ),
    );
  }
}

/// Header seksi bersih: Judul di kiri + Aksi/Lihat semua di kanan.
class MfSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onViewAll;

  const MfSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onViewAll != null)
            InkWell(
              onTap: onViewAll,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.brand,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Status Pill / Badge tenang (pale tint + dark text of same hue).
class MfPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const MfPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  factory MfPill.positive(BuildContext context, String label) {
    final tokens = context.tokens;
    return MfPill(
      label: label,
      background: tokens.incomeBg,
      foreground: tokens.income,
    );
  }

  factory MfPill.negative(BuildContext context, String label) {
    final tokens = context.tokens;
    return MfPill(
      label: label,
      background: tokens.expenseBg,
      foreground: tokens.expense,
    );
  }

  factory MfPill.warning(BuildContext context, String label) {
    final tokens = context.tokens;
    return MfPill(
      label: label,
      background: tokens.warningBg,
      foreground: tokens.warning,
    );
  }

  factory MfPill.neutral(BuildContext context, String label, {IconData? icon}) {
    final tokens = context.tokens;
    return MfPill(
      label: label,
      background: tokens.pillNeutralBg,
      foreground: tokens.pillNeutralInk,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading indicator minimalis.
class MfLoading extends StatelessWidget {
  final String? message;

  const MfLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.brand,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state yang bersih dan tenang (SKILL.md §11).
class MfEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: tokens.textMuted.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(actionLabel!),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 40),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state widget.
class MfErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const MfErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 32, color: tokens.expense),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: tokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Coba Lagi'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 40),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirmation dialog helper dengan gaya Finsave.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya, Lanjutkan',
  String cancelLabel = 'Batal',
  Color? confirmColor,
}) async {
  final tokens = context.tokens;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(fontSize: 14, color: tokens.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child:
              Text(cancelLabel, style: TextStyle(color: tokens.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: confirmColor ?? tokens.expense,
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
