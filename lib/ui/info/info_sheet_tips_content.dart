import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/info/app_tip.dart';
import 'package:munich_ways/ui/info/tip_illustration.dart';
import 'package:munich_ways/ui/info/tip_screenshot.dart';
import 'package:munich_ways/ui/widgets/menu_list.dart';

class InfoSheetTipsContent extends StatelessWidget {
  const InfoSheetTipsContent({super.key, required this.onOpenTip});

  final ValueChanged<AppTip> onOpenTip;

  @override
  Widget build(BuildContext context) {
    return MenuGroup(children: [
      for (final tip in orderedAppTips) ...[
        if (tip != orderedAppTips.first) const MenuGroupDivider(),
        MenuGroupItem(
          icon: tip.icon,
          label: tip.title(context.l10n.isEnglish),
          trailingElement: const Icon(Icons.chevron_right),
          onTap: () => onOpenTip(tip),
        ),
      ],
    ]);
  }
}

class InfoSheetTipContent extends StatelessWidget {
  const InfoSheetTipContent({super.key, required this.tip});

  final AppTip tip;

  @override
  Widget build(BuildContext context) {
    final illustrated = TipScreenshot.hasScreenshot(tip);
    final description = Text(tip.body(context.l10n.isEnglish),
        style: Theme.of(context).textTheme.bodyLarge);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Semantics(
              header: true,
              child: Text(tip.title(context.l10n.isEnglish),
                  style: Theme.of(context).textTheme.titleLarge),
            )),
        if (illustrated) ...[
          const SizedBox(height: 16),
          TipIllustration(tip: tip),
          const SizedBox(height: 12),
          DecoratedBox(
            key: const ValueKey('tip-description'),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child:
                Padding(padding: const EdgeInsets.all(12), child: description),
          ),
        ] else ...[
          const SizedBox(height: 12),
          DecoratedBox(
              key: const ValueKey('tip-description'),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant)),
              child: Padding(
                  padding: const EdgeInsets.all(12), child: description)),
          const SizedBox(height: 24),
          TipIllustration(tip: tip),
        ],
      ],
    );
  }
}
