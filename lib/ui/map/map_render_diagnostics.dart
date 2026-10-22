import 'dart:async';

/// Bounded, in-memory evidence for native map stalls. Records no coordinates,
/// route names or error messages and never times out or retries native work.
class MapRenderDiagnostics {
  MapRenderDiagnostics({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const maximumEvents = 16;
  static const maximumPendingDetails = 16;
  final DateTime Function() _now;
  final List<String> _events = [];
  final Map<Object, MapEntry<String, DateTime>> _active = {};
  int _started = 0;
  int _completed = 0;
  int _failed = 0;
  DateTime? _lastCameraMove;
  DateTime? _lastCameraIdle;
  DateTime? _lastMapIdle;

  void record(String event) {
    _events.add('${_now().toUtc().toIso8601String()} $event');
    if (_events.length > maximumEvents) _events.removeAt(0);
  }

  void cameraMoved() => _lastCameraMove = _now();
  void cameraIdle() => _lastCameraIdle = _now();
  void mapIdle() => _lastMapIdle = _now();

  Future<T> track<T>(String operation, Future<T> Function() run) async {
    final token = Object();
    if (_active.length < maximumPendingDetails) {
      _active[token] = MapEntry(operation, _now());
    }
    _started++;
    record('$operation: start');
    try {
      final result = await run();
      _completed++;
      record('$operation: complete');
      return result;
    } catch (error) {
      _failed++;
      record('$operation: failed (${error.runtimeType})');
      rethrow;
    } finally {
      _active.remove(token);
    }
  }

  Map<String, String> snapshot({required bool english}) {
    String t(String de, String en) => english ? en : de;
    String timestamp(DateTime? time) => time?.toUtc().toIso8601String() ?? '—';
    final pendingCount = _started - _completed - _failed;
    final pending = [
      for (final entry in _active.values)
        '${entry.key} (${timestamp(entry.value)})',
      if (pendingCount > _active.length)
        '+ ${pendingCount - _active.length} ${t('weitere', 'more')}',
    ];
    return {
      t('Native Kartenaufrufe (Start/Erfolg/Fehler)',
              'Native map calls (started/completed/failed)'):
          '$_started/$_completed/$_failed',
      t('Ausstehende Kartenaufrufe', 'Pending map calls'):
          pending.isEmpty ? '—' : pending.join('\n'),
      t('Letzte native Kamerabewegung (UTC)', 'Last native camera move (UTC)'):
          timestamp(_lastCameraMove),
      t('Letztes natives Kameraende (UTC)', 'Last native camera idle (UTC)'):
          timestamp(_lastCameraIdle),
      t('Letzter nativer Karten-Leerlauf (UTC)', 'Last native map idle (UTC)'):
          timestamp(_lastMapIdle),
      t('Letzte Kartenereignisse', 'Recent map events'): _events.join('\n'),
    };
  }
}
