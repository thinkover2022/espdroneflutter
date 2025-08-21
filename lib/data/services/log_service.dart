import 'dart:async';
import 'dart:typed_data';
import 'package:espdroneflutter/data/models/crtp_packet.dart';
import 'package:espdroneflutter/data/models/log_packet.dart';

/// Function type for sending CRTP packets
typedef PacketSender = void Function(CrtpPacket packet);

/// Telemetry data model
class TelemetryData {
  final double? height;           // stateEstimate.z
  final double? batteryVoltage;   // pm.vbat
  final int? batteryLevel;        // pm.batteryLevel
  final double? roll;             // stateEstimate.roll
  final double? pitch;            // stateEstimate.pitch
  final double? yaw;              // stateEstimate.yaw
  final DateTime timestamp;
  
  const TelemetryData({
    this.height,
    this.batteryVoltage,
    this.batteryLevel,
    this.roll,
    this.pitch,
    this.yaw,
    required this.timestamp,
  });
  
  TelemetryData copyWith({
    double? height,
    double? batteryVoltage,
    int? batteryLevel,
    double? roll,
    double? pitch,
    double? yaw,
  }) {
    return TelemetryData(
      height: height ?? this.height,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      roll: roll ?? this.roll,
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
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
  int _logCount = 0;
  int _currentTocIndex = 0;
  
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
  
  /// Initialize LOG system and request telemetry data
  Future<void> initialize() async {
    if (_isInitialized) {
      print('LOG service already initialized, skipping...');
      return;
    }
    
    print('Initializing LOG service...');
    _statusController.add('Initializing LOG system...');
    
    // Reset state for clean initialization
    _logVariables.clear();
    _telemetryBlockVariables.clear();
    _currentTocIndex = 0;
    _logCount = 0;
    _isRunning = false;
    
    // Step 1: Request TOC info
    _requestTocInfo();
  }
  
  /// Stop telemetry logging
  void stop() {
    if (!_isRunning) return;
    
    print('Stopping telemetry logging...');
    _statusController.add('Stopping telemetry...');
    
    // Stop the telemetry block
    final stopPacket = LogStopBlockPacket(_telemetryBlockId);
    _sendPacket(stopPacket);
    _isRunning = false;
  }
  
  /// Process incoming CRTP LOG packets
  void processIncomingPacket(CrtpPacket packet) {
    if (packet.header.port != CrtpPort.log) return;
    
    print('Processing LOG packet - Channel: ${packet.header.channel}, Length: ${packet.payload.length}');
    
    switch (packet.header.channel) {
      case 0: // TOC channel
        print('Processing TOC channel packet');
        _processTocPacket(packet);
        break;
      case 1: // Control channel
        print('Processing Control channel packet');
        _processControlPacket(packet);
        break;
      case 2: // Log data channel
        print('Processing Log data channel packet');
        _processLogDataPacket(packet);
        break;
      default:
        print('Unknown LOG channel: ${packet.header.channel}');
        break;
    }
  }
  
  void _requestTocInfo() {
    print('Requesting TOC info...');
    final tocInfoPacket = LogTocInfoPacket();
    print('Sending TOC info packet: Port=${tocInfoPacket.header.port.name}, Channel=${tocInfoPacket.header.channel}');
    _sendPacket(tocInfoPacket);
    print('TOC info packet sent');
  }
  
  void _processTocPacket(CrtpPacket packet) {
    if (packet.payload.isEmpty) {
      print('Received empty TOC packet');
      return;
    }
    
    final command = packet.payload[0];
    print('Processing TOC packet - Command: $command, Length: ${packet.payload.length}');
    print('Payload bytes: ${packet.payload.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    
    switch (command) {
      case 3: // CMD_GET_INFO_V2 response
        print('Received CMD_GET_INFO_V2 response');
        if (packet.payload.length >= 9) {
          _logCount = ByteData.sublistView(packet.payload, 1, 3).getUint16(0, Endian.little);
          print('LOG system has $_logCount variables');
          _statusController.add('Found $_logCount log variables');
          
          // Start requesting individual TOC items
          _currentTocIndex = 0;
          _requestNextTocItem();
        } else {
          print('TOC info response too short: ${packet.payload.length} bytes');
        }
        break;
        
      case 2: // CMD_GET_ITEM_V2 response
        print('Received CMD_GET_ITEM_V2 response');
        _processTocItemResponse(packet);
        break;
        
      default:
        print('Unknown TOC command: $command');
        break;
    }
  }
  
  void _requestNextTocItem() {
    print('_requestNextTocItem called: current=$_currentTocIndex, total=$_logCount');
    
    if (_currentTocIndex >= _logCount) {
      // All TOC items received, now create telemetry block
      print('All TOC items processed ($_currentTocIndex/$_logCount), creating telemetry block...');
      _createTelemetryBlock();
      return;
    }
    
    print('Requesting TOC item $_currentTocIndex...');
    final itemPacket = LogTocItemPacket(_currentTocIndex);
    _sendPacket(itemPacket);
    
    // Add timeout safety mechanism
    Timer(Duration(seconds: 2), () {
      if (_currentTocIndex < _logCount && !_isInitialized) {
        print('TOC request timeout for item $_currentTocIndex, retrying...');
        _requestNextTocItem();
      }
    });
  }
  
  void _processTocItemResponse(CrtpPacket packet) {
    print('Processing TOC item response for index $_currentTocIndex - Payload length: ${packet.payload.length}');
    
    if (packet.payload.length < 4) {
      print('TOC item $_currentTocIndex response too short (${packet.payload.length} bytes), moving to next');
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
        print('Invalid log type value: $logTypeValue');
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
        print('TOC item $_currentTocIndex: ID=$varId, ${variable.fullName}, Type=${logType.name}');
        
        // Check if this is a variable we want for telemetry
        if (_isTelemetryVariable(variable)) {
          _telemetryBlockVariables.add(variable);
          print('*** FOUND TELEMETRY VARIABLE: ${variable.fullName} ***');
        }
      } else {
        print('TOC item $_currentTocIndex: Failed to parse group/name from fullText="$fullText"');
      }
    } catch (e) {
      print('Error parsing TOC item $_currentTocIndex: $e');
      print('Payload bytes: ${packet.payload.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    }
    
    _currentTocIndex++;
    print('Requesting next TOC item: $_currentTocIndex of $_logCount');
    _requestNextTocItem();
  }
  
  bool _isTelemetryVariable(LogVariable variable) {
    const targetVariables = [
      'stateEstimate.z',      // Height
      'stateEstimate.roll',   // Roll angle
      'stateEstimate.pitch',  // Pitch angle  
      'stateEstimate.yaw',    // Yaw angle
      'pm.vbat',              // Battery voltage
      'pm.batteryLevel',      // Battery level
    ];
    
    return targetVariables.contains(variable.fullName);
  }
  
  void _createTelemetryBlock() {
    if (_telemetryBlockVariables.isEmpty) {
      print('No telemetry variables found!');
      _statusController.add('No telemetry variables available');
      return;
    }
    
    print('Creating telemetry block with ${_telemetryBlockVariables.length} variables');
    _statusController.add('Creating telemetry block...');
    
    final configs = _telemetryBlockVariables.map((variable) => 
      LogVariableConfig(
        variableId: variable.id,
        logType: variable.type,
      )
    ).toList();
    
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
          print('Telemetry block created successfully');
          _statusController.add('Starting telemetry...');
          _startTelemetryBlock();
        } else {
          print('Failed to create telemetry block: $result');
          _statusController.add('Failed to create telemetry block');
        }
        break;
        
      case 3: // CONTROL_START_BLOCK response
        if (result == 0) {
          print('Telemetry logging started');
          _statusController.add('Telemetry active');
          _isInitialized = true;
          _isRunning = true;
        } else {
          print('Failed to start telemetry block: $result');
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
    
    // Extract telemetry values from log data
    final height = logData.data['stateEstimate.z'] as double?;
    final roll = logData.data['stateEstimate.roll'] as double?;
    final pitch = logData.data['stateEstimate.pitch'] as double?;
    final yaw = logData.data['stateEstimate.yaw'] as double?;
    final batteryVoltage = logData.data['pm.vbat'] as double?;
    final batteryLevel = logData.data['pm.batteryLevel'] as int?;
    
    // Update current telemetry data
    _currentTelemetry = _currentTelemetry.copyWith(
      height: height,
      roll: roll,
      pitch: pitch,
      yaw: yaw,
      batteryVoltage: batteryVoltage,
      batteryLevel: batteryLevel,
    );
    
    // Broadcast the update
    _telemetryController.add(_currentTelemetry);
    
    // Debug output
    if (height != null || batteryVoltage != null) {
      print('Telemetry: H=${height?.toStringAsFixed(2)}m BAT=${batteryVoltage?.toStringAsFixed(1)}V ${batteryLevel ?? 0}%');
    }
  }
  
  void dispose() {
    print('Disposing LOG service...');
    stop();
    
    // Reset initialization state
    _isInitialized = false;
    _isRunning = false;
    
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
    
    print('LOG service disposed');
  }
}