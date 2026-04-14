import 'dart:io';

import 'package:flutter/material.dart';
import 'package:munich_ways/ui/about/imprint_screen.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:munich_ways/ui/widgets/menu_list.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

void showMapInfoSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        top: bottomSheetTopPadding(ctx),
        bottom: MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: const MapInfoSheet(),
    ),
  );
}

class MapInfoSheet extends StatefulWidget {
  const MapInfoSheet({super.key});

  @override
  State<MapInfoSheet> createState() => _MapInfoSheetState();
}

class _MapInfoSheetState extends State<MapInfoSheet> {
  String _versionLabel = '…';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        _versionLabel =
            'Version ${info.version}(${info.buildNumber}) ${Platform.isIOS ? 'iOS' : 'Android'}';
      });
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: bottomSheetMaxHeight(context),
        ),
        child: Container(
          decoration: bottomSheetDecoration(),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          children: [
                            Image.asset(
                              'images/logo_long.png',
                              height: 36,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _versionLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.black45,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Schließen',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MenuGroup(
                        children: [
                          MenuGroupItem(
                            icon: Icons.info_outline,
                            label: 'Über MunichWays',
                            onTap: () => _openUrl(
                              'https://munichways.de',
                              'Keine App zum Öffnen von munichways.de gefunden',
                            ),
                          ),
                          const MenuGroupDivider(),
                          MenuGroupItem(
                            icon: Icons.link,
                            label: 'Über RadlNavi',
                            onTap: () => _openUrl(
                              'https://radlnavi.de',
                              'Keine App zum Öffnen von radlnavi.de gefunden',
                            ),
                          ),
                          const MenuGroupDivider(),
                          MenuGroupItem(
                            icon: Icons.mail_outline,
                            label: 'Feedback',
                            onTap: _openFeedback,
                          ),
                          const MenuGroupDivider(),
                          MenuGroupItem(
                            icon: Icons.volunteer_activism_outlined,
                            label: 'Spenden',
                            onTap: () => _openUrl(
                              'https://munichways.de/spenden',
                              'Keine App zum Öffnen von munichways.de gefunden',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => ImprintScreen(),
                              ),
                            );
                          },
                          child: const Text('Impressum & Datenschutz'),
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: () => _openUrl(
                            'https://munichways.de/nutzungbedingungen-app',
                            'Keine App zum Öffnen der Nutzungsbedingungen gefunden',
                          ),
                          child: const Text('Nutzungsbedingungen'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url, String errorMessage) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      _snack(errorMessage);
    }
  }

  Future<void> _openFeedback() async {
    final body = Uri.encodeComponent('Appversion: $_versionLabel\n\n');
    final uri = Uri.parse(
      'mailto:mail@munichways.de?subject=${Uri.encodeComponent('Feedback Munichways App')}&body=$body',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Keine E-Mail-App gefunden');
    }
  }
}
