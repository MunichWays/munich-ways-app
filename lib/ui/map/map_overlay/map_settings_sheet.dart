import 'package:flutter/material.dart';
import 'package:munich_ways/ui/about/settings_sheet_content.dart';
import 'package:munich_ways/ui/map/map_overlay/map_bottom_sheet_frame.dart';

void showMapSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: MapBottomSheetFrame(
        title: 'Einstellungen',
        body: const SettingsSheetContent(),
      ),
    ),
  );
}
