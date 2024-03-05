import 'package:flutter/material.dart';
import 'package:munich_ways/ui/icons/munichways_icons_icons.dart';
import 'package:munich_ways/ui/map/map_action_buttons/map_button_bar.dart';
import 'package:munich_ways/ui/map/map_action_buttons/map_button_bar_item.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/theme.dart';

class LocationButton extends StatelessWidget {
  final Function onPressed;
  final LocationState locationState;

  const LocationButton({
    Key? key,
    required this.onPressed,
    required this.locationState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MapButtonBar(
      children: [
        MapButtonBarItem(
          label: "Aktueller Standort",
          child: _buildIcon(),
          onPressed: this.onPressed,
        ),
      ],
    );
  }

  Icon _buildIcon() {
    switch (this.locationState) {
      case LocationState.NOT_AVAILABLE:
        return Icon(
          Icons.location_searching,
          color: Colors.black26,
          size: 36,
        );
      case LocationState.DISPLAY:
        return Icon(
          Icons.my_location,
          color: Colors.black54,
          size: 36,
        );
      case LocationState.FOLLOW:
        return Icon(
          Icons.my_location,
          color: AppColors.mapAccentColor,
          size: 36,
        );
      case LocationState.FOLLOW_AND_ROTATE_MAP:
        return Icon(
          MunichwaysIcons.compass,
          color: AppColors.mapAccentColor,
          size: 36,
        );
    }
  }
}
