import 'package:flutter/material.dart';
import 'package:munich_ways/ui/theme.dart';

/// The same visual language for every position in a route plan.
class RoutePointBadge extends StatelessWidget {
  const RoutePointBadge({super.key, required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.munichWaysOrange,
        foregroundColor: AppColors.heroForeground,
        child: index == 0
            ? const Icon(Icons.navigation, size: 24)
            : index == count - 1
                ? const Icon(Icons.sports_score, size: 24)
                : FittedBox(
                    child: Text('$index',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
      ),
    );
  }
}
