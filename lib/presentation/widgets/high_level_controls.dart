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
  double _takeoffHeight = 0.3;
  double _takeoffDuration = 2.0;
  double _landingHeight = 0.0;
  double _landingDuration = 2.0;
  double _yawAngle = 0.0;
  bool _useCurrentYaw = true;

  @override
  Widget build(BuildContext context) {
    final hlState = ref.watch(highLevelCommanderProvider);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.flight_takeoff, color: Colors.blue),
                const SizedBox(width: 8.0),
                const Text(
                  'High-Level Commands',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildStatusIndicator(hlState),
              ],
            ),
            const SizedBox(height: 16.0),

            // Quick action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickTakeoffButton(hlState),
                _buildQuickLandButton(hlState),
                _buildEmergencyStopButton(hlState),
              ],
            ),
            const SizedBox(height: 16.0),

            // Advanced controls
            ExpansionTile(
              title: const Text('Advanced Settings'),
              children: [
                _buildHeightControls(),
                const SizedBox(height: 8.0),
                _buildDurationControls(),
                const SizedBox(height: 8.0),
                _buildYawControls(),
                const SizedBox(height: 16.0),
                _buildAdvancedButtons(hlState),
              ],
            ),

            // Status display
            if (hlState.lastResponse != null) ...[
              const SizedBox(height: 16.0),
              _buildStatusDisplay(hlState),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(HighLevelCommanderProviderState hlState) {
    Color color;
    String status;
    IconData icon;

    switch (hlState.commanderState) {
      case HighLevelCommanderState.idle:
        color = Colors.grey;
        status = 'Idle';
        icon = Icons.radio_button_unchecked;
        break;
      case HighLevelCommanderState.takingOff:
        color = Colors.orange;
        status = 'Taking Off';
        icon = Icons.flight_takeoff;
        break;
      case HighLevelCommanderState.flying:
        color = Colors.green;
        status = 'Flying';
        icon = Icons.airplanemode_active;
        break;
      case HighLevelCommanderState.landing:
        color = Colors.blue;
        status = 'Landing';
        icon = Icons.flight_land;
        break;
      case HighLevelCommanderState.stopped:
        color = Colors.red;
        status = 'Stopped';
        icon = Icons.stop;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16.0),
        const SizedBox(width: 4.0),
        Text(
          status,
          style: TextStyle(color: color, fontSize: 12.0),
        ),
      ],
    );
  }

  Widget _buildQuickTakeoffButton(HighLevelCommanderProviderState hlState) {
    final isEnabled = hlState.isEnabled && 
        (hlState.commanderState == HighLevelCommanderState.idle ||
         hlState.commanderState == HighLevelCommanderState.stopped);

    return ElevatedButton.icon(
      onPressed: isEnabled ? _quickTakeoff : null,
      icon: const Icon(Icons.flight_takeoff),
      label: const Text('Takeoff'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmergencyStopButton(HighLevelCommanderProviderState hlState) {
    final isEnabled = hlState.isEnabled;

    return ElevatedButton.icon(
      onPressed: isEnabled ? _emergencyStop : null,
      icon: const Icon(Icons.stop),
      label: const Text('STOP'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeightControls() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text('Takeoff Height:'),
            ),
            Expanded(
              flex: 3,
              child: Slider(
                value: _takeoffHeight,
                min: 0.1,
                max: 2.0,
                divisions: 19,
                label: '${_takeoffHeight.toStringAsFixed(1)}m',
                onChanged: (value) => setState(() => _takeoffHeight = value),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text('Landing Height:'),
            ),
            Expanded(
              flex: 3,
              child: Slider(
                value: _landingHeight,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${_landingHeight.toStringAsFixed(1)}m',
                onChanged: (value) => setState(() => _landingHeight = value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationControls() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text('Takeoff Duration:'),
            ),
            Expanded(
              flex: 3,
              child: Slider(
                value: _takeoffDuration,
                min: 1.0,
                max: 10.0,
                divisions: 9,
                label: '${_takeoffDuration.toStringAsFixed(1)}s',
                onChanged: (value) => setState(() => _takeoffDuration = value),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text('Landing Duration:'),
            ),
            Expanded(
              flex: 3,
              child: Slider(
                value: _landingDuration,
                min: 1.0,
                max: 10.0,
                divisions: 9,
                label: '${_landingDuration.toStringAsFixed(1)}s',
                onChanged: (value) => setState(() => _landingDuration = value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildYawControls() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Use Current Yaw'),
          subtitle: const Text('Maintain current orientation during maneuvers'),
          value: _useCurrentYaw,
          onChanged: (value) => setState(() => _useCurrentYaw = value),
        ),
        if (!_useCurrentYaw) ...[
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text('Yaw Angle:'),
              ),
              Expanded(
                flex: 3,
                child: Slider(
                  value: _yawAngle,
                  min: -180.0,
                  max: 180.0,
                  divisions: 36,
                  label: '${_yawAngle.toStringAsFixed(0)}°',
                  onChanged: (value) => setState(() => _yawAngle = value),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAdvancedButtons(HighLevelCommanderProviderState hlState) {
    final isEnabled = hlState.isEnabled;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: isEnabled ? _customTakeoff : null,
          child: const Text('Custom Takeoff'),
        ),
        ElevatedButton(
          onPressed: isEnabled ? _customLand : null,
          child: const Text('Custom Land'),
        ),
      ],
    );
  }

  Widget _buildStatusDisplay(HighLevelCommanderProviderState hlState) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hlState.lastCommand != null) ...[
            Text(
              'Last Command: ${hlState.lastCommand}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4.0),
          ],
          if (hlState.lastResponse != null) ...[
            Text(
              'Response: ${hlState.lastResponse}',
              style: const TextStyle(fontSize: 12.0),
            ),
            const SizedBox(height: 4.0),
          ],
          if (hlState.lastCommandTime != null) ...[
            Text(
              'Time: ${hlState.lastCommandTime!.toLocal().toString().substring(11, 19)}',
              style: const TextStyle(fontSize: 10.0, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // Action methods
  void _quickTakeoff() {
    ref.read(highLevelCommanderProvider.notifier).quickTakeoff();
  }

  void _quickLand() {
    ref.read(highLevelCommanderProvider.notifier).quickLand();
  }

  void _emergencyStop() {
    ref.read(highLevelCommanderProvider.notifier).emergencyStop();
  }

  void _customTakeoff() {
    final notifier = ref.read(highLevelCommanderProvider.notifier);
    if (_useCurrentYaw) {
      notifier.takeoff2(
        height: _takeoffHeight,
        duration: _takeoffDuration,
        useCurrentYaw: true,
      );
    } else {
      notifier.takeoff2(
        height: _takeoffHeight,
        duration: _takeoffDuration,
        yaw: _yawAngle * 3.14159 / 180.0, // Convert degrees to radians
        useCurrentYaw: false,
      );
    }
  }

  void _customLand() {
    final notifier = ref.read(highLevelCommanderProvider.notifier);
    if (_useCurrentYaw) {
      notifier.land2(
        height: _landingHeight,
        duration: _landingDuration,
        useCurrentYaw: true,
      );
    } else {
      notifier.land2(
        height: _landingHeight,
        duration: _landingDuration,
        yaw: _yawAngle * 3.14159 / 180.0, // Convert degrees to radians
        useCurrentYaw: false,
      );
    }
  }
}