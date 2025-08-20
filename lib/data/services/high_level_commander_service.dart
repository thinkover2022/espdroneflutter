import 'dart:async';
import 'package:espdroneflutter/data/models/high_level_commander_packet.dart';
import 'package:espdroneflutter/data/models/crtp_packet.dart';

/// Function type for sending CRTP packets
typedef PacketSender = void Function(CrtpPacket packet);

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

  HighLevelCommanderService(this._sendPacket);

  /// Stream of command response messages
  Stream<String> get responses => _responseController.stream;

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

  StatefulHighLevelCommanderService(super.sendPacket);

  HighLevelCommanderState get currentState => _currentState;
  Stream<HighLevelCommanderState> get stateStream => _stateController.stream;

  void _setState(HighLevelCommanderState newState) {
    if (_currentState != newState) {
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
    _setState(HighLevelCommanderState.takingOff);
    await super.takeoff2(
      height: height,
      duration: duration,
      yaw: yaw,
      useCurrentYaw: useCurrentYaw,
      groupMask: groupMask,
    );
    
    // Simulate state transition after takeoff duration
    Timer(Duration(milliseconds: (duration * 1000).round()), () {
      _setState(HighLevelCommanderState.flying);
    });
  }

  @override
  Future<void> land2({
    double height = HighLevelCommanderService.defaultLandingHeight,
    double duration = HighLevelCommanderService.defaultLandingDuration,
    double yaw = 0.0,
    bool useCurrentYaw = true,
    int groupMask = HighLevelCommanderService.allGroups,
  }) async {
    _setState(HighLevelCommanderState.landing);
    await super.land2(
      height: height,
      duration: duration,
      yaw: yaw,
      useCurrentYaw: useCurrentYaw,
      groupMask: groupMask,
    );
    
    // Simulate state transition after landing duration
    Timer(Duration(milliseconds: (duration * 1000).round()), () {
      _setState(HighLevelCommanderState.idle);
    });
  }

  @override
  Future<void> emergencyStop({int groupMask = HighLevelCommanderService.allGroups}) async {
    _setState(HighLevelCommanderState.stopped);
    await super.emergencyStop(groupMask: groupMask);
    
    // Return to idle after emergency stop
    Timer(const Duration(milliseconds: 500), () {
      _setState(HighLevelCommanderState.idle);
    });
  }

  @override
  void dispose() {
    _stateController.close();
    super.dispose();
  }
}