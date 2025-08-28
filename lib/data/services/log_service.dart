import 'dart:async';
import 'dart:typed_data';
import 'package:espdroneflutter/data/models/crtp_packet.dart';
import 'package:espdroneflutter/data/models/log_packet.dart';
import 'package:espdroneflutter/utils/app_logger.dart';

/// Function type for sending CRTP packets
typedef PacketSender = void Function(CrtpPacket packet);

/// Telemetry data model
class TelemetryData {
  final double? height;           // stateEstimate.z
  final double? verticalVelocity; // stateEstimate.vz
  final double? batteryVoltage;   // pm.vbat
  final int? batteryLevel;        // pm.batteryLevel
  final double? roll;             // stateEstimate.roll
  final double? pitch;            // stateEstimate.pitch
  final double? yaw;              // stateEstimate.yaw
  final double? accelerationZ;    // acc.z
  final DateTime timestamp;
  
  const TelemetryData({
    this.height,
    this.verticalVelocity,
    this.batteryVoltage,
    this.batteryLevel,
    this.roll,
    this.pitch,
    this.yaw,
    this.accelerationZ,
    required this.timestamp,
  });
  
  TelemetryData copyWith({
    double? height,
    double? verticalVelocity,
    double? batteryVoltage,
    int? batteryLevel,
    double? roll,
    double? pitch,
    double? yaw,
    double? accelerationZ,
  }) {
    return TelemetryData(
      height: height ?? this.height,
      verticalVelocity: verticalVelocity ?? this.verticalVelocity,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      roll: roll ?? this.roll,
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
      accelerationZ: accelerationZ ?? this.accelerationZ,
      timestamp: DateTime.now(),
    );
  }
  
  @override
  String toString() => 'TelemetryData(h: $height, bat: $batteryVoltage V, level: $batteryLevel%)';
}

/// ESP-Drone LOG service for telemetry data
class LogService {
  final PacketSender _sendPacket;
  final StreamController<TelemetryData> _telemetryController = 
      StreamController<TelemetryData>.broadcast();
  final StreamController<String> _statusController = 
      StreamController<String>.broadcast();
  
  // LOG system state
  final Map<int, LogVariable> _logVariables = {};
  final List<LogVariable> _telemetryBlockVariables = [];
  bool _isInitialized = false;
  bool _isRunning = false;
  bool _isTocDiscoveryComplete = false;
  bool _isDisposed = false;
  int _logCount = 0;
  int _currentTocIndex = 0;
  Timer? _tocTimeoutTimer;
  
  // Telemetry block configuration
  static const int _telemetryBlockId = 1;
  static const int _telemetryPeriodMs = 100; // 10Hz
  
  // Current telemetry data
  TelemetryData _currentTelemetry = TelemetryData(timestamp: DateTime.now());
  
  LogService(this._sendPacket);
  
  /// Stream of telemetry data updates
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;
  
  /// Stream of status messages
  Stream<String> get statusStream => _statusController.stream;
  
  /// Current telemetry data
  TelemetryData get currentTelemetry => _currentTelemetry;
  
  /// Whether LOG system is fully initialized and ready
  bool get isInitialized => _isInitialized;
  
  /// Whether telemetry logging is currently running
  bool get isRunning => _isRunning;
  
  /// Initialize LOG system and request telemetry data
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info(LogComponent.logService, 'LOG service already initialized, skipping...');
      return;
    }
    
    AppLogger.info(LogComponent.logService, 'Initializing LOG service...');
    _statusController.add('Initializing LOG system...');
    
    // Reset state for clean initialization
    _logVariables.clear();
    _telemetryBlockVariables.clear();
    _currentTocIndex = 0;
    _logCount = 0;
    _isRunning = false;
    _isTocDiscoveryComplete = false;
    _isDisposed = false;
    
    // Cancel any existing timeout timer
    _tocTimeoutTimer?.cancel();
    _tocTimeoutTimer = null;
    
    // Step 1: Request TOC info
    _requestTocInfo();
  }
  
  /// Stop telemetry logging
  void stop() {
    if (!_isRunning) return;
    
    AppLogger.info(LogComponent.logService, 'Stopping telemetry logging...');
    _statusController.add('Stopping telemetry...');
    
    // Stop the telemetry block
    final stopPacket = LogStopBlockPacket(_telemetryBlockId);
    _sendPacket(stopPacket);
    _isRunning = false;
  }
  
  /// Process incoming CRTP LOG packets
  void processIncomingPacket(CrtpPacket packet) {
    if (_isDisposed || packet.header.port != CrtpPort.log) return;
    
    AppLogger.verbose(LogComponent.logService, 'Processing LOG packet - Channel: ${packet.header.channel}, Length: ${packet.payload.length}');
    
    switch (packet.header.channel) {
      case 0: // TOC channel
        AppLogger.debug(LogComponent.logService, 'Processing TOC channel packet');
        _processTocPacket(packet);
        break;
      case 1: // Control channel
        AppLogger.debug(LogComponent.logService, 'Processing Control channel packet');
        _processControlPacket(packet);
        break;
      case 2: // Log data channel
        AppLogger.verbose(LogComponent.logService, 'Processing Log data channel packet');
        _processLogDataPacket(packet);
        break;
      default:
        AppLogger.warn(LogComponent.logService, 'Unknown LOG channel: ${packet.header.channel}');
        break;
    }
  }
  
  void _requestTocInfo() {
    AppLogger.debug(LogComponent.logService, 'Requesting TOC info...');
    final tocInfoPacket = LogTocInfoPacket();
    AppLogger.verbose(LogComponent.logService, 'Sending TOC info packet: Port=${tocInfoPacket.header.port.name}, Channel=${tocInfoPacket.header.channel}');
    _sendPacket(tocInfoPacket);
    AppLogger.verbose(LogComponent.logService, 'TOC info packet sent');
  }
  
  void _processTocPacket(CrtpPacket packet) {
    if (packet.payload.isEmpty) {
      AppLogger.warn(LogComponent.logService, 'Received empty TOC packet');
      return;
    }
    
    final command = packet.payload[0];
    AppLogger.verbose(LogComponent.logService, 'Processing TOC packet - Command: $command, Length: ${packet.payload.length}');
    AppLogger.verbose(LogComponent.logService, 'Payload bytes: ${packet.payload.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    
    switch (command) {
      case 3: // CMD_GET_INFO_V2 response
        AppLogger.debug(LogComponent.logService, 'Received CMD_GET_INFO_V2 response');
        if (packet.payload.length >= 9) {
          _logCount = ByteData.sublistView(packet.payload, 1, 3).getUint16(0, Endian.little);
          AppLogger.info(LogComponent.logService, 'LOG system has $_logCount variables');
          _statusController.add('Found $_logCount log variables');
          
          // Start requesting individual TOC items
          _currentTocIndex = 0;
          _requestNextTocItem();
        } else {
          AppLogger.error(LogComponent.logService, 'TOC info response too short: ${packet.payload.length} bytes');
        }
        break;
        
      case 2: // CMD_GET_ITEM_V2 response
        AppLogger.debug(LogComponent.logService, 'Received CMD_GET_ITEM_V2 response');
        _processTocItemResponse(packet);
        break;
        
      default:
        AppLogger.warn(LogComponent.logService, 'Unknown TOC command: $command');
        break;
    }
  }
  
  void _requestNextTocItem() {
    AppLogger.verbose(LogComponent.logService, '_requestNextTocItem called: current=$_currentTocIndex, total=$_logCount');
    
    if (_currentTocIndex >= _logCount || _isTocDiscoveryComplete) {
      if (!_isTocDiscoveryComplete) {
        // All TOC items received, now create telemetry block
        AppLogger.info(LogComponent.logService, 'All TOC items processed ($_currentTocIndex/$_logCount), creating telemetry block...');
        _isTocDiscoveryComplete = true;
        _createTelemetryBlock();
      } else {
        AppLogger.debug(LogComponent.logService, 'TOC Discovery already complete, ignoring request');
      }
      return;
    }
    
    AppLogger.verbose(LogComponent.logService, 'Requesting TOC item $_currentTocIndex...');
    final itemPacket = LogTocItemPacket(_currentTocIndex);
    _sendPacket(itemPacket);
    
    // Cancel previous timeout timer if exists
    _tocTimeoutTimer?.cancel();
    
    // Add timeout safety mechanism only for incomplete TOC discovery
    _tocTimeoutTimer = Timer(Duration(milliseconds: 500), () {
      if (!_isDisposed && _currentTocIndex < _logCount && !_isTocDiscoveryComplete && !_isInitialized) {
        AppLogger.warn(LogComponent.logService, 'TOC request timeout for item $_currentTocIndex, retrying...');
        _requestNextTocItem();
      }
    });
  }
  
  void _processTocItemResponse(CrtpPacket packet) {
    AppLogger.verbose(LogComponent.logService, 'Processing TOC item response for index $_currentTocIndex - Payload length: ${packet.payload.length}');
    
    if (packet.payload.length < 4) {
      AppLogger.warn(LogComponent.logService, 'TOC item $_currentTocIndex response too short (${packet.payload.length} bytes), moving to next');
      _currentTocIndex++;
      _requestNextTocItem();
      return;
    }
    
    try {
      // Parse variable ID from bytes 1-2 (little-endian)
      final varId = ByteData.sublistView(packet.payload, 1, 3).getUint16(0, Endian.little);
      // Parse log type from byte 3 (1-based in protocol, convert to 0-based for enum)
      final logTypeValue = packet.payload[3];
      if (logTypeValue < 1 || logTypeValue > LogType.values.length) {
        AppLogger.error(LogComponent.logService, 'Invalid log type value: $logTypeValue');
        _currentTocIndex++;
        _requestNextTocItem();
        return;
      }
      final logType = LogType.values[logTypeValue - 1]; // Convert to 0-based index
      
      // Parse group and name from payload
      String fullText = String.fromCharCodes(packet.payload.sublist(4));
      final parts = fullText.split('\x00');
      if (parts.length >= 2) {
        final group = parts[0];
        final name = parts[1];
        
        final variable = LogVariable(
          id: varId,
          group: group,
          name: name,
          type: logType,
        );
        
        _logVariables[varId] = variable;
        AppLogger.verbose(LogComponent.logService, 'TOC item $_currentTocIndex: ID=$varId, ${variable.fullName}, Type=${logType.name}');
        
        // Check if this is a variable we want for telemetry
        if (_isTelemetryVariable(variable)) {
          _telemetryBlockVariables.add(variable);
          AppLogger.info(LogComponent.logService, 'Found telemetry variable: ${variable.fullName}');
        }
      } else {
        AppLogger.error(LogComponent.logService, 'TOC item $_currentTocIndex: Failed to parse group/name from fullText="$fullText"');
      }
    } catch (e) {
      AppLogger.error(LogComponent.logService, 'Error parsing TOC item $_currentTocIndex: $e');
      AppLogger.error(LogComponent.logService, 'Payload bytes: ${packet.payload.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    }
    
    _currentTocIndex++;
    AppLogger.verbose(LogComponent.logService, 'Requesting next TOC item: $_currentTocIndex of $_logCount');
    _requestNextTocItem();
  }
  
  bool _isTelemetryVariable(LogVariable variable) {
    // Reduce to essential variables only to avoid "block size exceeds maximum" error
    const targetVariables = [
      'stateEstimate.z',      // Height (essential for takeoff verification)
      'stateEstimate.vz',     // Vertical velocity (essential for motion verification)  
      'pm.vbat',              // Battery voltage (essential for safety)
      'pm.batteryLevel',      // Battery level (essential for safety)
      // Remove attitude and acceleration to reduce block size
      // 'stateEstimate.roll',   // Roll angle
      // 'stateEstimate.pitch',  // Pitch angle  
      // 'stateEstimate.yaw',    // Yaw angle
      // 'acc.z',                // Z-axis acceleration (for motion verification)
    ];
    
    return targetVariables.contains(variable.fullName);
  }
  
  void _createTelemetryBlock() {
    if (_telemetryBlockVariables.isEmpty) {
      AppLogger.error(LogComponent.logService, 'No telemetry variables found!');
      _statusController.add('No telemetry variables available');
      return;
    }
    
    AppLogger.info(LogComponent.logService, 'Creating telemetry block with ${_telemetryBlockVariables.length} variables');
    _statusController.add('Creating telemetry block...');
    
    // Debug: Log the variables being added to the block
    for (final variable in _telemetryBlockVariables) {
      AppLogger.info(LogComponent.logService, 'Adding variable: ${variable.fullName} (ID=${variable.id}, Type=${variable.type.name})');
    }
    
    final configs = _telemetryBlockVariables.map((variable) => 
      LogVariableConfig(
        variableId: variable.id,
        logType: variable.type,
      )
    ).toList();
    
    // Debug: Log packet details
    AppLogger.info(LogComponent.logService, 'Block ID: $_telemetryBlockId, Variable count: ${configs.length}');
    
    final createPacket = LogCreateBlockPacket(_telemetryBlockId, configs);
    _sendPacket(createPacket);
  }
  
  void _processControlPacket(CrtpPacket packet) {
    if (packet.payload.length < 3) return;
    
    final command = packet.payload[0];
    final blockId = packet.payload[1];
    final result = packet.payload[2];
    
    if (blockId != _telemetryBlockId) return;
    
    switch (command) {
      case 6: // CONTROL_CREATE_BLOCK_V2 response
        if (result == 0) {
          AppLogger.info(LogComponent.logService, 'Telemetry block created successfully');
          _statusController.add('Starting telemetry...');
          _startTelemetryBlock();
        } else {
          final errorMessage = _getLogErrorMessage(result);
          AppLogger.error(LogComponent.logService, 'Failed to create telemetry block: error $result - $errorMessage');
          _statusController.add('Failed to create telemetry block: $errorMessage');
        }
        break;
        
      case 3: // CONTROL_START_BLOCK response
        if (result == 0) {
          AppLogger.info(LogComponent.logService, 'Telemetry logging started');
          _statusController.add('Telemetry active');
          _isInitialized = true;
          _isRunning = true;
        } else {
          AppLogger.error(LogComponent.logService, 'Failed to start telemetry block: error $result');
          _statusController.add('Failed to start telemetry');
        }
        break;
    }
  }
  
  void _startTelemetryBlock() {
    final startPacket = LogStartBlockPacket(_telemetryBlockId, _telemetryPeriodMs);
    _sendPacket(startPacket);
  }
  
  void _processLogDataPacket(CrtpPacket packet) {
    final logData = parseLogDataPacket(packet, _telemetryBlockVariables);
    if (logData == null || logData.blockId != _telemetryBlockId) return;
    
    // Extract essential telemetry values from log data
    final height = logData.data['stateEstimate.z'] as double?;
    final verticalVelocity = logData.data['stateEstimate.vz'] as double?;
    final batteryVoltage = logData.data['pm.vbat'] as double?;
    final batteryLevel = logData.data['pm.batteryLevel'] as int?;
    
    // Update current telemetry data (keep existing roll/pitch/yaw/accelerationZ values)
    _currentTelemetry = _currentTelemetry.copyWith(
      height: height,
      verticalVelocity: verticalVelocity,
      batteryVoltage: batteryVoltage,
      batteryLevel: batteryLevel,
    );
    
    // Broadcast the update
    _telemetryController.add(_currentTelemetry);
    
    // Debug output with essential data
    if (height != null || batteryVoltage != null) {
      final vzStr = verticalVelocity != null ? ' Vz=${verticalVelocity.toStringAsFixed(2)}m/s' : '';
      AppLogger.debug(LogComponent.telemetry, 'H=${height?.toStringAsFixed(2)}m$vzStr BAT=${batteryVoltage?.toStringAsFixed(1)}V ${batteryLevel ?? 0}%');
    }
  }
  
  void dispose() {
    AppLogger.info(LogComponent.logService, 'Disposing LOG service...');
    
    // Mark as disposed to stop all ongoing operations
    _isDisposed = true;
    
    // Cancel timeout timer immediately
    _tocTimeoutTimer?.cancel();
    _tocTimeoutTimer = null;
    
    stop();
    
    // Reset initialization state
    _isInitialized = false;
    _isRunning = false;
    _isTocDiscoveryComplete = false;
    
    // Clear collections
    _logVariables.clear();
    _telemetryBlockVariables.clear();
    
    // Close streams safely
    if (!_telemetryController.isClosed) {
      _telemetryController.close();
    }
    if (!_statusController.isClosed) {
      _statusController.close();
    }
    
    AppLogger.info(LogComponent.logService, 'LOG service disposed');
  }
  
  /// Get human-readable error message for LOG error codes
  String _getLogErrorMessage(int errorCode) {
    switch (errorCode) {
      case 0: return 'Success';
      case 1: return 'Command not found';
      case 2: return 'Wrong number of arguments';
      case 3: return 'Argument out of range';
      case 4: return 'Generic error';
      case 5: return 'Operation in progress';
      case 6: return 'Operation not supported';
      case 7: return 'Table of Contents (TOC) not found';
      case 8: return 'Too many log blocks active';
      case 9: return 'Block already exists';
      case 10: return 'Block not found';
      case 11: return 'Block is currently running';
      case 12: return 'Block contains too many variables';
      case 13: return 'Variable not found';
      case 14: return 'Variable type mismatch';
      case 15: return 'Insufficient memory';
      case 16: return 'Block configuration invalid';
      case 17: return 'Block size exceeds maximum allowed';
      case 18: return 'Log system busy';
      case 19: return 'Log system not initialized';
      case 20: return 'Variable access denied';
      default: return 'Unknown error';
    }
  }
}