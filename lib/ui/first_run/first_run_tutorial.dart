import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/info/app_tip.dart';
import 'package:munich_ways/ui/info/tip_viewer.dart';
import 'package:munich_ways/ui/theme.dart';

/// Optional introduction, sharing the permanent tips' layout and controls.
class FirstRunTutorial extends StatefulWidget {
  const FirstRunTutorial({super.key, required this.onFinish});
  final VoidCallback onFinish;
  @override
  State<FirstRunTutorial> createState() => _FirstRunTutorialState();
}

class _FirstRunTutorialState extends State<FirstRunTutorial> {
  ({bool all, int? index}) _location = (all: false, index: null);

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    final colors = Theme.of(context).colorScheme;
    final tips = _location.all ? orderedAppTips : firstRunAppTips;
    final index = _location.index;
    return Scaffold(
        body: SafeArea(
      child: index != null
          ? TipViewer(
              tips: tips,
              index: index,
              onChanged: (index) => setState(
                  () => _location = (all: _location.all, index: index)),
              onBack: () =>
                  setState(() => _location = (all: false, index: null)),
              onClose: widget.onFinish,
              footer: index == tips.length - 1
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!_location.all)
                              TextButton(
                                  onPressed: () => setState(() =>
                                      _location = (all: true, index: index)),
                                  child: Text(english
                                      ? 'View all tips'
                                      : 'Alle Tipps ansehen')),
                            FilledButton(
                                style: AppButtonStyles.primary(context),
                                onPressed: widget.onFinish,
                                child: Text(english ? 'Done' : 'Fertig')),
                          ]),
                    )
                  : null,
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                      tooltip: context.l10n.close,
                      onPressed: widget.onFinish,
                      icon: const Icon(Icons.close))),
              Expanded(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              colors.primaryContainer,
                              colors.surfaceContainer
                            ]),
                            borderRadius: BorderRadius.circular(24)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.directions_bike,
                                  size: 64, color: colors.primary),
                              const SizedBox(height: 16),
                              Semantics(
                                  header: true,
                                  child: Text(
                                      english ? 'New here?' : 'Neu hier?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold))),
                              const SizedBox(height: 12),
                              Text(
                                  english
                                      ? 'Discover 3 practical tips. You can find them later in the info menu under “Legend & tips”.'
                                      : 'Entdecke 3 praktische Tipps. Du findest sie später unter „Legende & Tipps“ im Info-Menü.',
                                  style: Theme.of(context).textTheme.bodyLarge),
                            ]),
                      ),
                      const SizedBox(height: 16),
                      for (final tip in firstRunAppTips)
                        Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                            child: Row(children: [
                              Icon(tip.icon, color: colors.primary, size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Text(tip.title(english),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                            ])),
                    ]),
              )),
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                            onPressed: widget.onFinish,
                            child: Text(english ? 'Later' : 'Später')),
                        FilledButton(
                            style: AppButtonStyles.primary(context),
                            onPressed: () => setState(
                                () => _location = (all: false, index: 0)),
                            child:
                                Text(english ? 'View tips' : 'Tipps ansehen')),
                      ])),
            ]),
    ));
  }
}
