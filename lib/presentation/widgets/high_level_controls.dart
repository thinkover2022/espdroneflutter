import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:espdroneflutter/presentation/providers/high_level_commander_provider.dart';
import 'package:espdroneflutter/presentation/providers/telemetry_provider.dart';
import 'package:espdroneflutter/data/services/high_level_commander_service.dart';
import 'package:espdroneflutter/utils/app_logger.dart';

class HighLevelControlsWidget extends ConsumerStatefulWidget {
  const HighLevelControlsWidget({super.key});

  @override
  ConsumerState<HighLevelControlsWidget> createState() => _HighLevelControlsWidgetState();
}

class _HighLevelControlsWidgetState extends ConsumerState<HighLevelControlsWidget> {

  @override
  Widget build(BuildContext context) {
    final hlState = ref.watch(highLevelCommanderProvider);
    final telemetryState = ref.watch(telemetryProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildQuickTakeoffButton(hlState, telemetryState),
        _buildQuickLandButton(hlState),
        _buildStopButton(hlState),
      ],
    );
  }


  Widget _buildQuickTakeoffButton(HighLevelCommanderProviderState hlState, TelemetryProviderState telemetryState) {
    final isCommanderReady = hlState.isEnabled && 
        (hlState.commanderState == HighLevelCommanderState.idle ||
         hlState.commanderState == HighLevelCommanderState.stopped);
    final isLogReady = telemetryState.isLogInitialized;
    final hasHeightData = telemetryState.telemetryData.height != null;
    final isEnabled = isCommanderReady && isLogReady && hasHeightData;
    
    // Determine button label based on state
    String buttonLabel = 'Takeoff';
    if (!isLogReady) {
      buttonLabel = 'LOG...';
    } else if (!hasHeightData) {
      buttonLabel = 'DATA...';
    }

    // 디버깅용 로그 출력
    AppLogger.verbose(LogComponent.ui, 'Takeoff button - commander: $isCommanderReady, LOG: $isLogReady, height: $hasHeightData, enabled: $isEnabled');

    return ElevatedButton.icon(
      onPressed: isEnabled ? _quickTakeoff : null,
      icon: const Icon(Icons.flight_takeoff),
      label: Text(buttonLabel),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? Colors.green : Colors.green.withOpacity(0.5),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.green.withOpacity(0.3),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        minimumSize: const Size(90, 36),
      ),
    );
  }

  Widget _buildQuickLandButton(HighLevelCommanderProviderState hlState) {
    final telemetryState = ref.watch(telemetryProvider);
    final currentHeight = telemetryState.telemetryData.height ?? 0.0;
    final isAirborne = currentHeight > 0.5; // 0.5m 이상일 때만 공중으로 간주
    
    final isEnabled = hlState.isEnabled && 
        hlState.commanderState == HighLevelCommanderState.flying &&
        isAirborne;

    return ElevatedButton.icon(
      onPressed: isEnabled ? _quickLand : null,
      icon: const Icon(Icons.flight_land),
      label: const Text('Land'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? Colors.blue : Colors.blue.withOpacity(0.5),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.blue.withOpacity(0.3),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        minimumSize: const Size(90, 36),
      ),
    );
  }

  Widget _buildStopButton(HighLevelCommanderProviderState hlState) {
    final isEnabled = hlState.isEnabled;

    return ElevatedButton.icon(
      onPressed: isEnabled ? _emergencyStop : null,
      icon: const Icon(Icons.stop),
      label: const Text('STOP'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? Colors.red : Colors.red.withOpacity(0.5),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.red.withOpacity(0.3),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        minimumSize: const Size(90, 36),
      ),
    );
  }

  // Action methods
  void _quickTakeoff() {
    AppLogger.info(LogComponent.ui, 'Quick takeoff button pressed!');
    final telemetryState = ref.read(telemetryProvider);
    ref.read(highLevelCommanderProvider.notifier).quickTakeoff(
      telemetryState, 
      () => ref.read(telemetryProvider)
    );
  }

  void _quickLand() {
    ref.read(highLevelCommanderProvider.notifier).quickLand();
  }

  void _emergencyStop() {
    ref.read(highLevelCommanderProvider.notifier).emergencyStop();
  }
}