import 'dart:io';

import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/info/imprint_screen.dart';
import 'package:munich_ways/ui/info/info_sheet_about_content.dart';
import 'package:munich_ways/ui/info/info_sheet_help_content.dart';
import 'package:munich_ways/ui/info/info_sheet_main_content.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';

void showMapInfoSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const InfoSheet(),
  );
}

class InfoSheet extends StatefulWidget {
  const InfoSheet({super.key});

  @override
  State<InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<InfoSheet> {
  String _versionLabel = '…';

  /// Drill-in help page.
  bool _showMapHelp = false;
  bool _showAbout = false;

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

  Widget _buildTitle(BuildContext context) {
    if (_showMapHelp) {
      return BottomSheetTitle(title: context.l10n.tr('Legende & Tipps'));
    }
    if (_showAbout) {
      return BottomSheetTitle(
        title: context.l10n.isEnglish
            ? 'About & attributions'
            : 'Über & Quellenangaben',
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'images/logo_long.png',
                height: 36,
                fit: BoxFit.contain,
                semanticLabel: 'MunichWays - Info',
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetFrame(
      startingElement: _showMapHelp || _showAbout
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: context.l10n.tr('Zurück'),
              onPressed: () => setState(() {
                _showMapHelp = false;
                _showAbout = false;
              }),
            )
          : null,
      title: _buildTitle(context),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: _showMapHelp
            ? const InfoSheetHelpContent()
            : _showAbout
                ? InfoSheetAboutContent(
                    versionLabel: _versionLabel,
                    onOpenImprint: _openImprint,
                  )
                : InfoSheetMainContent(
                    versionLabel: _versionLabel,
                    onOpenMapHelp: () => setState(() => _showMapHelp = true),
                    onOpenAbout: () => setState(() => _showAbout = true),
                  ),
      ),
    );
  }

  void _openImprint() {
    Navigator.of(context).pop();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ImprintScreen(),
      ),
    );
  }
}
