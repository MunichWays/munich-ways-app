import 'package:logger/logger.dart';

var log = Logger(
  printer: CustomPrinter(),
);

class CustomPrinter extends PrettyPrinter {
  static final stackTraceRegex = RegExp(r'#[0-9]+[\s]+(.+) \(([^\s]+)\)');
  static final levelPrefixes = {
    Level.verbose: '[V]',
    Level.debug: '[D]',
    Level.info: '[I]',
    Level.warning: '[W]',
    Level.error: '[E]',
    Level.wtf: '[WTF]',
  };

  CustomPrinter() : super(methodCount: 1, printTime: true);

  String formatStackTrace(StackTrace stackTrace, int methodCount) {
    var lines = stackTrace.toString().split("\n");

    var formatted = <String>[];
    var count = 0;
    for (var line in lines) {
      var match = stackTraceRegex.matchAsPrefix(line);
      if (match != null) {
        if (match.group(2).startsWith('package:logger')) {
          continue;
        }
//        var newLine = ("#$count   ${match.group(1)} (${match.group(2)})");
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
  String getTime() {
    String _threeDigits(int n) {
      if (n >= 100) return "$n";
      if (n >= 10) return "0$n";
      return "00$n";
    }

    String _twoDigits(int n) {
      if (n >= 10) return "$n";
      return "0$n";
    }

    var now = DateTime.now();
    String h = _twoDigits(now.hour);
    String min = _twoDigits(now.minute);
    String sec = _twoDigits(now.second);
    String ms = _threeDigits(now.millisecond);
    return "$h:$min:$sec.$ms";
  }

  @override
  formatAndPrint(Level level, String message, String time, String error,
      String stacktrace) {
    println("$time${levelPrefixes[level]}$stacktrace $message${error ?? ''}");
  }
}
