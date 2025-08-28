import 'dart:async';
import 'package:espdroneflutter/data/models/high_level_commander_packet.dart';
import 'package:espdroneflutter/data/models/crtp_packet.dart';
import 'package:espdroneflutter/utils/app_logger.dart';

/// Function type for sending CRTP packets
typedef PacketSender = void Function(CrtpPacket packet);

/// Response packet structure from ESP-Drone
class HighLevelCommandResponse {
  final int commandId;
  final int resultCode;
  final bool success;
  
  HighLevelCommandResponse({
    required this.commandId,
    required this.resultCode,
  }) : success = resultCode == 0;
  
  @override
  String toString() => 'HighLevelCommandResponse(cmd: $commandId, result: $resultCode, success: $success)';
}

/// Service for sending high-level commands to ESP-Drone
/// This service implements the same high-level commands available in the ESP-Drone firmware
class HighLevelCommanderService {
  static const int allGroups = 0; // Group mask for all drones
  
  // Default parameters
  static const double defaultTakeoffHeight = 0.3; // 30cm
  static const double defaultTakeoffDuration = 2.0; // 2 seconds
  static const double defaultLandingHeight = 0.0; // Ground level
  static const double defaultLandingDuration = 2.0; // 2 seconds

  final PacketSender _sendPacket;
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  final StreamController<HighLevelCommandResponse> _commandResponseController = 
      StreamController<HighLevelCommandResponse>.broadcast();

  HighLevelCommanderService(this._sendPacket);

  /// Stream of command response messages
  Stream<String> get responses => _responseController.stream;
  
  /// Stream of command responses from ESP-Drone
  Stream<HighLevelCommandResponse> get commandResponses => _commandResponseController.stream;
  
  /// Process incoming CRTP packets to extract command responses
  void processIncomingPacket(CrtpPacket packet) {
    // Debug: 모든 들어오는 패킷 로그 출력 (VERBOSE 레벨에서만 출력)
    AppLogger.verbose(LogComponent.hlCommander, 'Incoming packet - Port: ${packet.header.port.name} (0x${packet.header.port.value.toRadixString(16).padLeft(2, '0')}), Channel: ${packet.header.channel}, Payload length: ${packet.payload.length}');
    
    if (packet.payload.isNotEmpty) {
      AppLogger.verbose(LogComponent.hlCommander, 'Payload bytes: ${packet.payload.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    }
    
    if (packet.header.port == CrtpPort.setpointHl && packet.payload.length >= 4) {
      try {
        // ESP-Drone response packet structure: [original_cmd][original_data...][result_code]
        final commandId = packet.payload[0];
        final resultCode = packet.payload[3];
        
        final response = HighLevelCommandResponse(
          commandId: commandId,
          resultCode: resultCode,
        );
        
        AppLogger.info(LogComponent.hlCommander, 'High-level command response received: $response');
        _commandResponseController.add(response);
        
        // Also add to string responses for backward compatibility
        _responseController.add('Command $commandId response: ${response.success ? "SUCCESS" : "FAILED ($resultCode)"}');
      } catch (e) {
        AppLogger.error(LogComponent.hlCommander, 'Error processing high-level command response: $e');
      }
    } else {
      AppLogger.verbose(LogComponent.hlCommander, 'Packet does not match high-level response criteria (port: ${packet.header.port.name}, payload length: ${packet.payload.length})');
    }
  }

  /// Send takeoff2 command with specific parameters
  /// 
  /// [height] - Absolute height in meters (default: 0.3m)
  /// [duration] - Time to reach target height in seconds (default: 2.0s)
  /// [yaw] - Target yaw angle in radians (default: 0.0)
  /// [useCurrentYaw] - If true, maintains current yaw angle (default: true)
  /// [groupMask] - Group mask for multi-drone operations (default: 0 = all)
  Future<void> takeoff2({
    double height = defaultTakeoffHeight,
    double duration = defaultTakeoffDuration,
    double yaw = 0.0,
    bool useCurrentYaw = true,
    int groupMask = allGroups,
  }) async {
    final packet = Takeoff2Packet(
      groupMask: groupMask,
      height: height,
      yaw: yaw,
      useCurrentYaw: useCurrentYaw,
      duration: duration,
    );

    _sendPacket(packet);
    _responseController.add(
      'Takeoff2 command sent: height=${height}m, duration=${duration}s, yaw=${yaw}rad, useCurrentYaw=$useCurrentYaw'
    );
  }

  /// Send land2 command with specific parameters
  /// 
  /// [height] - Absolute landing height in meters (default: 0.0m)
  /// [duration] - Time to reach target height in seconds (default: 2.0s)
  /// [yaw] - Target yaw angle in radians (default: 0.0)
  /// [useCurrentYaw] - If true, maintains current yaw angle (default: true)
  /// [groupMask] - Group mask for multi-drone operations (default: 0 = all)
  Future<void> land2({
    double height = defaultLandingHeight,
    double duration = defaultLandingDuration,
    double yaw = 0.0,
    bool useCurrentYaw = true,
    int groupMask = allGroups,
  }) async {
    final packet = Land2Packet(
      groupMask: groupMask,
      height: height,
      yaw: yaw,
      useCurrentYaw: useCurrentYaw,
      duration: duration,
    );

    _sendPacket(packet);
    _responseController.add(
      'Land2 command sent: height=${height}m, duration=${duration}s, yaw=${yaw}rad, useCurrentYaw=$useCurrentYaw'
    );
  }

  /// Send emergency stop command
  /// 
  /// [groupMask] - Group mask for multi-drone operations (default: 0 = all)
  Future<void> emergencyStop({
    int groupMask = allGroups,
  }) async {
    final packet = StopPacket(groupMask: groupMask);

    _sendPacket(packet);
    _responseController.add('Emergency stop command sent');
  }

  /// Quick takeoff to default height with current yaw
  Future<void> quickTakeoff() async {
    await takeoff2(
      height: defaultTakeoffHeight,
      duration: defaultTakeoffDuration,
      useCurrentYaw: true,
    );
  }

  /// Quick land to ground with current yaw
  Future<void> quickLand() async {
    await land2(
      height: defaultLandingHeight,
      duration: defaultLandingDuration,
      useCurrentYaw: true,
    );
  }

  /// Takeoff with custom height but default duration and current yaw
  Future<void> takeoffToHeight(double height) async {
    await takeoff2(
      height: height,
      duration: defaultTakeoffDuration,
      useCurrentYaw: true,
    );
  }

  /// Takeoff with custom yaw angle
  Future<void> takeoffWithYaw(double yaw, {double height = defaultTakeoffHeight}) async {
    await takeoff2(
      height: height,
      yaw: yaw,
      useCurrentYaw: false,
      duration: defaultTakeoffDuration,
    );
  }

  /// Land with custom yaw angle
  Future<void> landWithYaw(double yaw, {double height = defaultLandingHeight}) async {
    await land2(
      height: height,
      yaw: yaw,
      useCurrentYaw: false,
      duration: defaultLandingDuration,
    );
  }

  void dispose() {
    _responseController.close();
    _commandResponseController.close();
  }
}

/// High-level commander states
enum HighLevelCommanderState {
  idle,
  takingOff,
  flying,
  landing,
  stopped,
}

/// Extended service with state tracking
class StatefulHighLevelCommanderService extends HighLevelCommanderService {
  HighLevelCommanderState _currentState = HighLevelCommanderState.idle;
  final StreamController<HighLevelCommanderState> _stateController = 
      StreamController<HighLevelCommanderState>.broadcast();
  
  StreamSubscription? _responseSubscription;
  Timer? _stateTransitionTimer;

  StatefulHighLevelCommanderService(super.sendPacket) {
    _initializeResponseListener();
  }

  HighLevelCommanderState get currentState => _currentState;
  Stream<HighLevelCommanderState> get stateStream => _stateController.stream;

  void _initializeResponseListener() {
    _responseSubscription = commandResponses.listen(_handleCommandResponse);
  }
  
  void _handleCommandResponse(HighLevelCommandResponse response) {
    AppLogger.debug(LogComponent.hlCommander, 'Handling command response: $response, current state: $_currentState');
    
    switch (response.commandId) {
      case 7: // COMMAND_TAKEOFF_2
        if (response.success) {
          AppLogger.info(LogComponent.hlCommander, 'Takeoff2 command successful - transitioning to flying state');
          // Transition to flying state immediately upon successful takeoff command
          _setState(HighLevelCommanderState.flying);
        } else {
          AppLogger.warn(LogComponent.hlCommander, 'Takeoff2 command failed - returning to idle state');
          _setState(HighLevelCommanderState.idle);
        }
        break;
        
      case 8: // COMMAND_LAND_2  
        if (response.success) {
          AppLogger.info(LogComponent.hlCommander, 'Land2 command successful - transitioning to idle state');
          // Transition to idle state immediately upon successful land command
          _setState(HighLevelCommanderState.idle);
        } else {
          AppLogger.warn(LogComponent.hlCommander, 'Land2 command failed - staying in current state');
        }
        break;
        
      case 3: // COMMAND_STOP
        if (response.success) {
          AppLogger.info(LogComponent.hlCommander, 'Stop command successful - transitioning to idle state');
          _setState(HighLevelCommanderState.idle);
        }
        break;
    }
  }

  void _setState(HighLevelCommanderState newState) {
    if (_currentState != newState) {
      AppLogger.info(LogComponent.hlCommander, 'State transition: $_currentState → $newState');
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  @override
  Future<void> takeoff2({
    double height = HighLevelCommanderService.defaultTakeoffHeight,
    double duration = HighLevelCommanderService.defaultTakeoffDuration,
    double yaw = 0.0,
    bool useCurrentYaw = true,
    int groupMask = HighLevelCommanderService.allGroups,
  }) async {
    AppLogger.info(LogComponent.hlCommander, 'Starting takeoff2 command - setting state to takingOff');
    _setState(HighLevelCommanderState.takingOff);
    
    await super.takeoff2(
      height: height,
      duration: duration,
      yaw: yaw,
      useCurrentYaw: useCurrentYaw,
      groupMask: groupMask,
    );
    
    // State transition will be handled by response from ESP-Drone
    // No timer needed - we rely on actual drone response
  }

  @override
  Future<void> land2({
    double height = HighLevelCommanderService.defaultLandingHeight,
    double duration = HighLevelCommanderService.defaultLandingDuration,
    double yaw = 0.0,
    bool useCurrentYaw = true,
    int groupMask = HighLevelCommanderService.allGroups,
  }) async {
    AppLogger.info(LogComponent.hlCommander, 'Starting land2 command - setting state to landing');
    _setState(HighLevelCommanderState.landing);
    
    await super.land2(
      height: height,
      duration: duration,
      yaw: yaw,
      useCurrentYaw: useCurrentYaw,
      groupMask: groupMask,
    );
    
    // State transition will be handled by response from ESP-Drone
    // No timer needed - we rely on actual drone response
  }

  @override
  Future<void> emergencyStop({int groupMask = HighLevelCommanderService.allGroups}) async {
    AppLogger.warn(LogComponent.hlCommander, 'Starting emergency stop command - setting state to stopped');
    _setState(HighLevelCommanderState.stopped);
    
    await super.emergencyStop(groupMask: groupMask);
    
    // State transition will be handled by response from ESP-Drone
    // No timer needed - we rely on actual drone response
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _stateTransitionTimer?.cancel();
    _stateController.close();
    super.dispose();
  }
}