import 'dart:async';
import 'dart:io';
import 'package:munich_ways/model/gpx_import_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:munich_ways/api/route_transfer_io.dart';
import 'package:munich_ways/localization/app_localizations.dart';
import 'package:munich_ways/model/route_transfer.dart';
import 'package:munich_ways/ui/map/route_qr_scanner.dart';
import 'package:munich_ways/ui/theme.dart';

Future<RouteTransfer?> showRouteImportSourceDialog(BuildContext context) async {
  final route = DialogRoute<RouteTransfer>(
      context: context, builder: (_) => const RouteImportSourceDialog());
  final result = await Navigator.of(context).push(route);
  await route.completed;
  return result;
}

/// Selects and loads a source without changing the active route.
class RouteImportSourceDialog extends StatefulWidget {
  const RouteImportSourceDialog(
      {super.key, this.pickFile, this.loadLink, this.scanLink});
  final Future<RouteTransfer?> Function()? pickFile;
  final Future<RouteTransfer> Function(Uri)? loadLink;
  final Future<Uri?> Function(BuildContext)? scanLink;
  @override
  State<RouteImportSourceDialog> createState() =>
      _RouteImportSourceDialogState();
}

class _RouteImportSourceDialogState extends State<RouteImportSourceDialog> {
  final _link = TextEditingController();
  bool _busy = false;
  bool _finishing = false;
  String? _error;
  http.Client? _client;
  bool get _english => context.l10n.isEnglish;

  Future<RouteTransfer> _load(Uri uri) async {
    if (widget.loadLink != null) return widget.loadLink!(uri);
    final client = http.Client();
    _client = client;
    try {
      return await RouteTransferIo.loadLink(uri, client: client);
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<void> _run(
    Future<RouteTransfer?> Function() action, {
    required bool file,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final transfer = await action();
      if (mounted &&
          transfer != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        _finishing = true;
        Navigator.pop(context, transfer);
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is GpxImportException
          ? error.userMessage(english: _english)
          : error is ExpiredRouteLinkException
              ? (_english
                  ? 'Link expired or unavailable. Create a new sharing link in RadlNavi.'
                  : 'Link abgelaufen oder nicht verfügbar. Bitte in RadlNavi einen neuen Teilen-Link erstellen.')
              : file
                  ? error is FormatException
                      ? (_english
                          ? 'The GPX file is damaged or unsupported.'
                          : 'Die GPX-Datei ist beschädigt oder wird nicht unterstützt.')
                      : (_english
                          ? 'Could not read the file. Please select it again.'
                          : 'Die Datei konnte nicht gelesen werden. Bitte erneut auswählen.')
                  : error is FormatException
                      ? (_english
                          ? 'Route unreadable. Create a new sharing link in RadlNavi.'
                          : 'Route nicht lesbar. Bitte in RadlNavi einen neuen Teilen-Link erstellen.')
                      : error is IOException ||
                              error is TimeoutException ||
                              error is http.ClientException
                          ? (_english
                              ? 'Could not load route. Check your internet connection and retry.'
                              : 'Route nicht geladen. Internetverbindung prüfen und erneut versuchen.')
                          : (_english
                              ? 'Import failed. Please try again.'
                              : 'Import fehlgeschlagen. Bitte erneut versuchen.');
      setState(() => _error = message);
    } finally {
      if (mounted && !_finishing) setState(() => _busy = false);
    }
  }

  void _openLink() {
    final uri = RouteTransferIo.parseLink(_link.text);
    if (uri == null) {
      setState(() => _error = _english
          ? 'Please paste a valid RadlNavi sharing link.'
          : 'Bitte einen gültigen RadlNavi-Teilen-Link einfügen.');
      return;
    }
    _run(() => _load(uri), file: false);
  }

  Future<void> _scan() => _run(() async {
        // Do not keep the keyboard in front of the camera permission prompt.
        FocusScope.of(context).unfocus();
        final uri = await (widget.scanLink ?? showRouteQrScanner)(context);
        if (uri == null || !mounted) return null;
        if (RouteTransferIo.sharedId(uri) == null)
          throw const FormatException('Unsupported route link');
        _link.text = uri.toString();
        return _load(uri);
      }, file: false);

  Future<void> _paste() async {
    try {
      final content = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted || _busy) return;
      final text = content?.text?.trim() ?? '';
      if (text.length > 2048) {
        setState(() => _error = _english
            ? 'Text too long. Copy only the route link.'
            : 'Text zu lang. Bitte nur den Routenlink kopieren.');
        return;
      }
      setState(() => _error = text.isEmpty
          ? (_english
              ? 'Clipboard contains no text.'
              : 'Zwischenablage enthält keinen Text.')
          : null);
      if (text.isNotEmpty) _link.text = text;
    } catch (_) {
      if (mounted)
        setState(() => _error = _english
            ? 'Could not paste. Touch and hold the link field to paste.'
            : 'Einfügen nicht möglich. Halte das Linkfeld gedrückt, um den Link einzufügen.');
    }
  }

  @override
  void dispose() {
    _client?.close();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SizedBox(
                key: const Key('route-import-panel'),
                width: double.infinity,
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    _english
                                        ? 'Import route'
                                        : 'Route importieren',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge)),
                            IconButton(
                                tooltip: _english ? 'Cancel' : 'Abbrechen',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close)),
                          ]),
                          Flexible(
                              child: SingleChildScrollView(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                    style: AppButtonStyles.primary(context),
                                    onPressed: _busy
                                        ? null
                                        : () => _run(
                                            widget.pickFile ??
                                                RouteTransferIo.pick,
                                            file: true),
                                    icon:
                                        const Icon(Icons.folder_open_outlined),
                                    label: Text(
                                        _english
                                            ? 'Choose GPX file'
                                            : 'GPX-Datei auswählen',
                                        textAlign: TextAlign.center)),
                                const SizedBox(height: 8),
                                Text(
                                    _english
                                        ? 'One continuous track · max. 4 MB'
                                        : 'Ein durchgehender Track · max. 4 MB',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Row(children: [
                                      const Expanded(child: Divider()),
                                      Flexible(
                                          flex: 4,
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              child: Text(
                                                  _english
                                                      ? 'or from RadlNavi'
                                                      : 'oder aus RadlNavi',
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall))),
                                      const Expanded(child: Divider()),
                                    ])),
                                OutlinedButton.icon(
                                    onPressed: _busy ? null : _scan,
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: Text(_english
                                        ? 'Scan QR code'
                                        : 'QR-Code scannen')),
                                const SizedBox(height: 16),
                                TextField(
                                    controller: _link,
                                    enabled: !_busy,
                                    maxLength: 2048,
                                    keyboardType: TextInputType.url,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textInputAction: TextInputAction.go,
                                    onSubmitted: (_) {
                                      if (!_busy) _openLink();
                                    },
                                    decoration: InputDecoration(
                                        labelText: _english
                                            ? 'Route link'
                                            : 'Routenlink',
                                        hintText:
                                            'https://radlnavi.munichways.de/r/…',
                                        counterText: '',
                                        suffixIcon: IconButton(
                                            tooltip: _english
                                                ? 'Paste from clipboard'
                                                : 'Aus Zwischenablage einfügen',
                                            onPressed: _busy ? null : _paste,
                                            icon: const Icon(
                                                Icons.content_paste)),
                                        border: const OutlineInputBorder())),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                    style: AppButtonStyles.secondary(context),
                                    onPressed: _busy ? null : _openLink,
                                    icon: const Icon(Icons.link),
                                    label: Text(
                                        _english ? 'Load link' : 'Link laden')),
                                TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => launchUrl(
                                            Uri.parse(
                                                'https://radlnavi.munichways.de/'),
                                            mode:
                                                LaunchMode.externalApplication),
                                    icon:
                                        const Icon(Icons.open_in_new, size: 18),
                                    label: Text(_english
                                        ? 'Go to RadlNavi'
                                        : 'zu RadlNavi')),
                                if (_busy) ...[
                                  const SizedBox(height: 16),
                                  const LinearProgressIndicator(),
                                  const SizedBox(height: 8),
                                  Text(_english
                                      ? 'Opening route …'
                                      : 'Route wird geöffnet …'),
                                ],
                                if (_error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Semantics(
                                          liveRegion: true,
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.info_outline,
                                                    size: 20,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: Text(_error!,
                                                        style: TextStyle(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .error))),
                                              ]))),
                              ]))),
                        ])))),
      );
}
