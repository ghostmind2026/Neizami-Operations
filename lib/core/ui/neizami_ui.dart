import 'package:flutter/material.dart';

import '../models/bootstrap_data.dart';

@immutable
class NeizamiUiTokens extends ThemeExtension<NeizamiUiTokens> {
  const NeizamiUiTokens({
    required this.primary,
    required this.primarySoft,
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.text,
    required this.muted,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
    required this.radius,
  });

  factory NeizamiUiTokens.fromBranding(Branding b) {
    return NeizamiUiTokens(
      primary: b.primary,
      primarySoft: Color.alphaBlend(b.primary.withValues(alpha: .09), b.surface),
      background: b.background,
      surface: b.surface,
      surfaceSoft: Color.alphaBlend(b.primary.withValues(alpha: .025), b.background),
      text: b.text,
      muted: b.muted,
      border: b.border,
      success: b.success,
      warning: b.warning,
      danger: b.danger,
      radius: b.radius.clamp(10, 22).toDouble(),
    );
  }

  final Color primary;
  final Color primarySoft;
  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color text;
  final Color muted;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;
  final double radius;

  @override
  NeizamiUiTokens copyWith({
    Color? primary,
    Color? primarySoft,
    Color? background,
    Color? surface,
    Color? surfaceSoft,
    Color? text,
    Color? muted,
    Color? border,
    Color? success,
    Color? warning,
    Color? danger,
    double? radius,
  }) {
    return NeizamiUiTokens(
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      radius: radius ?? this.radius,
    );
  }

  @override
  NeizamiUiTokens lerp(ThemeExtension<NeizamiUiTokens>? other, double t) {
    if (other is! NeizamiUiTokens) return this;
    return NeizamiUiTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      radius: radius + (other.radius - radius) * t,
    );
  }
}

extension NeizamiUiContext on BuildContext {
  NeizamiUiTokens get nz => Theme.of(this).extension<NeizamiUiTokens>()!;
}

class NzSurface extends StatelessWidget {
  const NzSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.radius,
    this.soft = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final bool soft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.nz;
    final r = radius ?? ui.radius;
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: soft ? ui.surfaceSoft : ui.surface,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: ui.border),
        boxShadow: [
          BoxShadow(
            color: ui.text.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: box,
      ),
    );
  }
}

class NzSectionHeader extends StatelessWidget {
  const NzSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ui = context.nz;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ui.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(color: ui.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class NzSearchField extends StatelessWidget {
  const NzSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.hintText,
    this.onClear,
    this.busy = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final String hintText;
  final VoidCallback? onClear;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ui = context.nz;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search_rounded, color: ui.muted),
        suffixIcon: busy
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
      ),
    );
  }
}

class NzFilterChip extends StatelessWidget {
  const NzFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final String? count;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ui = context.nz;
    return Material(
      color: selected ? ui.primary : ui.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? ui.primary : ui.border),
      ),
      child: InkWell(
        onTap: onSelected,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : ui.primary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : ui.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (count != null && count!.trim().isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  count!,
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: .78)
                        : ui.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NzEmptyState extends StatelessWidget {
  const NzEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ui = context.nz;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: ui.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: ui.primary, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ui.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: ui.muted, height: 1.45),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class NzSkeletonCard extends StatelessWidget {
  const NzSkeletonCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ui = context.nz;
    return NzSurface(
      padding: EdgeInsets.all(compact ? 12 : 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(ui, .62, 14),
          const SizedBox(height: 10),
          _bar(ui, .42, 10),
          if (!compact) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _bar(ui, 1, 28)),
                const SizedBox(width: 8),
                Expanded(child: _bar(ui, 1, 28)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(NeizamiUiTokens ui, double widthFactor, double height) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Color.alphaBlend(ui.muted.withValues(alpha: .08), ui.surface),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
