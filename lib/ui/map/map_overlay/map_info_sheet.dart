import 'dart:io';

import 'package:flutter/material.dart';
import 'package:munich_ways/ui/about/imprint_screen.dart';
import 'package:munich_ways/ui/map/map_overlay/map_bottom_sheet_frame.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

void showMapInfoSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
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
      child: Container(
        decoration: mapOverlayBottomSheetDecoration(),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: mapOverlayMaxScrollBodyHeight(
                    context,
                    chromeAboveBody: 132,
                  ),
                ),
                child: ListView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _InfoLinkRow(
                                icon: Icons.info_outline,
                                label: 'Über MunichWays',
                                onTap: () => _openUrl(
                                  'https://munichways.de',
                                  'Keine App zum Öffnen von munichways.de gefunden',
                                ),
                              ),
                              const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                              _InfoLinkRow(
                                icon: Icons.link,
                                label: 'Über RadlNavi',
                                onTap: () => _openUrl(
                                  'https://radlnavi.de',
                                  'Keine App zum Öffnen von radlnavi.de gefunden',
                                ),
                              ),
                              const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                              _InfoLinkRow(
                                icon: Icons.mail_outline,
                                label: 'Feedback',
                                onTap: _openFeedback,
                              ),
                              const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                              _InfoLinkRow(
                                icon: Icons.volunteer_activism_outlined,
                                label: 'Spenden',
                                onTap: () => _openUrl(
                                  'https://munichways.de/spenden',
                                  'Keine App zum Öffnen von munichways.de gefunden',
                                ),
                              ),
                            ],
                          ),
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
                  ],
                ),
              ),
            ],
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

class _InfoLinkRow extends StatelessWidget {
  const _InfoLinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.mapBlack),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
