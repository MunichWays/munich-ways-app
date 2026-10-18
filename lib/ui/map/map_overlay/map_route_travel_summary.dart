import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/route.dart';
import 'package:munich_ways/ui/map/navigation_remaining.dart';

/// Presentation only: one compact line, independent of guidance and routing.
class MapRouteTravelSummary extends StatefulWidget {
  const MapRouteTravelSummary({
    super.key,
    required this.route,
    required this.navigationStarted,
    this.remaining,
    this.now,
  });

  final CycleRoute route;
  final bool navigationStarted;
  final NavigationRemaining? remaining;
  final DateTime Function()? now;

  @override
  State<MapRouteTravelSummary> createState() => _MapRouteTravelSummaryState();
}

class _MapRouteTravelSummaryState extends State<MapRouteTravelSummary>
    with WidgetsBindingObserver {
  Timer? _previewClock;
  late DateTime _previewAt;
  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _previewAt = _now();
    _schedulePreviewClock();
  }

  @override
  void didUpdateWidget(covariant MapRouteTravelSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.navigationStarted) _previewAt = _now();
    _schedulePreviewClock();
  }

  void _schedulePreviewClock() {
    _previewClock?.cancel();
    // Active navigation already publishes arrival time with its GPS snapshot.
    if (widget.navigationStarted ||
        !widget.route.duration.isFinite ||
        widget.route.duration < 0) return;
    final now = _now();
    final delay = const Duration(minutes: 1) -
        Duration(seconds: now.second, milliseconds: now.millisecond);
    _previewClock = Timer(delay, () {
      if (!mounted || widget.navigationStarted) return;
      setState(() => _previewAt = _now());
      _schedulePreviewClock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || widget.navigationStarted) return;
    setState(() => _previewAt = _now());
    _schedulePreviewClock();
  }

  @override
  void dispose() {
    _previewClock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    final route = widget.route;
    final navigating = widget.navigationStarted;
    final estimate =
        identical(widget.remaining?.route, route) ? widget.remaining : null;
    final minutes = navigating
        ? estimate?.minutes
        : route.duration.isFinite && route.duration >= 0
            ? (route.duration / 60).round()
            : null;
    final meters = navigating
        ? estimate == null
            ? null
            : estimate.hundredsOfMeters * 100.0
        : route.distance;
    final arrival = navigating
        ? estimate?.arrivalTime.toLocal()
        : minutes == null
            ? null
            : _previewAt.add(Duration(minutes: minutes)).toLocal();
    final clock = arrival == null
        ? '—:—'
        : '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
    final duration =
        '${navigating && minutes != null ? '≈ ' : ''}${minutes ?? '—'} ${english ? 'min' : 'Min'}';
    final distance = meters == null || !meters.isFinite
        ? '— km'
        : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', english ? '.' : ',')} km';
    final routeEnd = navigating && route.destinationConnector.length >= 2;
    String localized(String de, String en) => english ? en : de;
    final durationLabel = minutes == null
        ? localized('Restfahrzeit derzeit nicht verfügbar',
            'Remaining travel time currently unavailable')
        : navigating
            ? localized('Geschätzte Restfahrzeit: $minutes Minuten',
                'Estimated remaining travel time: $minutes minutes')
            : localized(
                'Fahrzeit: $minutes Minuten', 'Travel time: $minutes minutes');
    final arrivalLabel = arrival == null
        ? localized('Ankunftszeit derzeit nicht verfügbar',
            'Arrival time currently unavailable')
        : routeEnd
            ? localized('Geschätzte Ankunft am Routenende: $clock',
                'Estimated arrival at route end: $clock')
            : localized('Geschätzte Ankunftszeit: $clock',
                'Estimated arrival time: $clock');
    final distanceLabel = navigating && estimate == null
        ? localized('Reststrecke derzeit nicht verfügbar',
            'Remaining distance currently unavailable')
        : routeEnd
            ? localized('Reststrecke bis Routenende: $distance',
                'Remaining distance to route end: $distance')
            : navigating
                ? localized(
                    'Reststrecke: $distance', 'Remaining distance: $distance')
                : localized('Strecke: $distance', 'Distance: $distance');
    final style =
        (Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16))
            .copyWith(color: Colors.white, fontWeight: FontWeight.w400);
    Widget value(String text, String label, {bool primary = false}) =>
        Semantics(
          label: label,
          excludeSemantics: true,
          child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: Text(text,
                maxLines: 1,
                style: style.copyWith(
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w400)),
          ),
        );
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: 16, vertical: navigating ? 8 : 2),
      child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // Large accessibility text stays readable, on one line, without
                // making the panel taller with additional rows or shrinking the text.
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ExcludeSemantics(
                            child: Icon(Icons.sports_score,
                                color: Colors.white70, size: 19)),
                        const SizedBox(width: 7),
                        value(duration, durationLabel, primary: true),
                        ExcludeSemantics(child: Text(' · ', style: style)),
                        value(clock, arrivalLabel),
                        ExcludeSemantics(child: Text(' · ', style: style)),
                        value(distance, distanceLabel),
                      ]),
                ),
              )),
    );
  }
}
