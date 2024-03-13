import 'package:flutter/material.dart';
import 'package:munich_ways/ui/map/map_action_buttons/map_button_bar.dart';
import 'package:munich_ways/ui/map/map_action_buttons/map_button_bar_item.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';

class ShowGesamtnetzButton extends StatelessWidget {
  final MapScreenViewModel model;

  const ShowGesamtnetzButton({
    Key? key,
    required this.model,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MapButtonBar(
      children: [
        MapButtonBarItem(
          label: "Alle Strecken einblenden",
          child: Row(
            children: [
              Icon(
                  model.isGesamtnetzVisible ? Icons.layers : Icons.layers_clear,
                  color: model.isGesamtnetzVisible
                      ? AppColors.mapAccentColor
                      : AppColors.disabledMapButton),
              SizedBox(
                width: 4,
              ),
              Text(
                "",
                style: TextStyle(
                    color: model.isGesamtnetzVisible
                        ? AppColors.mapAccentColor
                        : AppColors.disabledMapButton),
              ),
            ],
          ),
          onPressed: () {
            model.toggleGesamtnetzVisible();
          },
        )
      ],
    );
  }
}
