import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:espdroneflutter/presentation/providers/high_level_commander_provider.dart';
import 'package:espdroneflutter/data/services/high_level_commander_service.dart';

class HighLevelControlsWidget extends ConsumerStatefulWidget {
  const HighLevelControlsWidget({super.key});

  @override
  ConsumerState<HighLevelControlsWidget> createState() => _HighLevelControlsWidgetState();
}

class _HighLevelControlsWidgetState extends ConsumerState<HighLevelControlsWidget> {

  @override
  Widget build(BuildContext context) {
    final hlState = ref.watch(highLevelCommanderProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildQuickTakeoffButton(hlState),
        _buildQuickLandButton(hlState),
        _buildStopButton(hlState),
      ],
    );
  }


  Widget _buildQuickTakeoffButton(HighLevelCommanderProviderState hlState) {
    final isEnabled = hlState.isEnabled && 
        (hlState.commanderState == HighLevelCommanderState.idle ||
         hlState.commanderState == HighLevelCommanderState.stopped);

    // 디버깅용 로그 출력
    print('Takeoff button - isEnabled: ${hlState.isEnabled}, commanderState: ${hlState.commanderState}, buttonEnabled: $isEnabled');

    return ElevatedButton.icon(
      onPressed: isEnabled ? _quickTakeoff : null,
      icon: const Icon(Icons.flight_takeoff),
      label: const Text('Takeoff'),
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
    final isEnabled = hlState.isEnabled && 
        (hlState.commanderState == HighLevelCommanderState.flying ||
         hlState.commanderState == HighLevelCommanderState.takingOff);

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
    print('Quick takeoff button pressed!');
    ref.read(highLevelCommanderProvider.notifier).quickTakeoff();
  }

  void _quickLand() {
    ref.read(highLevelCommanderProvider.notifier).quickLand();
  }

  void _emergencyStop() {
    ref.read(highLevelCommanderProvider.notifier).emergencyStop();
  }
}