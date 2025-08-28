import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:espdroneflutter/data/models/commander_packet.dart';

class FlightData extends Equatable {
  final double roll;
  final double pitch;
  final double yaw;
  final double thrust;
  final bool isFlying;

  const FlightData({
    required this.roll,
    required this.pitch,
    required this.yaw,
    required this.thrust,
    required this.isFlying,
  });

  factory FlightData.zero() {
    return const FlightData(
      roll: 0.0,
      pitch: 0.0,
      yaw: 0.0,
      thrust: 0.0,
      isFlying: false,
    );
  }

  FlightData copyWith({
    double? roll,
    double? pitch,
    double? yaw,
    double? thrust,
    bool? isFlying,
  }) {
    return FlightData(
      roll: roll ?? this.roll,
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
      thrust: thrust ?? this.thrust,
      isFlying: isFlying ?? this.isFlying,
    );
  }

  @override
  List<Object?> get props => [roll, pitch, yaw, thrust, isFlying];
}

class FlightControlNotifier extends StateNotifier<FlightData> {
  Timer? _commandTimer;
  final StreamController<FlightData> _flightDataController =
      StreamController<FlightData>.broadcast();

  // Flight control parameters
  double _rollTrim = 0.0;
  double _pitchTrim = 0.0;
  double _yawTrim = 0.0;
  double _thrustTrim = 0.0;

  // Control settings
  double _maxRollPitch = 20.0; // degrees
  double _maxYawRate = 200.0; // degrees/second
  double _maxThrust = 65535.0; // 16-bit max
  double _minThrust = 30000.0; // Increased minimum thrust for reliable takeoff (46% of max thrust)

  // Current control inputs
  double _currentRoll = 0.0;
  double _currentPitch = 0.0;
  double _currentYaw = 0.0;
  double _currentThrust = 0.0;

  bool _xMode = false;
  bool _isFlying = false;

  FlightControlNotifier() : super(FlightData.zero());

  Stream<FlightData> get flightDataStream => _flightDataController.stream;

  // Control input methods
  void updateRollPitch(double roll, double pitch) {
    _currentRoll = (roll * _maxRollPitch) + _rollTrim;
    _currentPitch = (pitch * _maxRollPitch) + _pitchTrim;
    _updateFlightData();
  }

  void updateYaw(double yaw) {
    _currentYaw = (yaw * _maxYawRate) + _yawTrim;
    _updateFlightData();
  }

  void updateThrust(double thrust) {
    // Map thrust from 0-1 to minThrust-maxThrust range
    if (thrust > 0) {
      _currentThrust =
          _minThrust + (thrust * (_maxThrust - _minThrust)) + _thrustTrim;
      _isFlying = true;
    } else {
      _currentThrust = 0.0;
      _isFlying = false;
    }
    _updateFlightData();
  }

  void updateAllControls(double roll, double pitch, double yaw, double thrust) {
    _currentRoll = (roll * _maxRollPitch) + _rollTrim;
    _currentPitch = (pitch * _maxRollPitch) + _pitchTrim;
    _currentYaw = (yaw * _maxYawRate) + _yawTrim;

    if (thrust > 0) {
      _currentThrust =
          _minThrust + (thrust * (_maxThrust - _minThrust)) + _thrustTrim;
      _isFlying = true;
    } else {
      _currentThrust = 0.0;
      _isFlying = false;
    }

    _updateFlightData();
  }

  void _updateFlightData() {
    final newData = FlightData(
      roll: _currentRoll,
      pitch: _currentPitch,
      yaw: _currentYaw,
      thrust: _currentThrust,
      isFlying: _isFlying,
    );

    state = newData;
    _flightDataController.add(newData);
  }

  // Emergency stop
  void emergencyStop() {
    _currentRoll = 0.0;
    _currentPitch = 0.0;
    _currentYaw = 0.0;
    _currentThrust = 0.0;
    _isFlying = false;
    _updateFlightData();
  }

  // Trim adjustment methods
  void setRollTrim(double trim) {
    _rollTrim = trim;
  }

  void setPitchTrim(double trim) {
    _pitchTrim = trim;
  }

  void setYawTrim(double trim) {
    _yawTrim = trim;
  }

  void setThrustTrim(double trim) {
    _thrustTrim = trim;
  }

  // Configuration methods
  void setMaxRollPitch(double maxRollPitch) {
    _maxRollPitch = maxRollPitch;
  }

  void setMaxYawRate(double maxYawRate) {
    _maxYawRate = maxYawRate;
  }

  void setMaxThrust(double maxThrust) {
    _maxThrust = maxThrust;
  }

  void setMinThrust(double minThrust) {
    _minThrust = minThrust;
  }

  void setXMode(bool xMode) {
    _xMode = xMode;
  }

  // Generate commander packet for current state
  CommanderPacket generateCommanderPacket() {
    return CommanderPacket(
      roll: _currentRoll,
      pitch: _currentPitch,
      yaw: _currentYaw,
      thrust: _currentThrust.toInt(),
      xMode: _xMode,
    );
  }

  // Start/stop command loop
  void startCommandLoop(Function(CommanderPacket) sendCommand) {
    _commandTimer?.cancel();
    _commandTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      try {
        final packet = generateCommanderPacket();
        sendCommand(packet);
      } catch (e) {
        print('Error in command loop: $e');
        // 연결이 끊어진 경우 안전하게 정지
        emergencyStop();
        stopCommandLoop();
      }
    });
  }

  void stopCommandLoop() {
    _commandTimer?.cancel();
    _commandTimer = null;
  }

  @override
  void dispose() {
    _commandTimer?.cancel();
    _flightDataController.close();
    super.dispose();
  }
}

final flightControlProvider = StateNotifierProvider<FlightControlNotifier, FlightData>((ref) {
  return FlightControlNotifier();
});