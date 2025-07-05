import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:espdroneflutter/presentation/cubit/drone_connection_cubit.dart';
import 'package:espdroneflutter/presentation/cubit/flight_control_cubit.dart';
import 'package:espdroneflutter/presentation/widgets/virtual_joystick.dart';
import 'package:espdroneflutter/presentation/widgets/flight_data_display.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
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
          BlocBuilder<DroneConnectionCubit, DroneConnectionState>(
            builder: (context, state) {
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
      body: BlocListener<DroneConnectionCubit, DroneConnectionState>(
        listener: (context, state) {
          if (state is DroneConnected) {
            _startFlightControl();
          } else if (state is DroneDisconnected) {
            _stopFlightControl();
          }
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
        ),
      ),
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
    context.read<FlightControlCubit>().updateAllControls(
          _rightJoystickX, // Roll
          _rightJoystickY, // Pitch
          _leftJoystickX, // Yaw
          _leftJoystickY, // Thrust
        );
  }

  void _emergencyStop() {
    context.read<FlightControlCubit>().emergencyStop();
    setState(() {
      _leftJoystickX = 0.0;
      _leftJoystickY = 0.0;
      _rightJoystickX = 0.0;
      _rightJoystickY = 0.0;
    });
  }

  void _takeoffLand() {
    final flightCubit = context.read<FlightControlCubit>();
    if (flightCubit.state.isFlying) {
      // Land
      flightCubit.updateThrust(0.0);
    } else {
      // Takeoff
      flightCubit.updateThrust(0.5);
    }
  }

  void _startFlightControl() {
    final connectionCubit = context.read<DroneConnectionCubit>();
    final flightCubit = context.read<FlightControlCubit>();

    flightCubit.startCommandLoop((packet) {
      if (connectionCubit.udpDriver != null) {
        connectionCubit.udpDriver!.sendPacket(packet);
      } else if (connectionCubit.bleDriver != null) {
        connectionCubit.bleDriver!.sendPacket(packet);
      }
    });
  }

  void _stopFlightControl() {
    context.read<FlightControlCubit>().stopCommandLoop();
  }

  void _showConnectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocBuilder<DroneConnectionCubit, DroneConnectionState>(
              builder: (context, state) {
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
              context.read<DroneConnectionCubit>().connectUdp();
              Navigator.of(context).pop();
            },
            child: const Text('Connect UDP'),
          ),
          TextButton(
            onPressed: () {
              context.read<DroneConnectionCubit>().connectBle();
              Navigator.of(context).pop();
            },
            child: const Text('Connect BLE'),
          ),
          TextButton(
            onPressed: () {
              context.read<DroneConnectionCubit>().disconnect();
              Navigator.of(context).pop();
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
