import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:espdroneflutter/data/services/log_service.dart';
import 'package:espdroneflutter/data/models/crtp_packet.dart';

class TelemetryProviderState extends Equatable {
  final bool isEnabled;
  final bool isActive;
  final TelemetryData telemetryData;
  final String? statusMessage;
  final DateTime? lastUpdate;

  const TelemetryProviderState({
    required this.isEnabled,
    required this.isActive,
    required this.telemetryData,
    this.statusMessage,
    this.lastUpdate,
  });

  factory TelemetryProviderState.initial() {
    return TelemetryProviderState(
      isEnabled: false,
      isActive: false,
      telemetryData: TelemetryData(timestamp: DateTime.now()),
    );
  }

  TelemetryProviderState copyWith({
    bool? isEnabled,
    bool? isActive,
    TelemetryData? telemetryData,
    String? statusMessage,
    DateTime? lastUpdate,
  }) {
    return TelemetryProviderState(
      isEnabled: isEnabled ?? this.isEnabled,
      isActive: isActive ?? this.isActive,
      telemetryData: telemetryData ?? this.telemetryData,
      statusMessage: statusMessage ?? this.statusMessage,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  @override
  List<Object?> get props => [
        isEnabled,
        isActive,
        telemetryData,
        statusMessage,
        lastUpdate,
      ];
}

class TelemetryNotifier extends StateNotifier<TelemetryProviderState> {
  LogService? _logService;
  Function(CrtpPacket)? _packetSender;
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _statusSubscription;

  TelemetryNotifier() : super(TelemetryProviderState.initial());

  void initialize(Function(CrtpPacket) packetSender) {
    print('Initializing TelemetryNotifier...');
    
    // Clean up existing resources first
    _telemetrySubscription?.cancel();
    _statusSubscription?.cancel();
    _logService?.dispose();
    
    // Initialize new resources
    _packetSender = packetSender;
    _logService = LogService(packetSender);

    // Listen to telemetry data updates
    _telemetrySubscription = _logService!.telemetryStream.listen(
      (telemetryData) {
        state = state.copyWith(
          telemetryData: telemetryData,
          lastUpdate: DateTime.now(),
          isActive: true,
        );
      },
      onError: (error) {
        print('Telemetry stream error: $error');
      },
    );

    // Listen to status updates
    _statusSubscription = _logService!.statusStream.listen(
      (status) {
        state = state.copyWith(
          statusMessage: status,
          lastUpdate: DateTime.now(),
        );
      },
      onError: (error) {
        print('Status stream error: $error');
      },
    );

    state = state.copyWith(isEnabled: true);
    
    // Start telemetry initialization
    startTelemetry();
    print('TelemetryNotifier initialized');
  }

  /// Process incoming CRTP packets for LOG responses
  void processIncomingPacket(CrtpPacket packet) {
    _logService?.processIncomingPacket(packet);
  }

  /// Start telemetry data collection
  Future<void> startTelemetry() async {
    if (_logService == null) return;
    
    print('Starting telemetry collection...');
    state = state.copyWith(
      statusMessage: 'Starting telemetry...',
      lastUpdate: DateTime.now(),
    );
    
    await _logService!.initialize();
  }

  /// Stop telemetry data collection
  void stopTelemetry() {
    if (_logService == null) return;
    
    print('Stopping telemetry collection...');
    _logService!.stop();
    
    state = state.copyWith(
      isActive: false,
      statusMessage: 'Telemetry stopped',
      lastUpdate: DateTime.now(),
    );
  }

  @override
  void dispose() {
    print('Disposing TelemetryNotifier...');
    
    // Cancel subscriptions safely
    _telemetrySubscription?.cancel();
    _telemetrySubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    
    // Dispose LOG service
    _logService?.dispose();
    _logService = null;
    _packetSender = null;
    
    // Reset state
    state = TelemetryProviderState.initial();
    
    super.dispose();
    print('TelemetryNotifier disposed');
  }

  // Convenience getters
  double? get height => state.telemetryData.height;
  double? get batteryVoltage => state.telemetryData.batteryVoltage;
  int? get batteryLevel => state.telemetryData.batteryLevel;
  double? get roll => state.telemetryData.roll;
  double? get pitch => state.telemetryData.pitch;
  double? get yaw => state.telemetryData.yaw;
  
  String get heightString {
    final h = height;
    return h != null ? '${h.toStringAsFixed(2)}m' : '--';
  }
  
  String get batteryString {
    final voltage = batteryVoltage;
    final level = batteryLevel;
    if (voltage != null && level != null) {
      return '${voltage.toStringAsFixed(1)}V (${level}%)';
    } else if (voltage != null) {
      return '${voltage.toStringAsFixed(1)}V';
    } else if (level != null) {
      return '${level}%';
    }
    return '--';
  }
  
  String get attitudeString {
    final r = roll;
    final p = pitch;
    final y = yaw;
    if (r != null && p != null && y != null) {
      return 'R:${r.toStringAsFixed(1)}° P:${p.toStringAsFixed(1)}° Y:${y.toStringAsFixed(1)}°';
    }
    return 'R:-- P:-- Y:--';
  }
}

final telemetryProvider = StateNotifierProvider<TelemetryNotifier, TelemetryProviderState>((ref) {
  return TelemetryNotifier();
});