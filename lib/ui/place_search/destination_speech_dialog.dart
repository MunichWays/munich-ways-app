import 'dart:async';

import 'package:flutter/material.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/speech/speech_input_controller.dart';
import 'package:munich_ways/speech/speech_input_engine.dart';
import 'package:provider/provider.dart';

/// Returns completed or explicitly accepted text. The caller owns the search.
Future<String?> showDestinationSpeechDialog(BuildContext context) {
  final controller = context.read<SpeechInputController>();
  if (controller.isBusy) return Future.value(null);
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<String>(
    context: context,
    builder: (_) => _DestinationSpeechDialog(controller: controller),
  );
}

class _DestinationSpeechDialog extends StatefulWidget {
  const _DestinationSpeechDialog({required this.controller});
  final SpeechInputController controller;

  @override
  State<_DestinationSpeechDialog> createState() =>
      _DestinationSpeechDialogState();
}

class _DestinationSpeechDialogState extends State<_DestinationSpeechDialog> {
  bool _waiting = false;
  bool _closing = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.hasStartedInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_closing) unawaited(_start());
      });
    }
  }

  Future<void> _start() async {
    if (_waiting || widget.controller.isBusy) return;
    widget.controller.markInputStarted();
    setState(() {
      _attempted = true;
      _waiting = true;
    });
    final text = await widget.controller.start(
      localeId: context.l10n.isEnglish ? 'en-US' : 'de-DE',
    );
    if (!mounted || _closing) return;
    setState(() => _waiting = false);
    if (text != null || widget.controller.failure == null) {
      _closing = true;
      Navigator.of(context).pop(text);
    }
  }

  void _cancel() {
    _closing = true;
    if (_waiting) unawaited(widget.controller.cancel());
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  String _failureMessage(SpeechInputFailure failure, bool english) =>
      switch (failure) {
        SpeechInputFailure.permissionDenied => english
            ? 'Microphone or speech recognition permission is missing. Allow access in your device settings, then try again.'
            : 'Die Berechtigung für Mikrofon oder Spracherkennung fehlt. Erlaube den Zugriff in den Geräteeinstellungen und versuche es erneut.',
        SpeechInputFailure.languageUnavailable => english
            ? 'English speech recognition is unavailable on this device.'
            : 'Deutsche Spracherkennung ist auf diesem Gerät nicht verfügbar.',
        SpeechInputFailure.noMatch => english
            ? 'Not understood. Please try again.'
            : 'Nicht verstanden. Bitte erneut versuchen.',
        SpeechInputFailure.timeout => english
            ? 'The recording timed out. Please try again.'
            : 'Die Aufnahme wurde wegen Zeitüberschreitung beendet. Bitte erneut versuchen.',
        SpeechInputFailure.network => english
            ? 'Speech recognition could not connect. Check your connection and try again.'
            : 'Die Spracherkennung konnte keine Verbindung herstellen. Prüfe die Verbindung und versuche es erneut.',
        SpeechInputFailure.busy => english
            ? 'Speech recognition is busy. Please try again shortly.'
            : 'Die Spracherkennung ist beschäftigt. Bitte gleich erneut versuchen.',
        SpeechInputFailure.audio => english
            ? 'Microphone access was interrupted. Please try again.'
            : 'Der Mikrofonzugriff wurde unterbrochen. Bitte erneut versuchen.',
        SpeechInputFailure.unknown => english
            ? 'Speech recognition ended unexpectedly. Please try again.'
            : 'Die Spracherkennung wurde unerwartet beendet. Bitte erneut versuchen.',
        SpeechInputFailure.unavailable => english
            ? 'Speech recognition is currently unavailable. Try again or type your destination.'
            : 'Die Spracherkennung ist derzeit nicht verfügbar. Versuche es erneut oder tippe dein Ziel ein.',
      };

  @override
  Widget build(BuildContext context) {
    final english = context.l10n.isEnglish;
    return PopScope<String>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _cancel();
      },
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final canUseText = _attempted &&
              !_waiting &&
              !controller.isBusy &&
              controller.failure != null &&
              controller.partialText.isNotEmpty;
          final hasFailure = !_waiting && controller.failure != null;
          final isListening = controller.state == SpeechInputState.listening;
          final status = switch (controller.state) {
            SpeechInputState.initializing =>
              english ? 'Preparing microphone…' : 'Mikrofon wird vorbereitet …',
            SpeechInputState.listening =>
              english ? 'Listening…' : 'Ich höre zu …',
            SpeechInputState.processing ||
            SpeechInputState.cancelling =>
              english
                  ? 'Finishing recording…'
                  : 'Aufnahme wird abgeschlossen …',
            _ => english ? 'Say your destination.' : 'Sprich dein Ziel.',
          };
          return AlertDialog(
            title: Text(english ? 'Speak destination' : 'Ziel sprechen'),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_attempted) ...[
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasFailure || isListening) ...[
                          ExcludeSemantics(
                            child: Icon(
                              hasFailure
                                  ? Icons.warning_amber_rounded
                                  : Icons.fiber_manual_record,
                              color: hasFailure
                                  ? Colors.amber.shade800
                                  : Colors.red.shade700,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            hasFailure
                                ? _failureMessage(controller.failure!, english)
                                : status,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color:
                                      isListening ? Colors.red.shade700 : null,
                                  fontWeight:
                                      isListening ? FontWeight.bold : null,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.partialText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(controller.partialText),
                  ],
                  if (canUseText) ...[
                    const SizedBox(height: 8),
                    Text(english
                        ? 'You can use the recognized text and edit it in the search field.'
                        : 'Du kannst den erkannten Text übernehmen und im Suchfeld korrigieren.'),
                  ],
                ],
                if (!_attempted) Text(status),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _cancel();
                  Navigator.of(context).pop();
                },
                child: Text(english ? 'Cancel' : 'Abbrechen'),
              ),
              if (canUseText)
                FilledButton(
                  onPressed: () {
                    _closing = true;
                    Navigator.of(context).pop(controller.partialText);
                  },
                  child: Text(english ? 'Use text' : 'Text übernehmen'),
                ),
              if (_waiting)
                FilledButton(
                  onPressed: controller.state == SpeechInputState.listening
                      ? () => unawaited(controller.stop())
                      : null,
                  child: Text(english ? 'Stop recording' : 'Aufnahme stoppen'),
                )
              else
                FilledButton(
                  onPressed: controller.isBusy ? null : _start,
                  child: Text(_attempted
                      ? (english ? 'Try again' : 'Erneut versuchen')
                      : (english ? 'Start recording' : 'Aufnahme starten')),
                ),
            ],
          );
        },
      ),
    );
  }
}
