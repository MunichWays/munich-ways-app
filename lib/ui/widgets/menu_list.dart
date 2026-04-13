import 'package:flutter/material.dart';
import 'package:munich_ways/ui/theme.dart';

/// Rounded grey panel containing [MenuGroupItem]s separated by [MenuGroupDivider].
class MenuGroup extends StatelessWidget {
  const MenuGroup({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  static const Color _kBackground = Color(0xFFF2F2F2);
  static const double _kRadius = 24;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _kBackground,
        borderRadius: BorderRadius.all(Radius.circular(_kRadius)),
      ),
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

/// Single tappable row with leading icon and label (e.g. info sheet links).
class MenuGroupItem extends StatelessWidget {
  const MenuGroupItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.inkBorderRadius = 12,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double inkBorderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(inkBorderRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            spacing: 16,
            children: [
              Icon(icon, color: AppColors.mapBlack),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w400,
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
