import 'package:logger/logger.dart';

var log = Logger(
  printer: CustomPrinter(),
);

/// One Line Logprinter
///
/// Output looks like this:
/// 19:59:43.553[D]package:munich_ways/ui/map/map_screen_model.dart:32:9 <message>
class CustomPrinter extends PrettyPrinter {
  static final stackTraceRegex = RegExp(r'#[0-9]+[\s]+(.+) \(([^\s]+)\)');
  static final levelPrefixes = {
    Level.trace: '[T]',
    Level.debug: '[D]',
    Level.info: '[I]',
    Level.warning: '[W]',
    Level.error: '[E]',
    Level.fatal: '[F]',
  };

  CustomPrinter() : super(methodCount: 1, printTime: true);

  @override
  List<String> log(LogEvent event) {
    var messageStr = stringifyMessage(event.message);

    String? stackTraceStr;
    if (event.stackTrace == null) {
      if ((methodCount ?? 0) > 0) {
        stackTraceStr = formatStackTrace(StackTrace.current, methodCount ?? 0);
      }
    } else if ((errorMethodCount ?? 0) > 0) {
      stackTraceStr = formatStackTrace(event.stackTrace, errorMethodCount ?? 0);
    }

    var errorStr = event.error?.toString();

    String? timeStr;
    if (printTime) {
      timeStr = getTime(DateTime.now());
    }
    return [
      "$timeStr${levelPrefixes[event.level]}$stackTraceStr $messageStr${errorStr ?? ''}"
    ];
  }

  String? formatStackTrace(StackTrace? stackTrace, int? methodCount) {
    var lines = stackTrace.toString().split("\n");

    var formatted = <String>[];
    var count = 0;
    for (var line in lines) {
      var match = stackTraceRegex.matchAsPrefix(line);
      if (match != null) {
        if (match.group(2)!.startsWith('package:logger') ||
            match
                .group(2)!
                .startsWith('package:munich_ways/common/logger_setup.dart')) {
          continue;
        }
        var newLine = ("${match.group(2)}");
        formatted.add(newLine.replaceAll('<anonymous closure>', '()'));
        if (++count == methodCount) {
          break;
        }
      } else {
        formatted.add(line);
      }
    }

    if (formatted.isEmpty) {
      return null;
    } else {
      return formatted.join('\n');
    }
  }

  @override
  String getTime(DateTime time) {
    String _threeDigits(int n) {
      if (n >= 100) return "$n";
      if (n >= 10) return "0$n";
      return "00$n";
    }

    String _twoDigits(int n) {
      if (n >= 10) return "$n";
      return "0$n";
    }

    String h = _twoDigits(time.hour);
    String min = _twoDigits(time.minute);
    String sec = _twoDigits(time.second);
    String ms = _threeDigits(time.millisecond);
    return "$h:$min:$sec.$ms";
  }
}
