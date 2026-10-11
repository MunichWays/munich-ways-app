import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/reviews/app_review_diagnostics.dart';
import 'package:munich_ways/reviews/app_review_service.dart';

class InfoSheetDiagnosticsContent extends StatefulWidget {
  const InfoSheetDiagnosticsContent({
    super.key,
    required this.versionLabel,
    this.reviewService,
    this.runtimeDiagnostics,
    this.settingsDiagnostics,
  });

  final String versionLabel;
  final AppReviewService? reviewService;
  final Map<String, String> Function()? runtimeDiagnostics;
  final Map<String, String> Function()? settingsDiagnostics;

  @override
  State<InfoSheetDiagnosticsContent> createState() =>
      _InfoSheetDiagnosticsContentState();
}

class _InfoSheetDiagnosticsContentState
    extends State<InfoSheetDiagnosticsContent> {
  late Future<AppReviewDiagnostics> _snapshot;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  Future<AppReviewDiagnostics> _load() =>
      (widget.reviewService ?? appReviewService).readDiagnostics();

  List<_DiagnosticSection> _sections(
      BuildContext context, AppReviewDiagnostics data) {
    final en = context.l10n.isEnglish;
    String t(String de, String english) => en ? english : de;
    String flag(bool? value) => value == null
        ? t('Unbekannt', 'Unknown')
        : value
            ? t('Ja', 'Yes')
            : t('Nein', 'No');
    final media = MediaQuery.of(context);
    return [
      _DiagnosticSection(title: t('App & System', 'App & system'), rows: [
        (
          t('Erfasst (UTC)', 'Captured (UTC)'),
          DateTime.now().toUtc().toIso8601String()
        ),
        (
          t('Version', 'Version'),
          widget.versionLabel.replaceFirst(RegExp(r'^Version\s+'), '')
        ),
        (
          t('Betriebssystem', 'Operating system'),
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'
        ),
        (
          t('Ausführung', 'Build mode'),
          kDebugMode
              ? 'debug'
              : kProfileMode
                  ? 'profile'
                  : 'release'
        ),
        (
          t('Sprache', 'Language'),
          Localizations.localeOf(context).toLanguageTag()
        ),
        (t('Darstellung', 'Theme'), Theme.of(context).brightness.name),
        (
          t('Bildschirm (dp)', 'Screen (dp)'),
          '${media.size.width.toStringAsFixed(0)} × ${media.size.height.toStringAsFixed(0)}'
        ),
        (t('Pixeldichte', 'Pixel ratio'), '${media.devicePixelRatio}'),
        (
          t('Textskalierung', 'Text scale'),
          '${media.textScaler.scale(16) / 16}'
        ),
        (
          t('Animationen reduziert', 'Reduced animations'),
          flag(media.disableAnimations)
        ),
      ]),
      _DiagnosticSection(
          title: t('Einstellungen', 'Settings'),
          collapsed: true,
          rows: widget.settingsDiagnostics
                  ?.call()
                  .entries
                  .map((e) => (e.key, e.value))
                  .toList() ??
              [],
          notes: [
            if (widget.settingsDiagnostics == null)
              t('Keine Einstellungen verfügbar', 'Settings unavailable')
          ]),
      _DiagnosticSection(
          title: t('Karte & Navigation', 'Map & navigation'),
          collapsed: true,
          rows: widget.runtimeDiagnostics
                  ?.call()
                  .entries
                  .map((e) => (e.key, e.value))
                  .toList() ??
              [],
          notes: [
            t('Momentaufnahme', 'Snapshot'),
            if (widget.runtimeDiagnostics == null)
              t('Keine Laufzeitdaten verfügbar', 'Runtime data unavailable')
          ]),
      _DiagnosticSection(
          title: t('App-Bewertung', 'App review'),
          collapsed: true,
          rows: [
            (
              t('Bewertungszähler', 'Review counter'),
              data.completedTrips == null
                  ? t('Nicht lesbar', 'Unreadable')
                  : '${data.completedTrips}/3'
            ),
            (
              t('Einmaliger Anfrageversuch vermerkt',
                  'One-time request attempt recorded'),
              flag(data.requestAttempted)
            ),
            (
              t('Store verfügbar (letzte Prüfung)',
                  'Store available (last check)'),
              flag(data.storeAvailable)
            ),
            if (data.storageError != null)
              (t('Lesefehler', 'Read error'), data.storageError!),
            if (data.failureType != null)
              (t('Letzter Fehlertyp', 'Last failure type'), data.failureType!),
            (
              t('Dialoganzeige / Bewertung', 'Dialog shown / review submitted'),
              t('Nicht feststellbar', 'Cannot be determined')
            ),
          ],
          notes: [
            t('Letzte Bewertungsereignisse (nur diese App-Sitzung, max. 20)',
                'Recent review events (this app session only, max. 20)'),
            if (data.events.isEmpty)
              t('Keine Ereignisse in dieser Sitzung',
                  'No events in this session'),
          ],
          events: [
            for (final entry in data.events)
              (entry.time.toIso8601String(), _eventLabel(entry.event, en))
          ],
          footer: t(
              'Zähler und Anfragevermerk bleiben nach Neustart erhalten. Ereignisse und Store-Verfügbarkeit nicht.',
              'Counter and request marker survive restarts. Events and store availability do not.')),
    ];
  }

  String _privacy(bool en) => en
      ? 'No destinations, coordinates, favorites or credentials. Nothing is sent automatically.'
      : 'Keine Ziele, Koordinaten, Favoriten oder Zugangsschlüssel. Keine automatische Übertragung.';

  @override
  Widget build(BuildContext context) {
    final en = context.l10n.isEnglish;
    return FutureBuilder<AppReviewDiagnostics>(
      future: _snapshot,
      builder: (context, snapshot) {
        final sections =
            snapshot.hasData ? _sections(context, snapshot.data!) : null;
        final report = sections == null
            ? null
            : [
                'MunichWays – ${en ? 'Diagnostics' : 'Diagnosedaten'}',
                for (final section in sections) section.report,
                _privacy(en),
              ].join('\n\n');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              TextButton.icon(
                onPressed: snapshot.connectionState == ConnectionState.waiting
                    ? null
                    : () => setState(() {
                          _copied = false;
                          _snapshot = _load();
                        }),
                icon: const Icon(Icons.refresh),
                label: Text(en ? 'Refresh' : 'Aktualisieren'),
              ),
              TextButton.icon(
                onPressed: report == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: report));
                        if (mounted) setState(() => _copied = true);
                      },
                icon: const Icon(Icons.copy_outlined),
                label: Text(_copied
                    ? (en ? 'Copied' : 'Kopiert')
                    : (en ? 'Copy' : 'Kopieren')),
              ),
            ]),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (sections != null) ...[
              for (final section in sections)
                _DiagnosticSectionView(section: section),
              const SizedBox(height: 16),
              Text(_privacy(en), style: Theme.of(context).textTheme.bodySmall),
            ] else
              Text(en
                  ? 'Could not load diagnostics. Please try again.'
                  : 'Diagnosedaten konnten nicht geladen werden. Bitte erneut versuchen.'),
          ],
        );
      },
    );
  }
}

class _DiagnosticSection {
  const _DiagnosticSection(
      {required this.title,
      required this.rows,
      this.collapsed = false,
      this.notes = const [],
      this.events = const [],
      this.footer});

  final String title;
  final List<(String, String)> rows;
  final bool collapsed;
  final List<String> notes;
  final List<(String, String)> events;
  final String? footer;

  String get report => [
        title,
        for (final (label, value) in rows) '$label: $value',
        ...notes,
        for (final (time, event) in events) '$time  $event',
        if (footer != null) footer!
      ].join('\n');
}

class _DiagnosticSectionView extends StatelessWidget {
  const _DiagnosticSectionView({required this.section});
  final _DiagnosticSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (label, value) in section.rows)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '$label: ',
                    style:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              style: theme.textTheme.bodySmall,
            )),
      for (final note in section.notes)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(note, style: theme.textTheme.bodySmall)),
      for (final (time, event) in section.events)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(time,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(event, style: theme.textTheme.bodySmall),
            ])),
      if (section.footer != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(section.footer!, style: theme.textTheme.bodySmall)),
    ]);
    final title = Text(section.title,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600));
    if (section.collapsed) {
      return Material(
          color: Colors.transparent,
          child: ExpansionTile(
            key: PageStorageKey(section.title),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            title: title,
            children: [content],
          ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      title,
      const SizedBox(height: 8),
      content,
      const SizedBox(height: 16)
    ]);
  }
}

String _eventLabel(ReviewDiagnosticEvent event, bool en) {
  final (de, english) = switch (event) {
    ReviewDiagnosticEvent.tripRecorded => (
        'Orangener Abschluss gespeichert',
        'Orange Finish recorded'
      ),
    ReviewDiagnosticEvent.storageFailed => (
        'Speichern fehlgeschlagen',
        'Storage failed'
      ),
    ReviewDiagnosticEvent.promptScheduled => (
        'Anfrage in 2 Sekunden geplant',
        'Request scheduled in 2 seconds'
      ),
    ReviewDiagnosticEvent.promptCancelled => (
        'Geplante Anfrage abgebrochen',
        'Scheduled request cancelled'
      ),
    ReviewDiagnosticEvent.interfaceBusy => (
        'Anfrage verworfen: Oberfläche nicht frei oder Aktion abgebrochen',
        'Request skipped: interface busy or action cancelled'
      ),
    ReviewDiagnosticEvent.checkingStore => (
        'Store-Verfügbarkeit wird geprüft',
        'Checking store availability'
      ),
    ReviewDiagnosticEvent.storeUnavailable => (
        'Store meldet nicht verfügbar',
        'Store reports unavailable'
      ),
    ReviewDiagnosticEvent.requestSkipped => (
        'Kein Aufruf: Versuch bereits vermerkt, Schwelle nicht erreicht oder abgebrochen',
        'No handoff: attempt recorded, threshold not reached or cancelled'
      ),
    ReviewDiagnosticEvent.nativeHandoff => (
        'Bewertungsanfrage an native API übergeben',
        'Review request handed to native API'
      ),
    ReviewDiagnosticEvent.nativeCompleted => (
        'Nativer Aufruf abgeschlossen; Anzeige unbekannt',
        'Native call completed; display unknown'
      ),
    ReviewDiagnosticEvent.requestFailed => (
        'Bewertungsanfrage fehlgeschlagen / Zeitlimit',
        'Review request failed / timed out'
      ),
  };
  return en ? english : de;
}
