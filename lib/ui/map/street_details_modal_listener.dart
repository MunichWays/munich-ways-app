import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/model/street_details.dart';
import 'package:munich_ways/ui/map/map_screen_model.dart';
import 'package:munich_ways/ui/street_details/street_details_sheet.dart';
import 'package:provider/provider.dart';

/// Listens for street taps from [MapScreenViewModel] using a [BuildContext] that
/// is under [Navigator] and [ChangeNotifierProvider], so [showModalBottomSheet]
/// receives a valid subtree.
class StreetDetailsModalListener extends StatefulWidget {
  const StreetDetailsModalListener();

  @override
  State<StreetDetailsModalListener> createState() =>
      _StreetDetailsModalListenerState();
}

class _StreetDetailsModalListenerState
    extends State<StreetDetailsModalListener> {
  StreamSubscription<StreetDetails?>? _subscription;

  @override
  void initState() {
    super.initState();
    final model = context.read<MapScreenViewModel>();
    _subscription = model.showStreetDetails.listen(_onStreetDetails);
  }

  void _onStreetDetails(StreetDetails? details) {
    if (!mounted || details == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: StreetDetailsSheet(details: details),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
