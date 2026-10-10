import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/first_run/first_run_tutorial.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:url_launcher/url_launcher.dart';

const appTermsUrl = 'https://www.munichways.de/nutzungbedingungen-app/';

/// Keeps the map mounted behind the notice and optional tutorial so data loads.
/// The builder receives whether startup interactions (including permissions)
/// are allowed. Finishing first-run UI preserves the existing map state.
class FirstRunSafetyGate extends StatefulWidget {
  const FirstRunSafetyGate({
    super.key,
    required this.showNotice,
    required this.onDismiss,
    required this.builder,
    this.showTutorial = false,
    this.onDismissTutorial,
    this.openTerms,
  }) : assert(!showTutorial || onDismissTutorial != null);

  final bool showNotice;
  final Future<void> Function() onDismiss;
  final Widget Function(BuildContext context, bool interactionsEnabled) builder;
  final Future<bool> Function(Uri)? openTerms;
  final bool showTutorial;
  final Future<void> Function()? onDismissTutorial;

  @override
  State<FirstRunSafetyGate> createState() => _FirstRunSafetyGateState();
}

enum _FirstRunPhase { notice, tutorial, done }

class _FirstRunSafetyGateState extends State<FirstRunSafetyGate> {
  final _noticeMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late _FirstRunPhase _phase;

  @override
  void initState() {
    super.initState();
    _phase = widget.showNotice
        ? _FirstRunPhase.notice
        : widget.showTutorial
            ? _FirstRunPhase.tutorial
            : _FirstRunPhase.done;
  }

  void _dismiss(_FirstRunPhase phase) {
    if (_phase != phase || phase == _FirstRunPhase.done) return;
    final tutorial = phase == _FirstRunPhase.tutorial;
    setState(() => _phase = !tutorial && widget.showTutorial
        ? _FirstRunPhase.tutorial
        : _FirstRunPhase.done);
    // Storage must not hold up access to the app. If saving fails, the pending
    // flag remains on disk and the notice can be shown again on the next start.
    unawaited(_persistDismissal(tutorial));
  }

  Future<void> _persistDismissal(bool tutorial) async {
    try {
      if (tutorial) {
        await widget.onDismissTutorial!();
      } else {
        await widget.onDismiss();
      }
    } catch (error, stackTrace) {
      log.w(
          'Saving first-run ${tutorial ? 'tutorial' : 'safety notice'} dismissal failed',
          error: error,
          stackTrace: stackTrace);
    }
  }

  Future<void> _openTerms() async {
    final messenger = _noticeMessengerKey.currentState!;
    final english = context.l10n.isEnglish;
    var opened = false;
    try {
      final uri = Uri.parse(appTermsUrl);
      opened = await (widget.openTerms?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (error, stackTrace) {
      log.w('Opening app terms failed', error: error, stackTrace: stackTrace);
    }
    if (!mounted || _phase != _FirstRunPhase.notice || opened) return;
    messenger.showSnackBar(SnackBar(
      content: Text(english
          ? 'The link could not be opened. Please try again.'
          : 'Der Link konnte nicht geöffnet werden. Bitte versuche es erneut.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _phase != _FirstRunPhase.done;
    return PopScope<void>(
      canPop: !visible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && visible) _dismiss(_phase);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: visible,
            child: ExcludeSemantics(
              excluding: visible,
              child: IgnorePointer(
                ignoring: visible,
                child: widget.builder(context, !visible),
              ),
            ),
          ),
          if (visible)
            ScaffoldMessenger(
              key: _noticeMessengerKey,
              child: _phase == _FirstRunPhase.notice
                  ? _buildNotice(context)
                  : FirstRunTutorial(
                      onFinish: () => _dismiss(_FirstRunPhase.tutorial)),
            ),
        ],
      ),
    );
  }

  Widget _buildNotice(BuildContext context) {
    final english = context.l10n.isEnglish;
    Widget logo = Image.asset(
      'images/logo_long.png',
      width: 210,
      height: 36,
      fit: BoxFit.contain,
      semanticLabel: 'MunichWays',
    );
    if (Theme.of(context).brightness == Brightness.dark) {
      // Match the info window: light lettering with the original blue mark.
      logo = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
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
        ]),
        child: logo,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
              child: Card(
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: logo,
                            ),
                          ),
                          IconButton(
                            tooltip: context.l10n.close,
                            onPressed: () => _dismiss(_FirstRunPhase.notice),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                english
                                    ? 'As easy as riding a bike!'
                                    : 'So einfach wie Radfahren!',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              english
                                  ? 'Relaxed everyday cycling.'
                                  : 'Entspannt Rad fahren im Alltag.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 12),
                            _welcomeStep(
                                context,
                                1,
                                Icons.touch_app_outlined,
                                english
                                    ? 'Long press your destination on the map'
                                    : 'Ziel auf der Karte länger drücken'),
                            _welcomeStep(
                                context,
                                2,
                                Icons.play_arrow_rounded,
                                english
                                    ? 'Choose “Start route here”, then tap “Start”'
                                    : '„Route hierhin“ wählen, dann „Starten“ antippen'),
                            _welcomeStep(
                                context,
                                3,
                                Icons.navigation_outlined,
                                english
                                    ? 'Follow the navigation instructions'
                                    : 'Navigationshinweisen folgen'),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              english
                                  ? 'Take care of yourself and pay attention to '
                                      'traffic. The navigation or underlying map '
                                      'data may contain errors. Pay attention to '
                                      'the conditions around you.'
                                  : 'Achte auf dich und den Verkehr. Die Navigation '
                                      'oder die Kartenbasis können Fehler enthalten. '
                                      'Beachte die Situation vor Ort.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _openTerms,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              child: Text(english
                                  ? 'Terms of use'
                                  : 'Nutzungsbedingungen'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton(
                        onPressed: () => _dismiss(_FirstRunPhase.notice),
                        style: AppButtonStyles.primary(context),
                        child: Text(english ? 'Let’s go' : 'Los geht’s'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomeStep(
      BuildContext context, int number, IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: colors.primary,
              child: Text('$number',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                      color: colors.onPrimary, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
          const SizedBox(width: 8),
          ExcludeSemantics(child: Icon(icon, color: colors.primary)),
        ]),
      ),
    );
  }
}
