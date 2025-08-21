import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:espdroneflutter/data/services/high_level_commander_service.dart';
import 'package:espdroneflutter/data/models/crtp_packet.dart';

class HighLevelCommanderProviderState extends Equatable {
  final bool isEnabled;
  final HighLevelCommanderState commanderState;
  final String? lastCommand;
  final DateTime? lastCommandTime;
  final String? lastResponse;

  const HighLevelCommanderProviderState({
    required this.isEnabled,
    required this.commanderState,
    this.lastCommand,
    this.lastCommandTime,
    this.lastResponse,
  });

  factory HighLevelCommanderProviderState.initial() {
    return const HighLevelCommanderProviderState(
      isEnabled: false,
      commanderState: HighLevelCommanderState.idle,
    );
  }

  HighLevelCommanderProviderState copyWith({
    bool? isEnabled,
    HighLevelCommanderState? commanderState,
    String? lastCommand,
    DateTime? lastCommandTime,
    String? lastResponse,
  }) {
    return HighLevelCommanderProviderState(
      isEnabled: isEnabled ?? this.isEnabled,
      commanderState: commanderState ?? this.commanderState,
      lastCommand: lastCommand ?? this.lastCommand,
      lastCommandTime: lastCommandTime ?? this.lastCommandTime,
      lastResponse: lastResponse ?? this.lastResponse,
    );
  }

  @override
  List<Object?> get props => [
        isEnabled,
        commanderState,
        lastCommand,
        lastCommandTime,
        lastResponse,
      ];
}

class HighLevelCommanderNotifier extends StateNotifier<HighLevelCommanderProviderState> {
  StatefulHighLevelCommanderService? _service;
  Function(CrtpPacket)? _packetSender;
  StreamSubscription? _incomingPacketSubscription;

  HighLevelCommanderNotifier() : super(HighLevelCommanderProviderState.initial());

  void initialize(Function(CrtpPacket) packetSender) {
    _packetSender = packetSender;
    _service = StatefulHighLevelCommanderService(packetSender);

    // Listen to state changes
    _service!.stateStream.listen((commanderState) {
      state = state.copyWith(commanderState: commanderState);
    });

    // Listen to responses
    _service!.responses.listen((response) {
      state = state.copyWith(
        lastResponse: response,
        lastCommandTime: DateTime.now(),
      );
    });

    state = state.copyWith(isEnabled: true);
  }
  
  /// Process incoming CRTP packets for command responses
  void processIncomingPacket(CrtpPacket packet) {
    _service?.processIncomingPacket(packet);
  }

  @override
  void dispose() {
    _incomingPacketSubscription?.cancel();
    _service?.dispose();
    _service = null;
    _packetSender = null;
    super.dispose();
  }

  // High-level takeoff commands
  Future<void> takeoff2({
    double height = 0.3,
    double duration = 2.0,
    double yaw = 0.0,
    bool useCurrentYaw = true,
  }) async {
    if (_service == null) return;

    state = state.copyWith(
      lastCommand: 'takeoff2(height: ${height}m, duration: ${duration}s)',
      lastCommandTime: DateTime.now(),
    );

    await _service!.takeoff2(
      height: height,
      duration: duration,
      yaw: yaw,
      useCurrentYaw: useCurrentYaw,
    );
  }

  Future<void> land2({
    double height = 0.0,
    double duration = 2.0,
    double yaw = 0.0,
    bool useCurrentYaw = true,
  }) async {
    if (_service == null) return;

    state = state.copyWith(
      lastCommand: 'land2(height: ${height}m, duration: ${duration}s)',
      lastCommandTime: DateTime.now(),
    );

    await _service!.land2(
      height: height,
      duration: duration,
      yaw: yaw,
      useCurrentYaw: useCurrentYaw,
    );
  }

  Future<void> emergencyStop() async {
    if (_service == null) return;

    state = state.copyWith(
      lastCommand: 'emergencyStop',
      lastCommandTime: DateTime.now(),
    );

    await _service!.emergencyStop();
  }

  // Convenience methods
  Future<void> quickTakeoff() async {
    await takeoff2();
  }

  Future<void> quickLand() async {
    await land2();
  }

  Future<void> takeoffToHeight(double height) async {
    await takeoff2(height: height);
  }

  Future<void> takeoffWithYaw(double yaw, {double height = 0.3}) async {
    await takeoff2(height: height, yaw: yaw, useCurrentYaw: false);
  }

  Future<void> landWithYaw(double yaw, {double height = 0.0}) async {
    await land2(height: height, yaw: yaw, useCurrentYaw: false);
  }

  // State queries
  bool get isIdle => state.commanderState == HighLevelCommanderState.idle;
  bool get isTakingOff => state.commanderState == HighLevelCommanderState.takingOff;
  bool get isFlying => state.commanderState == HighLevelCommanderState.flying;
  bool get isLanding => state.commanderState == HighLevelCommanderState.landing;
  bool get isStopped => state.commanderState == HighLevelCommanderState.stopped;
  bool get isActive => isTakingOff || isFlying || isLanding;
}

final highLevelCommanderProvider = StateNotifierProvider<HighLevelCommanderNotifier, HighLevelCommanderProviderState>((ref) {
  return HighLevelCommanderNotifier();
});