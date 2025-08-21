import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:espdroneflutter/presentation/providers/drone_connection_provider.dart';
import 'package:espdroneflutter/presentation/providers/flight_control_provider.dart';
import 'package:espdroneflutter/presentation/providers/high_level_commander_provider.dart';
import 'package:espdroneflutter/presentation/providers/telemetry_provider.dart';
import 'package:espdroneflutter/presentation/widgets/virtual_joystick.dart';
import 'package:espdroneflutter/presentation/widgets/flight_data_display.dart';
import 'package:espdroneflutter/presentation/widgets/high_level_controls.dart';

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
  
  StreamSubscription? _incomingPacketSubscription;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        toolbarHeight: 40.0, // AppBar 높이 최소화
        title: Container(
          height: 40.0, // title 영역 높이 고정
          child: Consumer(
            builder: (context, ref, child) {
              final telemetryData = ref.watch(telemetryProvider);
              final flightData = ref.watch(flightControlProvider);
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center, // 세로 중앙 정렬
                children: [
                  // 텔레메트리 데이터가 있으면 실제 값, 없으면 조이스틱 값 표시
                  _buildAppBarDataItem(
                    'H', 
                    telemetryData.telemetryData.height?.toStringAsFixed(2) ?? '--', 
                    Colors.cyan, 
                    'm'
                  ),
                  _buildAppBarDataItem(
                    'B', 
                    telemetryData.telemetryData.batteryVoltage?.toStringAsFixed(1) ?? '--', 
                    _getBatteryColor(telemetryData.telemetryData.batteryVoltage),
                    'V'
                  ),
                  _buildAppBarDataItem('R', flightData.roll, Colors.red),
                  _buildAppBarDataItem('P', flightData.pitch, Colors.blue),
                  _buildAppBarDataItem('Y', flightData.yaw, Colors.yellow),
                  _buildAppBarDataItem('T', flightData.thrust, Colors.green),
                ],
              );
            },
          ),
        ),
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
              print('Connection state changed: $next');
              if (next is DroneConnected) {
                print('Drone connected - initializing controls');
                _startFlightControl();
                _initializeHighLevelCommander();
                print('About to initialize telemetry...');
                _initializeTelemetry();
              } else if (next is DroneDisconnected) {
                print('Drone disconnected - cleaning up controls');
                _stopFlightControl();
                _disposeHighLevelCommander();
                _disposeTelemetry();
              }
            });
            return child!;
          },
          child: SafeArea(
            child: Column(
              children: [
                // High-Level Commands
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: HighLevelControlsWidget(),
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
    // 조이스틱 크기를 더 크게 설정
    final joystickSize = orientation == Orientation.landscape
        ? (screenSize.height * 0.6).clamp(150.0, 350.0) // 0.6으로 매우 크게 설정
        : (screenSize.width * 0.45).clamp(180.0, 280.0);

    if (orientation == Orientation.landscape) {
      // Landscape mode - side by side
      return Padding(
        padding: const EdgeInsets.all(5.0), // 패딩 더 줄이기
        child: Row(
          children: [
            // Left joystick (Thrust/Yaw)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(2.0), // 패딩 최소화
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    VirtualJoystick(
                      size: joystickSize,
                      baseRadius: joystickSize * 0.4,
                      knobRadius: joystickSize * 0.12,
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
              child: Container(
                padding: const EdgeInsets.all(2.0), // 패딩 최소화
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    VirtualJoystick(
                      size: joystickSize,
                      baseRadius: joystickSize * 0.4,
                      knobRadius: joystickSize * 0.12,
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
        ),
      );
    } else {
      // Portrait mode - stacked vertically
      return Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          children: [
            // Top joystick (Roll/Pitch)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    VirtualJoystick(
                      size: joystickSize,
                      baseRadius: joystickSize * 0.4,
                      knobRadius: joystickSize * 0.12,
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
              child: Container(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    VirtualJoystick(
                      size: joystickSize,
                      baseRadius: joystickSize * 0.4,
                      knobRadius: joystickSize * 0.12,
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
        ),
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


  void _startFlightControl() {
    final connectionNotifier = ref.read(droneConnectionProvider.notifier);
    final flightNotifier = ref.read(flightControlProvider.notifier);

    flightNotifier.startCommandLoop((packet) {
      try {
        if (connectionNotifier.udpDriver != null && connectionNotifier.udpDriver!.isConnected) {
          connectionNotifier.udpDriver!.sendPacket(packet);
        } else if (connectionNotifier.bleDriver != null) {
          connectionNotifier.bleDriver!.sendPacket(packet);
        }
      } catch (e) {
        print('Error sending flight control packet: $e');
        // 연결 오류 시 안전하게 정지
        flightNotifier.emergencyStop();
      }
    });
  }

  void _stopFlightControl() {
    final flightNotifier = ref.read(flightControlProvider.notifier);
    flightNotifier.emergencyStop(); // 정지 시 안전하게 모든 제어값 0으로 설정
    flightNotifier.stopCommandLoop();
  }

  void _initializeHighLevelCommander() {
    print('Initializing High Level Commander...');
    final connectionNotifier = ref.read(droneConnectionProvider.notifier);
    final hlCommander = ref.read(highLevelCommanderProvider.notifier);

    // Initialize with a packet sender function
    hlCommander.initialize((packet) {
      try {
        if (connectionNotifier.udpDriver != null && connectionNotifier.udpDriver!.isConnected) {
          print('Sending high-level command packet via UDP');
          connectionNotifier.udpDriver!.sendPacket(packet);
        } else if (connectionNotifier.bleDriver != null) {
          print('Sending high-level command packet via BLE');
          connectionNotifier.bleDriver!.sendPacket(packet);
        } else {
          print('No connection available for high-level command');
        }
      } catch (e) {
        print('Error sending high-level command packet: $e');
      }
    });
    
    // Packet subscription is handled in _initializeTelemetry() to avoid duplication
    
    print('High Level Commander initialized');
  }

  void _initializeTelemetry() {
    print('Initializing Telemetry...');
    final connectionNotifier = ref.read(droneConnectionProvider.notifier);
    final telemetryNotifier = ref.read(telemetryProvider.notifier);

    // Initialize with a packet sender function
    telemetryNotifier.initialize((packet) {
      try {
        if (connectionNotifier.udpDriver != null && connectionNotifier.udpDriver!.isConnected) {
          print('Sending telemetry packet via UDP: Port ${packet.header.port.name}');
          connectionNotifier.udpDriver!.sendPacket(packet);
        } else if (connectionNotifier.bleDriver != null) {
          print('Sending telemetry packet via BLE: Port ${packet.header.port.name}');
          connectionNotifier.bleDriver!.sendPacket(packet);
        } else {
          print('No connection available for telemetry packet');
        }
      } catch (e) {
        print('Error sending telemetry packet: $e');
      }
    });
    
    // Subscribe to incoming packets for telemetry responses
    if (connectionNotifier.udpDriver != null) {
      // Safely cancel any existing subscription
      _incomingPacketSubscription?.cancel();
      _incomingPacketSubscription = null;
      
      // Create new subscription
      try {
        _incomingPacketSubscription = connectionNotifier.udpDriver!.incomingPackets.listen(
          (packet) {
            // Forward to both high-level commander and telemetry
            ref.read(highLevelCommanderProvider.notifier).processIncomingPacket(packet);
            telemetryNotifier.processIncomingPacket(packet);
          },
          onError: (error) {
            print('Packet subscription error: $error');
          },
          onDone: () {
            print('Packet subscription completed');
          },
        );
        print('Packet subscription created successfully');
      } catch (e) {
        print('Error creating packet subscription: $e');
      }
    }
    
    print('Telemetry initialized');
  }

  void _disposeHighLevelCommander() {
    print('Disposing High Level Commander...');
    ref.read(highLevelCommanderProvider.notifier).dispose();
  }
  
  void _disposeTelemetry() {
    print('Disposing Telemetry...');
    // Cancel packet subscription safely
    _incomingPacketSubscription?.cancel();
    _incomingPacketSubscription = null;
    ref.read(telemetryProvider.notifier).dispose();
  }
  
  @override
  void dispose() {
    _incomingPacketSubscription?.cancel();
    super.dispose();
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

  Widget _buildAppBarDataItem(String label, dynamic value, Color color, [String? unit]) {
    String displayValue;
    if (value is double) {
      displayValue = value.toStringAsFixed(1);
    } else {
      displayValue = value.toString();
    }
    
    if (unit != null) {
      displayValue += unit;
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13.0, // 폰트 크기 줄이기
            fontWeight: FontWeight.bold,
            height: 1.0, // 줄 간격 최소화
          ),
        ),
        Text(
          displayValue,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.0, // 폰트 크기 줄이기
            height: 1.0, // 줄 간격 최소화
          ),
        ),
      ],
    );
  }
  
  Color _getBatteryColor(double? voltage) {
    if (voltage == null) return Colors.grey;
    if (voltage < 3.0) return Colors.red;      // 위험
    if (voltage < 3.3) return Colors.orange;   // 낮음
    if (voltage < 3.7) return Colors.yellow;   // 보통
    return Colors.green;                       // 양호
  }
}
