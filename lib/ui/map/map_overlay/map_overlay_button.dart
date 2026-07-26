import 'package:flutter/material.dart';
import 'package:munich_ways/ui/theme.dart';

/// Translucent map control: [child] is typically an [Icon].
/// When [isActive] is true, icon color follows [AppColors.mapAccentColor].
///
/// Uses a shaped [Material] only (no [BackdropFilter]): platform compositing
/// often keeps backdrop blur in a square behind the map, which looks wrong.
class MapOverlayButton extends StatelessWidget {
  const MapOverlayButton({
    super.key,
    required this.child,
    this.isActive = false,
    this.onPressed,
    this.circular = true,
    this.size = 48,
    this.emphasizeActive = false,
    this.tooltip,
  });

  final Widget child;
  final bool isActive;
  final VoidCallback? onPressed;
  final bool circular;
  final double size;
  final bool emphasizeActive;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final borderRadius = circular ? size / 2 : 14.0;
    final shape = circular
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          );

    Widget core = Material(
      color: isActive && emphasizeActive
          ? AppColors.mapAccentColor
          : AppColors.mapButtonBackground.withValues(alpha: 0.80),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.transparent,
      child: InkWell(
        customBorder: shape,
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: IconTheme.merge(
            data: IconThemeData(
              color: isActive
                  ? emphasizeActive
                      ? Colors.white
                      : AppColors.mapButtonForegroundActive
                  : AppColors.mapButtonForeground,
              size: 24,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      core = Tooltip(message: tooltip!, child: core);
    }
    return core;
  }
}
