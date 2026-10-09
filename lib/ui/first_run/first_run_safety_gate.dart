import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/ui/theme.dart';
import 'package:url_launcher/url_launcher.dart';

const appTermsUrl = 'https://www.munichways.de/nutzungbedingungen-app/';

/// Keeps the map mounted behind the notice so data can load while it is read.
/// The builder receives whether startup interactions (including permissions)
/// are allowed. Closing the notice preserves the existing map state.
class FirstRunSafetyGate extends StatefulWidget {
  const FirstRunSafetyGate({
    super.key,
    required this.showNotice,
    required this.onDismiss,
    required this.builder,
    this.openTerms,
  });

  final bool showNotice;
  final Future<void> Function() onDismiss;
  final Widget Function(BuildContext context, bool interactionsEnabled) builder;
  final Future<bool> Function(Uri)? openTerms;

  @override
  State<FirstRunSafetyGate> createState() => _FirstRunSafetyGateState();
}

class _FirstRunSafetyGateState extends State<FirstRunSafetyGate> {
  final _noticeMessengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _dismissed = false;

  void _dismiss() {
    if (_dismissed) return;
    setState(() => _dismissed = true);
    // Storage must not hold up access to the app. If saving fails, the pending
    // flag remains on disk and the notice can be shown again on the next start.
    unawaited(_persistDismissal());
  }

  Future<void> _persistDismissal() async {
    try {
      await widget.onDismiss();
    } catch (error, stackTrace) {
      log.w('Saving first-run safety notice dismissal failed',
          error: error, stackTrace: stackTrace);
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
    if (!mounted || _dismissed || opened) return;
    messenger.showSnackBar(SnackBar(
      content: Text(english
          ? 'The link could not be opened. Please try again.'
          : 'Der Link konnte nicht geöffnet werden. Bitte versuche es erneut.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.showNotice && !_dismissed;
    return PopScope<void>(
      canPop: !visible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && visible) _dismiss();
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
              child: _buildNotice(context),
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
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 8, 12),
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
                            onPressed: _dismiss,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                english
                                    ? 'Ride relaxed – with your eyes open'
                                    : 'Entspannt unterwegs – mit offenen Augen',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              english
                                  ? 'Take care of yourself and pay attention to '
                                      'traffic. Our navigation may contain errors. '
                                      'Follow the conditions around you and '
                                      'the traffic rules.'
                                  : 'Achte auf dich und den Verkehr. Unsere '
                                      'Navigation kann Fehler enthalten. Beachte '
                                      'die Situation vor Ort und die Verkehrsregeln.',
                              style: Theme.of(context).textTheme.bodyLarge,
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
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: FilledButton(
                        onPressed: _dismiss,
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
}
