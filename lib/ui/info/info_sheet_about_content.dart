import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:munich_ways/ui/widgets/menu_list.dart';
import 'package:url_launcher/url_launcher_string.dart';

class InfoSheetAboutContent extends StatelessWidget {
  const InfoSheetAboutContent({
    super.key,
    required this.versionLabel,
    required this.onOpenImprint,
  });

  final String versionLabel;
  final VoidCallback onOpenImprint;

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
    // Keep compatibility with the older Flutter SDK used by CI.
    // ignore: deprecated_member_use
    SemanticsService.announce(message, TextDirection.ltr);
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else if (context.mounted) {
      _snack(
        context,
        context.l10n.isEnglish
            ? 'No app found to open this link'
            : 'Keine App zum Öffnen dieses Links gefunden',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sourceTitle = context.l10n.isEnglish
        ? 'Sources & routing services'
        : 'Quellen & Routendienste';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuGroup(
          children: [
            MenuGroupItem(
              icon: Icons.open_in_new,
              label: context.l10n.isEnglish
                  ? 'About MunichWays'
                  : 'Über MunichWays',
              onTap: () => _openUrl(context, 'https://munichways.de'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          title: Text(
            sourceTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          children: [
            MenuGroup(
              children: [
                MenuGroupItem(
                  icon: Icons.open_in_new,
                  label: context.l10n.isEnglish
                      ? 'About RadlNavi'
                      : 'Über RadlNavi',
                  onTap: () => _openUrl(context, 'https://radlnavi.de'),
                ),
                const MenuGroupDivider(),
                MenuGroupItem(
                  icon: Icons.open_in_new,
                  label: 'BRouter',
                  onTap: () => _openUrl(context, 'https://brouter.de/brouter/'),
                ),
                const MenuGroupDivider(),
                MenuGroupItem(
                  icon: Icons.open_in_new,
                  label: 'OpenStreetMap',
                  onTap: () => _openUrl(
                    context,
                    'https://www.openstreetmap.org/copyright',
                  ),
                ),
                const MenuGroupDivider(),
                MenuGroupItem(
                  icon: Icons.open_in_new,
                  label: 'OpenMapTiles',
                  onTap: () =>
                      _openUrl(context, 'https://www.openmaptiles.org/'),
                ),
                const MenuGroupDivider(),
                MenuGroupItem(
                  icon: Icons.open_in_new,
                  label: 'OpenFreeMap',
                  onTap: () => _openUrl(context, 'https://openfreemap.org/'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegalLink(
              label: context.l10n.tr('Impressum & Datenschutz'),
              onPressed: onOpenImprint,
            ),
            _LegalLink(
              label: context.l10n.tr('Nutzungsbedingungen'),
              onPressed: () => _openUrl(
                context,
                'https://munichways.de/nutzungbedingungen-app',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          versionLabel,
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.uiPrimary,
        textStyle: Theme.of(context).textTheme.bodyMedium,
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
      child: Text(label),
    );
  }
}
