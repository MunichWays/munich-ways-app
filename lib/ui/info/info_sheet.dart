import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/info/app_tip.dart';
import 'package:munich_ways/ui/info/app_version_label.dart';
import 'package:munich_ways/ui/info/imprint_screen.dart';
import 'package:munich_ways/ui/info/info_sheet_about_content.dart';
import 'package:munich_ways/ui/info/info_sheet_help_content.dart';
import 'package:munich_ways/ui/info/info_sheet_main_content.dart';
import 'package:munich_ways/ui/info/info_sheet_tips_content.dart';
import 'package:munich_ways/ui/info/tip_viewer.dart';
import 'package:munich_ways/ui/widgets/bottom_sheet.dart';

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

enum _InfoPage { main, mapHelp, about, tips }

class _InfoSheetState extends State<InfoSheet> {
  String _versionLabel = '…';

  ({_InfoPage page, AppTip? tip}) _location = (page: _InfoPage.main, tip: null);

  void _open(_InfoPage page, {AppTip? tip}) {
    setState(() => _location = (page: page, tip: tip));
  }

  void _back() {
    _open(_location.tip != null
        ? _InfoPage.tips
        : _location.page == _InfoPage.tips
            ? _InfoPage.mapHelp
            : _InfoPage.main);
  }

  @override
  void initState() {
    super.initState();
    loadAppVersionLabel().then((versionLabel) {
      if (!mounted) return;
      setState(() {
        _versionLabel = versionLabel;
      });
    });
  }

  Widget _buildTitle(BuildContext context) {
    if (_location.page == _InfoPage.tips) {
      return BottomSheetTitle(title: context.l10n.isEnglish ? 'Tips' : 'Tipps');
    }
    if (_location.page == _InfoPage.mapHelp) {
      return BottomSheetTitle(title: context.l10n.tr('Legende & Tipps'));
    }
    if (_location.page == _InfoPage.about) {
      return BottomSheetTitle(
        title: context.l10n.isEnglish
            ? 'About & attributions'
            : 'Über & Quellenangaben',
      );
    }
    final logo = Image.asset(
      'images/logo_long.png',
      height: 36,
      fit: BoxFit.contain,
      semanticLabel: 'MunichWays - Info',
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Theme.of(context).brightness == Brightness.dark)
                ColorFiltered(
                  // Turn the black lettering light while preserving the
                  // original #6699CC MunichWays blue in the logo mark.
                  colorFilter: const ColorFilter.matrix(
                    <double>[
                      -1.5,
                      0,
                      0,
                      0,
                      255,
                      -1,
                      0,
                      0,
                      0,
                      255,
                      -.5,
                      0,
                      0,
                      0,
                      255,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ],
                  ),
                  child: logo,
                )
              else
                logo,
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _location.page == _InfoPage.main,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: _location.tip != null
          ? TipViewer(
              tips: orderedAppTips,
              index: orderedAppTips.indexOf(_location.tip!),
              onChanged: (index) =>
                  _open(_InfoPage.tips, tip: orderedAppTips[index]),
              onBack: _back,
              onClose: () => Navigator.of(context).pop(),
            )
          : BottomSheetFrame(
              key: ValueKey(_location),
              startingElement: _location.page != _InfoPage.main
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: context.l10n.tr('Zurück'),
                      onPressed: _back,
                    )
                  : null,
              title: _buildTitle(context),
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: switch (_location.page) {
                  _InfoPage.mapHelp => InfoSheetHelpContent(
                      onOpenTips: () => _open(_InfoPage.tips)),
                  _InfoPage.tips => InfoSheetTipsContent(
                      onOpenTip: (tip) => _open(_InfoPage.tips, tip: tip)),
                  _InfoPage.about => InfoSheetAboutContent(
                      versionLabel: _versionLabel,
                      onOpenImprint: _openImprint,
                    ),
                  _InfoPage.main => InfoSheetMainContent(
                      versionLabel: _versionLabel,
                      onOpenMapHelp: () => _open(_InfoPage.mapHelp),
                      onOpenAbout: () => _open(_InfoPage.about),
                    ),
                },
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
