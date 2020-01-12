import 'package:ansicolor/ansicolor.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

enum LogTag {
  API,
  API_SYNC,
  CAMERA,
  DATABASE,
  INTERNAL,
  LOCATION,
  MEDIA_MANAGER,
  MIDI,
  OFFLINE,
  PERMISSION,
  SERVICE
}

class Log {
  // FIXME smoreau: ask Mathieu what is the global app variable to replace when bootstrap flutter-mix
  final Logger log = new Logger('AppFlutterMix');
  static final Log _instance = Log._privateConstructor();

  Log._privateConstructor();

  factory Log() {
    return _instance;
  }

  /// Initialize logger level (called from main)
  /// Examples
  /// - log all messages (may be verbose): Log().initLogger();
  /// - log INFO and more important messages: Log().initLogger(Level.INFO);
  initLogger([Level level = Level.ALL]) {
    Logger.root.level = level;
    Logger.root.onRecord.listen((LogRecord rec) {
      final levelPadded = rec.level.name.padRight(7);
      print('$levelPadded: ${rec.time}: ${rec.message}');
    });

    Log().log.info('Initialising logs for ${kReleaseMode ? 'RELEASE' : 'DEBUG'} with level ${level.name}');
  }
  
  static String _getTag(LogTag tag) {
    return 'MBZ_' + describeEnum(tag);
  }

  static v(LogTag tag, String message) {
    Log().log.finest('[${_getTag(tag)}]: $message');
  }

  static d(LogTag tag, String message) {
    Log().log.fine('[${_getTag(tag)}]: $message');
  }

  static i(LogTag tag, String message) {
    Log().log.info('[${_getTag(tag)}]: $message');
  }

  static w(LogTag tag, String message) {
    Log().log.warning('[${_getTag(tag)}]: $message');
  }

  static e(LogTag tag, String message) {
    AnsiPen red = AnsiPen()..red();
    Log().log.severe(red('[${_getTag(tag)}]: $message'));
  }
}
