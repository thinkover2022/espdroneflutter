/// Application logging utility with configurable log levels
class AppLogger {
  static const String _tag = 'ESP-Drone';
  
  // Log levels
  static const int _OFF = 0;
  static const int _ERROR = 1;
  static const int _WARN = 2;
  static const int _INFO = 3;
  static const int _DEBUG = 4;
  static const int _VERBOSE = 5;
  
  // Current log level - change this to control verbosity
  static int _currentLogLevel = _INFO; // Default to INFO level
  
  /// Set the global log level
  /// OFF(0), ERROR(1), WARN(2), INFO(3), DEBUG(4), VERBOSE(5)
  static void setLogLevel(int level) {
    _currentLogLevel = level;
  }
  
  /// Get current log level
  static int get logLevel => _currentLogLevel;
  
  /// Log error messages (always shown unless OFF)
  static void error(String component, String message) {
    if (_currentLogLevel >= _ERROR) {
      print('E/$_tag-$component: $message');
    }
  }
  
  /// Log warning messages
  static void warn(String component, String message) {
    if (_currentLogLevel >= _WARN) {
      print('W/$_tag-$component: $message');
    }
  }
  
  /// Log info messages
  static void info(String component, String message) {
    if (_currentLogLevel >= _INFO) {
      print('I/$_tag-$component: $message');
    }
  }
  
  /// Log debug messages
  static void debug(String component, String message) {
    if (_currentLogLevel >= _DEBUG) {
      print('D/$_tag-$component: $message');
    }
  }
  
  /// Log verbose messages (for detailed debugging)
  static void verbose(String component, String message) {
    if (_currentLogLevel >= _VERBOSE) {
      print('V/$_tag-$component: $message');
    }
  }
  
  /// Quick log level setters
  static void setQuiet() => setLogLevel(_ERROR);
  static void setNormal() => setLogLevel(_INFO);
  static void setDebug() => setLogLevel(_DEBUG);
  static void setVerbose() => setLogLevel(_VERBOSE);
  static void setSilent() => setLogLevel(_OFF);
}

/// Logger component names
class LogComponent {
  static const String hlCommander = 'HLCmd';
  static const String logService = 'LogSvc';
  static const String telemetry = 'Telem';
  static const String connection = 'Conn';
  static const String ui = 'UI';
  static const String flight = 'Flight';
}