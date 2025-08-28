import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:espdroneflutter/data/services/high_level_commander_service.dart';
import 'package:espdroneflutter/data/models/crtp_packet.dart';
import 'package:espdroneflutter/presentation/providers/telemetry_provider.dart';
import 'package:espdroneflutter/presentation/providers/flight_control_provider.dart';

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
  
  // References for controlling low-level commands
  FlightControlNotifier? _flightControlNotifier;
  Function(CrtpPacket)? _lowLevelCommandSender;

  HighLevelCommanderNotifier() : super(HighLevelCommanderProviderState.initial());

  void initialize(Function(CrtpPacket) packetSender, {FlightControlNotifier? flightControlNotifier, Function(CrtpPacket)? lowLevelCommandSender}) {
    _packetSender = packetSender;
    _service = StatefulHighLevelCommanderService(packetSender);
    _flightControlNotifier = flightControlNotifier;
    _lowLevelCommandSender = lowLevelCommandSender;

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

  /// Stop low-level joystick commands to allow High Level Commander to take over
  void _stopJoystickCommands() {
    if (_flightControlNotifier != null) {
      print('Stopping joystick commands for High Level Commander');
      _flightControlNotifier!.stopCommandLoop();
      // Also send zero values to ensure drone stops receiving commands
      _flightControlNotifier!.emergencyStop();
    }
  }

  /// Restart low-level joystick commands
  void _restartJoystickCommands() {
    if (_flightControlNotifier != null && _lowLevelCommandSender != null) {
      print('Restarting joystick commands');
      _flightControlNotifier!.startCommandLoop(_lowLevelCommandSender!);
    }
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
    required TelemetryProviderState telemetryState,
    double relativeHeight = 0.3,
    double duration = 2.0,
    double yaw = 0.0,
    bool useCurrentYaw = true,
  }) async {
    if (_service == null) return;

    // Check if LOG system is initialized before proceeding
    if (!telemetryState.isLogInitialized) {
      print('Takeoff2 rejected: LOG system not initialized yet');
      state = state.copyWith(
        lastCommand: 'takeoff2 rejected - LOG system not ready',
        lastCommandTime: DateTime.now(),
      );
      return;
    }

    // Check if telemetry data is valid (height data available)
    final currentHeight = telemetryState.telemetryData.height;
    if (currentHeight == null) {
      print('Takeoff2 rejected: No height data available from telemetry');
      state = state.copyWith(
        lastCommand: 'takeoff2 rejected - No height data',
        lastCommandTime: DateTime.now(),
      );
      return;
    }

    // Stop low-level joystick commands
    _stopJoystickCommands();
    
    // Wait for ESP-Drone commander timeout (2+ seconds) to activate High Level Commander
    print('Waiting for ESP-Drone commander timeout (2.5s) to activate High Level Commander...');
    await Future.delayed(Duration(milliseconds: 2500));

    // Use validated height data
    final absoluteHeight = currentHeight + relativeHeight;

    print('=== TAKEOFF2 DEBUG ===');
    print('Takeoff2: current=${currentHeight.toStringAsFixed(2)}m, relative=+${relativeHeight.toStringAsFixed(2)}m, target=${absoluteHeight.toStringAsFixed(2)}m');
    print('Telemetry height: ${telemetryState.telemetryData.height}');
    print('Will send absolute height: $absoluteHeight to ESP-Drone');
    print('======================');

    state = state.copyWith(
      lastCommand: 'takeoff2(target: ${absoluteHeight.toStringAsFixed(2)}m, +${relativeHeight.toStringAsFixed(2)}m)',
      lastCommandTime: DateTime.now(),
    );

    try {
      await _service!.takeoff2(
        height: absoluteHeight,
        duration: duration,
        yaw: yaw,
        useCurrentYaw: useCurrentYaw,
      );
      
      // Wait for takeoff duration, then restart joystick commands
      await Future.delayed(Duration(milliseconds: (duration * 1000 + 1000).toInt()));
      _restartJoystickCommands();
    } catch (e) {
      print('Takeoff2 error: $e');
      // Always restart joystick commands even if takeoff fails
      _restartJoystickCommands();
      rethrow;
    }
  }

  Future<void> land2({
    double height = 0.0,
    double duration = 2.0,
    double yaw = 0.0,
    bool useCurrentYaw = true,
  }) async {
    if (_service == null) return;

    // Stop low-level joystick commands
    _stopJoystickCommands();
    
    // Wait for ESP-Drone commander timeout (2+ seconds) to activate High Level Commander
    print('Waiting for ESP-Drone commander timeout (2.5s) to activate High Level Commander...');
    await Future.delayed(Duration(milliseconds: 2500));

    state = state.copyWith(
      lastCommand: 'land2(height: ${height}m, duration: ${duration}s)',
      lastCommandTime: DateTime.now(),
    );

    try {
      await _service!.land2(
        height: height,
        duration: duration,
        yaw: yaw,
        useCurrentYaw: useCurrentYaw,
      );
      
      // Wait for landing duration, then restart joystick commands
      await Future.delayed(Duration(milliseconds: (duration * 1000 + 1000).toInt()));
      _restartJoystickCommands();
    } catch (e) {
      print('Land2 error: $e');
      // Always restart joystick commands even if landing fails
      _restartJoystickCommands();
      rethrow;
    }
  }

  Future<void> emergencyStop() async {
    if (_service == null) return;

    state = state.copyWith(
      lastCommand: 'emergencyStop',
      lastCommandTime: DateTime.now(),
    );

    await _service!.emergencyStop();
  }

  /// Calculate variance of height readings to detect sensor noise
  double _calculateVariance(List<double> readings) {
    if (readings.length < 2) return 0.0;
    final mean = readings.reduce((a, b) => a + b) / readings.length;
    final squaredDiffs = readings.map((x) => (x - mean) * (x - mean));
    return squaredDiffs.reduce((a, b) => a + b) / readings.length;
  }

  // Convenience methods (require telemetry state to be passed from UI)
  Future<void> quickTakeoff(TelemetryProviderState telemetryState, Function() getCurrentTelemetryState) async {
    const double targetRelativeHeight = 0.3; // 목표 상승 높이
    const double heightTolerance = 0.05; // 허용 오차 5cm
    const int maxRetries = 5; // 최대 재시도 횟수
    
    // FIXED: 시작 시점의 높이를 한 번만 저장하고 일관되게 사용
    double? baselineHeight;
    
    print('=== SMART TAKEOFF START ===');
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('--- Attempt $attempt/$maxRetries ---');
      
      try {
        // 첫 번째 시도에서 baseline 높이 설정
        if (baselineHeight == null) {
          final freshTelemetryState = getCurrentTelemetryState();
          baselineHeight = freshTelemetryState.telemetryData.height;
          if (baselineHeight == null) {
            print('❌ No height data available, aborting takeoff');
            return;
          }
          print('Baseline height set: ${baselineHeight.toStringAsFixed(2)}m → Target: ${(baselineHeight + targetRelativeHeight).toStringAsFixed(2)}m');
        }
        
        // takeoff2 실행 전 현재 텔레메트리 상태 확인
        final preTakeoffState = getCurrentTelemetryState();
        final preTakeoffHeight = preTakeoffState.telemetryData.height ?? baselineHeight;
        
        print('Pre-takeoff height: ${preTakeoffHeight.toStringAsFixed(2)}m');
        
        // takeoff2 실행 (duration 5초)
        await takeoff2(telemetryState: preTakeoffState, duration: 5.0, relativeHeight: targetRelativeHeight);
        
        // takeoff2 명령 완료 대기 및 모니터링
        print('Waiting for takeoff2 completion and monitoring height changes...');
        
        // 높이 변화를 여러 번 측정하여 안정성 확인
        final List<double> heightReadings = [];
        for (int i = 0; i < 5; i++) {
          await Future.delayed(Duration(milliseconds: 1000)); // 1초마다 측정
          final checkState = getCurrentTelemetryState();
          final checkHeight = checkState.telemetryData.height ?? baselineHeight;
          heightReadings.add(checkHeight);
          print('Height check ${i+1}/5: ${checkHeight.toStringAsFixed(2)}m (gain: ${(checkHeight - baselineHeight).toStringAsFixed(2)}m)');
        }
        
        // 최종 높이는 마지막 3개 측정값의 평균으로 계산 (안정성)
        final recentReadings = heightReadings.skip(2).toList(); // 마지막 3개
        final currentHeight = recentReadings.reduce((a, b) => a + b) / recentReadings.length;
        final heightGained = currentHeight - baselineHeight;
        
        print('=== FINAL ASSESSMENT ===');
        print('Height readings: ${heightReadings.map((h) => h.toStringAsFixed(2)).join(', ')} m');
        print('Baseline: ${baselineHeight.toStringAsFixed(2)}m');
        print('Final average: ${currentHeight.toStringAsFixed(2)}m');
        print('Height gained: ${heightGained.toStringAsFixed(2)}m');
        print('Target gain: ${targetRelativeHeight.toStringAsFixed(2)}m');
        print('Tolerance: ${heightTolerance.toStringAsFixed(2)}m');
        print('Success threshold: ${(targetRelativeHeight - heightTolerance).toStringAsFixed(2)}m');
        
        // 추가 검증: 높이 변화가 실제 상승인지 확인 (센서 노이즈 필터링)
        final heightVariance = _calculateVariance(heightReadings);
        final isStableReading = heightVariance < 0.01; // 1cm 미만의 변화만 안정적으로 간주
        
        // 센서 오류 감지: 갑작스럽게 큰 높이 변화는 센서 오류일 가능성
        final isSuspiciousGain = heightGained > (targetRelativeHeight * 1.5); // 1.5배 이상 상승 시 의심
        final isExcessiveGain = heightGained > 0.5; // 0.5m 이상 상승 시 과도한 상승
        
        print('Height variance: ${heightVariance.toStringAsFixed(4)}m² (stable: $isStableReading)');
        print('Suspicious gain check: ${isSuspiciousGain} (>${(targetRelativeHeight * 1.5).toStringAsFixed(2)}m)');
        print('Excessive gain check: ${isExcessiveGain} (>0.50m)');
        
        // 사용자 확인 요청 또는 자동 오류 감지
        if (isExcessiveGain || isSuspiciousGain) {
          print('⚠️ 경고: 비정상적으로 큰 높이 상승 감지!');
          print('현재 이를 자동 성공으로 처리하지만, 센서 오류일 가능성이 높습니다.');
          print('드론이 실제로 떠 있는지 육안으로 확인해주세요!');
          
          // TODO: 사용자 인터페이스에서 확인 버튼 추가 가능
          // 지금은 경고와 함께 성공 처리
        }
        
        if (heightGained >= (targetRelativeHeight - heightTolerance) && isStableReading) {
          final status = (isSuspiciousGain || isExcessiveGain) ? 'SUCCESS (sensor warning)' : 'SUCCESS';
          print('✅ TAKEOFF $status after $attempt attempts (gain: ${heightGained.toStringAsFixed(2)}m)');
          
          if (isSuspiciousGain || isExcessiveGain) {
            print('⚠️ 주의: 센서 데이터가 비정상적입니다. 드론이 실제로 이륚했는지 확인해주세요.');
          }
          
          state = state.copyWith(
            lastCommand: isSuspiciousGain ? 'takeoff completed (sensor warning)' : 'takeoff completed successfully',
            lastCommandTime: DateTime.now(),
          );
          return; // 성공! 완료
        } else if (heightGained >= (targetRelativeHeight - heightTolerance) && !isStableReading) {
          print('⚠️ Height reached but readings unstable (variance: ${heightVariance.toStringAsFixed(4)}), continuing...');
        }
        
        print('❌ Height not reached or unstable, need ${(targetRelativeHeight - heightGained).toStringAsFixed(2)}m more');
        
      } catch (e) {
        print('⚠️ Attempt $attempt failed: $e');
      }
      
      if (attempt < maxRetries) {
        print('Retrying in 1 second...');
        await Future.delayed(Duration(milliseconds: 1000));
      }
    }
    
    print('🔴 TAKEOFF FAILED after $maxRetries attempts');
    state = state.copyWith(
      lastCommand: 'takeoff failed after $maxRetries attempts',
      lastCommandTime: DateTime.now(),
    );
  }

  Future<void> quickLand() async {
    await land2();
  }

  Future<void> takeoffToHeight(TelemetryProviderState telemetryState, double relativeHeight) async {
    await takeoff2(telemetryState: telemetryState, relativeHeight: relativeHeight);
  }

  Future<void> takeoffWithYaw(TelemetryProviderState telemetryState, double yaw, {double relativeHeight = 0.3}) async {
    await takeoff2(telemetryState: telemetryState, relativeHeight: relativeHeight, yaw: yaw, useCurrentYaw: false);
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
  
  // Check if takeoff is allowed (LOG system must be initialized and telemetry data valid)
  bool isTakeoffAllowed(TelemetryProviderState telemetryState) {
    return telemetryState.isLogInitialized && 
           telemetryState.telemetryData.height != null && 
           !isActive;
  }
}

final highLevelCommanderProvider = StateNotifierProvider<HighLevelCommanderNotifier, HighLevelCommanderProviderState>((ref) {
  return HighLevelCommanderNotifier();
});