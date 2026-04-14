import 'package:flutter/material.dart';
import 'package:munich_ways/ui/about/settings_sheet_content.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

void showMapSettingsSheet(BuildContext context, MapScreenViewModel model) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BottomSheetFrame(
      title: 'Einstellungen',
      body: SettingsSheetContent(model: model),
    ),
  );
}
