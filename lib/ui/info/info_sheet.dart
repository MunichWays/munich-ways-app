import 'dart:io';

import 'package:flutter/material.dart';
import 'package:munich_ways/ui/info/imprint_screen.dart';
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

  Widget _buildTitle(ThemeData theme) {
    if (_showMapHelp) {
      return const BottomSheetTitle(title: 'Karte nutzen');
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
              ),
              const SizedBox(height: 6),
              Text(
                _versionLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BottomSheetFrame(
      startingElement: _showMapHelp
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Zurück',
              onPressed: () => setState(() => _showMapHelp = false),
            )
          : null,
      title: _buildTitle(theme),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: _showMapHelp
            ? const InfoSheetHelpContent()
            : InfoSheetMainContent(
                versionLabel: _versionLabel,
                onOpenMapHelp: () => setState(() => _showMapHelp = true),
                onOpenImprint: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ImprintScreen(),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
