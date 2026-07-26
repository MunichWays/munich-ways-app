import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:munich_ways/localization/app_localizations.dart';
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
    final sourceTitle =
        context.l10n.isEnglish ? 'Map data & sources' : 'Kartendaten & Quellen';

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
            const MenuGroupDivider(),
            MenuGroupItem(
              icon: Icons.open_in_new,
              label:
                  context.l10n.isEnglish ? 'About RadlNavi' : 'Über RadlNavi',
              onTap: () => _openUrl(context, 'https://radlnavi.de'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          sourceTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        MenuGroup(
          children: [
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
              onTap: () => _openUrl(context, 'https://www.openmaptiles.org/'),
            ),
            const MenuGroupDivider(),
            MenuGroupItem(
              icon: Icons.open_in_new,
              label: 'OpenFreeMap',
              onTap: () => _openUrl(context, 'https://openfreemap.org/'),
            ),
            const MenuGroupDivider(),
            MenuGroupItem(
              icon: Icons.open_in_new,
              label: 'BRouter',
              onTap: () => _openUrl(context, 'https://brouter.de/brouter/'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        MenuGroup(
          children: [
            MenuGroupItem(
              icon: Icons.policy_outlined,
              label: context.l10n.tr('Impressum & Datenschutz'),
              onTap: onOpenImprint,
            ),
            const MenuGroupDivider(),
            MenuGroupItem(
              icon: Icons.description_outlined,
              label: context.l10n.tr('Nutzungsbedingungen'),
              onTap: () => _openUrl(
                context,
                'https://munichways.de/nutzungbedingungen-app',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            versionLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
          ),
        ),
      ],
    );
  }
}
