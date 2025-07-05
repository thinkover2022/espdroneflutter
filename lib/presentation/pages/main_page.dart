import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:espdroneflutter/presentation/providers/drone_connection_provider.dart';
import 'package:espdroneflutter/presentation/providers/flight_control_provider.dart';
import 'package:espdroneflutter/presentation/widgets/virtual_joystick.dart';
import 'package:espdroneflutter/presentation/widgets/flight_data_display.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  double _leftJoystickX = 0.0;
  double _leftJoystickY = 0.0;
  double _rightJoystickX = 0.0;
  double _rightJoystickY = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ESP-Drone Controller'),
        backgroundColor: Colors.grey[900],
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(droneConnectionProvider);
              return IconButton(
                icon: Icon(
                  state is DroneConnected ? Icons.wifi : Icons.wifi_off,
                  color: state is DroneConnected ? Colors.green : Colors.red,
                ),
                onPressed: () => _showConnectionDialog(context),
              );
            },
          ),
        ],
      ),
      body: Consumer(
          builder: (context, ref, child) {
            ref.listen<DroneConnectionState>(droneConnectionProvider,
                (previous, next) {
              if (next is DroneConnected) {
                _startFlightControl();
              } else if (next is DroneDisconnected) {
                _stopFlightControl();
              }
            });
            return child!;
          },
          child: SafeArea(
            child: Column(
              children: [
                // Flight data display and control buttons at top
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const FlightDataPanel(),
                      const SizedBox(height: 16.0),
                      // Control buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _emergencyStop,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                            ),
                            child: const Text('EMERGENCY STOP'),
                          ),
                          const FlightStatusIndicator(),
                          ElevatedButton(
                            onPressed: _takeoffLand,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                            ),
                            child: const Text('TAKEOFF/LAND'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main flight control area - responsive layout
                Expanded(
                  child: OrientationBuilder(
                    builder: (context, orientation) {
                      return _buildJoystickLayout(orientation);
                    },
                  ),
                ),
              ],
            ),
          )),
    );
  }

  Widget _buildJoystickLayout(Orientation orientation) {
    final screenSize = MediaQuery.of(context).size;
    final joystickSize = orientation == Orientation.landscape
        ? (screenSize.height * 0.25).clamp(120.0, 200.0)
        : (screenSize.width * 0.35).clamp(140.0, 220.0);

    if (orientation == Orientation.landscape) {
      // Landscape mode - side by side
      return Row(
        children: [
          // Left joystick (Thrust/Yaw)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Thrust / Yaw',
                    style: TextStyle(color: Colors.white70, fontSize: 12.0),
                  ),
                  const SizedBox(height: 8.0),
                  VirtualJoystick(
                    size: joystickSize,
                    onChanged: (x, y) {
                      setState(() {
                        _leftJoystickX = x; // Yaw
                        _leftJoystickY = y; // Thrust
                      });
                      _updateFlightControls();
                    },
                    baseColor: Colors.grey[800]!,
                    knobColor: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          // Right joystick (Roll/Pitch)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Roll / Pitch',
                    style: TextStyle(color: Colors.white70, fontSize: 12.0),
                  ),
                  const SizedBox(height: 8.0),
                  VirtualJoystick(
                    size: joystickSize,
                    onChanged: (x, y) {
                      setState(() {
                        _rightJoystickX = x; // Roll
                        _rightJoystickY = y; // Pitch
                      });
                      _updateFlightControls();
                    },
                    baseColor: Colors.grey[800]!,
                    knobColor: Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Portrait mode - stacked vertically
      return Column(
        children: [
          // Top joystick (Roll/Pitch)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Roll / Pitch',
                    style: TextStyle(color: Colors.white70, fontSize: 14.0),
                  ),
                  const SizedBox(height: 8.0),
                  VirtualJoystick(
                    size: joystickSize,
                    onChanged: (x, y) {
                      setState(() {
                        _rightJoystickX = x; // Roll
                        _rightJoystickY = y; // Pitch
                      });
                      _updateFlightControls();
                    },
                    baseColor: Colors.grey[800]!,
                    knobColor: Colors.red,
                  ),
                ],
              ),
            ),
          ),
          // Bottom joystick (Thrust/Yaw)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Thrust / Yaw',
                    style: TextStyle(color: Colors.white70, fontSize: 14.0),
                  ),
                  const SizedBox(height: 8.0),
                  VirtualJoystick(
                    size: joystickSize,
                    onChanged: (x, y) {
                      setState(() {
                        _leftJoystickX = x; // Yaw
                        _leftJoystickY = y; // Thrust
                      });
                      _updateFlightControls();
                    },
                    baseColor: Colors.grey[800]!,
                    knobColor: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  void _updateFlightControls() {
    ref.read(flightControlProvider.notifier).updateAllControls(
          _rightJoystickX, // Roll
          _rightJoystickY, // Pitch
          _leftJoystickX, // Yaw
          _leftJoystickY, // Thrust
        );
  }

  void _emergencyStop() {
    ref.read(flightControlProvider.notifier).emergencyStop();
    setState(() {
      _leftJoystickX = 0.0;
      _leftJoystickY = 0.0;
      _rightJoystickX = 0.0;
      _rightJoystickY = 0.0;
    });
  }

  void _takeoffLand() {
    final flightNotifier = ref.read(flightControlProvider.notifier);
    final flightState = ref.read(flightControlProvider);
    if (flightState.isFlying) {
      // Land
      flightNotifier.updateThrust(0.0);
    } else {
      // Takeoff
      flightNotifier.updateThrust(0.5);
    }
  }

  void _startFlightControl() {
    final connectionNotifier = ref.read(droneConnectionProvider.notifier);
    final flightNotifier = ref.read(flightControlProvider.notifier);

    flightNotifier.startCommandLoop((packet) {
      if (connectionNotifier.udpDriver != null) {
        connectionNotifier.udpDriver!.sendPacket(packet);
      } else if (connectionNotifier.bleDriver != null) {
        connectionNotifier.bleDriver!.sendPacket(packet);
      }
    });
  }

  void _stopFlightControl() {
    ref.read(flightControlProvider.notifier).stopCommandLoop();
  }

  void _showConnectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer(
              builder: (context, ref, child) {
                final state = ref.watch(droneConnectionProvider);
                String statusText = 'Disconnected';
                Color statusColor = Colors.red;

                if (state is DroneConnecting) {
                  statusText = 'Connecting...';
                  statusColor = Colors.orange;
                } else if (state is DroneConnected) {
                  statusText = 'Connected (${state.type.name.toUpperCase()})';
                  statusColor = Colors.green;
                } else if (state is DroneConnectionFailed) {
                  statusText = 'Failed: ${state.error}';
                  statusColor = Colors.red;
                }

                return Row(
                  children: [
                    Icon(Icons.circle, color: statusColor, size: 12.0),
                    const SizedBox(width: 8.0),
                    Text(statusText),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(droneConnectionProvider.notifier).connectUdp();
              Navigator.of(context).pop();
            },
            child: const Text('Connect UDP'),
          ),
          TextButton(
            onPressed: () {
              ref.read(droneConnectionProvider.notifier).connectBle();
              Navigator.of(context).pop();
            },
            child: const Text('Connect BLE'),
          ),
          TextButton(
            onPressed: () {
              ref.read(droneConnectionProvider.notifier).disconnect();
              Navigator.of(context).pop();
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
