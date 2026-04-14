import 'package:flutter/material.dart';
import 'package:munich_ways/ui/about/settings_sheet_content.dart';
import 'package:munich_ways/ui/map/map_overlay/map_bottom_sheet_frame.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';

void showMapSettingsSheet(BuildContext context, MapScreenViewModel model) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MapBottomSheetFrame(
      title: 'Einstellungen',
      body: SettingsSheetContent(model: model),
    ),
  );
}
