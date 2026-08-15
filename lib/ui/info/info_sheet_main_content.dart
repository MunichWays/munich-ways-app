import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/menu_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Main list + legal links for [InfoSheet].
class InfoSheetMainContent extends StatelessWidget {
  const InfoSheetMainContent({
    super.key,
    required this.versionLabel,
    required this.onOpenMapHelp,
    required this.onOpenAbout,
  });

  final String versionLabel;

  final VoidCallback onOpenMapHelp;

  final VoidCallback onOpenAbout;

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
    // `announce` also works with the older Flutter SDK used by the 3.0 CI job.
    // ignore: deprecated_member_use
    SemanticsService.announce(message, TextDirection.ltr);
  }

  Future<void> _openUrl(
    BuildContext context,
    String url,
    String errorMessage,
  ) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      if (context.mounted) _snack(context, errorMessage);
    }
  }

  Future<void> _openFeedback(BuildContext context) async {
    final body = Uri.encodeComponent('Appversion: $versionLabel\n\n');
    final uri = Uri.parse(
      'mailto:mail@munichways.de?subject=${Uri.encodeComponent('Feedback Munichways App')}&body=$body',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) _snack(context, 'Keine E-Mail-App gefunden');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CompactColorLegend(),
        const SizedBox(height: 12),
        MenuGroup(
          children: [
            MenuGroupItem(
              icon: Icons.map_outlined,
              label: context.l10n.tr('Legende & Tipps'),
              trailingElement: const Icon(Icons.chevron_right),
              onTap: onOpenMapHelp,
            ),
            const MenuGroupDivider(),
            MenuGroupItem(
              icon: Icons.mail_outline,
              label: 'Feedback',
              onTap: () => _openFeedback(context),
            ),
            const MenuGroupDivider(),
            MenuGroupItem(
              icon: Icons.volunteer_activism_outlined,
              label: context.l10n.isEnglish ? 'Donate' : 'Spenden',
              onTap: () => _openUrl(
                context,
                'https://munichways.de/spenden',
                'Keine App zum Öffnen von munichways.de gefunden',
              ),
            ),
            const MenuGroupDivider(),
            MenuGroupItem(
              icon: Icons.link,
              label: context.l10n.isEnglish
                  ? 'About & attributions'
                  : 'Über & Quellenangaben',
              trailingElement: const Icon(Icons.chevron_right),
              onTap: onOpenAbout,
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactColorLegend extends StatelessWidget {
  const _CompactColorLegend();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        AppColors.mapGreen,
        context.l10n.isEnglish ? 'Comfortable' : 'Gemütlich',
      ),
      (
        AppColors.mapYellow,
        context.l10n.isEnglish ? 'Average' : 'Durchschnittlich',
      ),
      (
        AppColors.mapRed,
        context.l10n.isEnglish ? 'Stressful' : 'Stressig',
      ),
      (
        AppColors.getPolylineColor(
          'schwarz',
          dark: Theme.of(context).brightness == Brightness.dark,
        ),
        context.l10n.isEnglish ? 'Very stressful' : 'Sehr stressig',
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: item.$1,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(item.$2),
            ],
          ),
      ],
    );
  }
}
