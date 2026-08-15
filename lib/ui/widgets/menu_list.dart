import 'package:flutter/material.dart';

/// Rounded grey panel containing [MenuGroupItem]s separated by [MenuGroupDivider].
class MenuGroup extends StatelessWidget {
  const MenuGroup({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  static const double _kRadius = 24;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: const BorderRadius.all(Radius.circular(_kRadius)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Horizontal rule between [MenuGroupItem]s inside a [MenuGroup].
class MenuGroupDivider extends StatelessWidget {
  const MenuGroupDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }
}

/// Row with optional leading icon, label, optional [trailingElement], and optional tap.
class MenuGroupItem extends StatelessWidget {
  const MenuGroupItem({
    super.key,
    this.icon,
    required this.label,
    this.labelSemantics,
    this.onTap,
    this.trailingElement,
    this.inkBorderRadius = 12,
  });

  /// Matches typical touch targets (e.g. [Switch]) so rows with only an [Icon]
  /// trailing do not look shorter than rows with switches or dropdowns.
  static const double _kMinRowExtent = kMinInteractiveDimension;

  final IconData? icon;
  final String label;
  final String? labelSemantics;
  final VoidCallback? onTap;
  final Widget? trailingElement;
  final double inkBorderRadius;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Semantics(
      label: labelSemantics,
      child: ExcludeSemantics(
        excluding: labelSemantics != null,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w400,
              ),
        ),
      ),
    );

    final rowChildren = <Widget>[
      if (icon != null) ...[
        ExcludeSemantics(
          child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(width: 16),
      ],
      Expanded(child: labelWidget),
      if (trailingElement != null) ...[
        const SizedBox(width: 12),
        trailingElement!,
      ],
    ];

    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinRowExtent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: rowChildren,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(inkBorderRadius),
          onTap: onTap,
          child: padded,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: padded,
    );
  }
}
