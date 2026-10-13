import 'package:flutter/material.dart';
import '../theme.dart';

/// Tombol Ikon Kotak Membulat (Sesuai Gaya Visual Gambar Referensi)
/// Digunakan untuk Tombol Back, Search, Filter, dan Aksi Cepat
class AppSquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  const AppSquareIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.onTap,
    this.tooltip,
    this.size = 42,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget button = InkWell(
      onTap: onTap ?? onPressed,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? (isDark ? AppTheme.darkSurfaceSecondary : AppTheme.surface),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: size * 0.48,
            color: iconColor ?? (isDark ? Colors.white : AppTheme.textPrimary),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    // Pastikan touch target minimal 48x48
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Center(child: button),
    );
  }
}

/// Filter Pill Chip (Sesuai Navigasi Filter Referensi)
class AppPillFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? count;

  const AppPillFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isSelected
        ? (isDark ? AppTheme.primaryTealLight : AppTheme.primaryTeal)
        : (isDark ? AppTheme.darkSurfaceSecondary : AppTheme.surface);

    final textColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white70 : AppTheme.textSecondary);

    final borderColor = isSelected
        ? Colors.transparent
        : (isDark ? AppTheme.darkBorder : AppTheme.borderColor);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withAlpha(50) : AppTheme.surfaceSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Header Bagian dengan Judul dan Opsional "Lihat semua"
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final String seeAllText;
  final String? actionTitle;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllText = 'Lihat semua',
    this.actionTitle,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveActionText = actionTitle ?? (onSeeAll != null ? seeAllText : null);
    final effectiveOnAction = onAction ?? onSeeAll;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (effectiveActionText != null)
            GestureDetector(
              onTap: effectiveOnAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Text(
                  effectiveActionText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Status Badge Berbentuk Pill Rapi
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory AppStatusBadge.success(String label, {IconData? icon}) {
    return AppStatusBadge(
      label: label,
      backgroundColor: AppTheme.successContainer,
      textColor: AppTheme.success,
      icon: icon,
    );
  }

  factory AppStatusBadge.warning(String label, {IconData? icon}) {
    return AppStatusBadge(
      label: label,
      backgroundColor: AppTheme.warningContainer,
      textColor: AppTheme.warning,
      icon: icon,
    );
  }

  factory AppStatusBadge.error(String label, {IconData? icon}) {
    return AppStatusBadge(
      label: label,
      backgroundColor: AppTheme.errorContainer,
      textColor: AppTheme.error,
      icon: icon,
    );
  }

  factory AppStatusBadge.neutral(String label, {IconData? icon}) {
    return AppStatusBadge(
      label: label,
      backgroundColor: AppTheme.surfaceSecondary,
      textColor: AppTheme.textSecondary,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
