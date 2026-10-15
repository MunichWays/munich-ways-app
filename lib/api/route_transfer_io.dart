import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:munich_ways/model/route_transfer.dart';

class ExpiredRouteLinkException extends FormatException {
  const ExpiredRouteLinkException()
      : super('Route link expired or unavailable');
}

class RouteTransferIo {
  static final instance = RouteTransferIo();
  static const channel = MethodChannel('com.munichways/route_transfer');
  final _incoming = StreamController<Future<RouteTransfer>>.broadcast();
  Stream<Future<RouteTransfer>> get incoming => _incoming.stream;
  StreamSubscription<Uri>? _links;
  bool _started = false;
  Uri? _lastLink;
  DateTime? _lastLinkAt;
  void start() {
    if (_started) return;
    _started = true;
    final links = AppLinks();
    _links = links.uriLinkStream.listen((uri) {
      if (sharedId(uri) == null) return;
      final now = DateTime.now();
      if (_lastLink == uri &&
          _lastLinkAt != null &&
          now.difference(_lastLinkAt!) < const Duration(seconds: 2)) return;
      _lastLink = uri;
      _lastLinkAt = now;
      _incoming.add(loadLink(uri));
    }, onError: (_) {/* Explicit retry remains available through import. */});
    channel.setMethodCallHandler((call) async {
      if (call.method == 'gpx') _incoming.add(_decodeNative(call.arguments));
    });
    channel.invokeMethod<Object?>('initialGpx').then((value) {
      if (value != null) _incoming.add(_decodeNative(value));
    }).catchError((_) {
      /* Platforms without the native bridge use the picker. */
    });
  }

  static Uri? parseLink(String text) {
    if (text.length > 2048) return null;
    final uri = Uri.tryParse(text.trim());
    return uri != null && sharedId(uri) != null ? uri : null;
  }

  static String? sharedId(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host != 'radlnavi.munichways.de' ||
        (uri.hasPort && uri.port != 443) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) return null;
    final match = RegExp(r'^/r/([A-Za-z0-9_-]{22,64})/?$').firstMatch(uri.path);
    return match?.group(1);
  }

  static Future<RouteTransfer> _decodeNative(Object? value) async {
    if (value is! Uint8List)
      throw const FormatException('GPX could not be opened (maximum 4 MB)');
    return decode(value);
  }

  static RouteTransfer decode(List<int> bytes) {
    if (bytes.length > RouteTransfer.maxBytes)
      throw const FormatException('GPX exceeds 4 MB');
    return RouteTransfer.fromGpx(utf8.decode(bytes));
  }

  static Future<RouteTransfer?> pick() async {
    final file = await FilePicker.pickFile(
        type: FileType.custom, allowedExtensions: ['gpx']);
    if (file == null) return null;
    final bytes = <int>[];
    await for (final chunk in file.readAsByteStream()) {
      bytes.addAll(chunk);
      if (bytes.length > RouteTransfer.maxBytes)
        throw const FormatException('GPX exceeds 4 MB');
    }
    return decode(bytes);
  }

  void stop() {
    _links?.cancel();
    channel.setMethodCallHandler(null);
    _started = false;
  }

  static Future<RouteTransfer> loadLink(Uri uri, {http.Client? client}) async {
    final id = sharedId(uri);
    if (id == null) throw const FormatException('Unsupported route link');
    final own = client == null;
    final connection = client ?? http.Client();
    try {
      // No arbitrary URL from a file or deep link is ever fetched.
      final request = http.Request(
          'GET', Uri.https('api.radlnavi.munichways.de', '/shared_routes/$id'))
        ..followRedirects = false;
      final response =
          await connection.send(request).timeout(const Duration(seconds: 20));
      if (response.statusCode == 404 || response.statusCode == 410)
        throw const ExpiredRouteLinkException();
      if (response.statusCode != 200)
        throw const HttpException(
            'Route could not be loaded. Open the link again to retry.');
      final bytes = <int>[];
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > RouteTransfer.maxBytes)
          throw const FormatException('Route exceeds 4 MB');
      }
      return RouteTransfer.fromJson(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    } finally {
      if (own) connection.close();
    }
  }

  static Future<void> export(RouteTransfer transfer, {Rect? origin}) async {
    final data = Uint8List.fromList(utf8.encode(transfer.toGpx()));
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(data, mimeType: 'application/gpx+xml')],
      fileNameOverrides: [RouteTransfer.gpxFilename(transfer.name)],
      sharePositionOrigin: origin,
    ));
  }
}
