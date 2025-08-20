# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application for controlling an ESP-based drone, compatible with Crazyflie-style quadcopters. The app provides dual joystick control interface and supports both UDP and Bluetooth Low Energy (BLE) communication protocols.

## Common Development Commands

### Build and Run
```bash
# Run the app in debug mode
flutter run

# Build APK for Android
flutter build apk

# Build for iOS
flutter build ios

# Build for all platforms
flutter build
```

### Development Tasks
```bash
# Get dependencies
flutter pub get

# Analyze code for issues
flutter analyze

# Run tests
flutter test

# Run widget tests specifically
flutter test test/widget_test.dart

# Format code
flutter format .
```

### Platform-Specific Commands
```bash
# Android build
flutter build apk --release

# iOS build (requires macOS)
flutter build ios --release

# Web build
flutter build web

# Desktop builds
flutter build windows
flutter build linux
flutter build macos
```

## Architecture

### Core Architecture Pattern
- **BLoC Pattern**: Uses flutter_bloc for state management
- **Driver Pattern**: Communication drivers for UDP and BLE protocols
- **CRTP Protocol**: Crazy Real-Time Protocol for drone communication

### Key Components

#### Data Layer (`lib/data/`)
- **drivers/**: Communication protocol implementations
  - `esp_udp_driver.dart`: UDP communication with ESP-Drone (192.168.43.42:2390)
  - `ble_driver.dart`: BLE communication using flutter_blue_plus
- **models/**: Data structures for drone communication
  - `crtp_packet.dart`: CRTP protocol packet structure
  - `commander_packet.dart`: Flight control command packets (low-level)
  - `high_level_commander_packet.dart`: High-level command packets (takeoff2, land2, stop)
- **services/**: Business logic services
  - `high_level_commander_service.dart`: High-level command execution with state tracking

#### Presentation Layer (`lib/presentation/`)
- **providers/**: Riverpod state management
  - `drone_connection_provider.dart`: Manages UDP/BLE connection states
  - `flight_control_provider.dart`: Flight control logic and command generation
  - `high_level_commander_provider.dart`: High-level command state management
- **pages/**: UI screens
  - `main_page.dart`: Main flight control interface with dual joysticks and high-level controls
- **widgets/**: Custom UI components
  - `virtual_joystick.dart`: Touch-based joystick controls
  - `flight_data_display.dart`: Real-time flight data visualization
  - `high_level_controls.dart`: High-level command interface (takeoff2, land2, emergency stop)

### Communication Flow

#### Low-Level Control (Manual Flight)
1. UI joystick inputs → FlightControlProvider
2. FlightControlProvider generates CommanderPacket (20ms intervals)
3. DroneConnectionProvider sends packets via active driver (UDP/BLE)
4. ESP-Drone receives CRTP packets on commander port and responds with telemetry

#### High-Level Control (Autonomous Commands)
1. UI high-level buttons → HighLevelCommanderProvider
2. HighLevelCommanderProvider generates high-level command packets (takeoff2, land2, stop)
3. DroneConnectionProvider sends packets via active driver (UDP/BLE)
4. ESP-Drone receives CRTP packets on setpoint_hl port (0x08) and executes trajectory planning

### Flight Control Mapping

#### Low-Level Manual Controls
- **Left Joystick**: Thrust (Y-axis) / Yaw (X-axis)
- **Right Joystick**: Roll (X-axis) / Pitch (Y-axis)
- **Control Ranges**:
  - Roll/Pitch: ±20 degrees
  - Yaw Rate: ±200 degrees/second
  - Thrust: 10000-65535 (16-bit)

#### High-Level Autonomous Commands
- **Takeoff2**: Autonomous takeoff to specified height with optional yaw control
  - Parameters: height (0.1-2.0m), duration (1-10s), yaw (-180°-180°), useCurrentYaw
  - Default: 0.3m height, 2s duration, current yaw maintained
- **Land2**: Autonomous landing to specified height with optional yaw control
  - Parameters: height (0.0-1.0m), duration (1-10s), yaw (-180°-180°), useCurrentYaw
  - Default: 0.0m height, 2s duration, current yaw maintained
- **Emergency Stop**: Immediate motor stop with high-level command
  - Safer than low-level emergency stop, integrates with trajectory planner

## Dependencies

### Core Dependencies
- `flutter_riverpod`: State management (replaced flutter_bloc)
- `equatable`: Value equality comparisons
- `flutter_blue_plus`: BLE communication
- `permission_handler`: Runtime permissions
- `shared_preferences`: Local storage

### Development Dependencies
- `flutter_test`: Testing framework
- `flutter_lints`: Code linting rules

## Network Configuration

### UDP Connection
- **Target IP**: 192.168.43.42
- **Target Port**: 2390
- **Local Port**: 2399
- **Protocol**: UDP with checksum validation

### BLE Connection
- **Service UUID**: 00000201-1c7f-4f9e-947d-9797024fb5b4
- **Characteristic UUID**: 00000202-1c7f-4f9e-947d-9797024fb5b4
- **Device Names**: Looks for "Crazyflie" or "ESP-Drone"

## Testing

The project includes a basic widget test in `test/widget_test.dart`. Tests can be run with `flutter test`.

## Platform Support

This Flutter app supports:
- Android (primary target)
- iOS
- Web
- Windows
- Linux
- macOS

## Key Constants

- Command loop frequency: 20ms (50Hz)
- UDP heartbeat interval: 1 second
- BLE packet fragmentation: 20 bytes max
- Joystick dead zone and sensitivity configured in virtual_joystick.dart
- High-level commander port: 0x08 (CRTP_PORT_SETPOINT_HL)
- High-level command IDs: takeoff2=7, land2=8, stop=3

## Implementation Notes

### Takeoff2 High-Level Command Integration

This Flutter app now supports the ESP-Drone firmware's takeoff2 high-level command, which provides:

1. **Autonomous Takeoff**: The drone plans and executes a smooth takeoff trajectory to the specified height
2. **Trajectory Planning**: Uses the onboard trajectory planner for smooth acceleration/deceleration curves
3. **Yaw Control**: Option to maintain current yaw or rotate to a specific angle during takeoff
4. **Safety Integration**: Integrates with the high-level commander's safety systems

### Packet Structure Compatibility

The implementation matches the ESP-Drone firmware's data structures:

```dart
struct data_takeoff_2 {
  uint8_t groupMask;        // Group mask (0 = all drones)
  float height;             // Target height in meters
  float yaw;                // Target yaw in radians  
  bool useCurrentYaw;       // Maintain current yaw if true
  float duration;           // Time to reach target height
}
```

### State Management

The high-level commander tracks drone state through:
- `idle`: Ready for commands
- `takingOff`: Executing takeoff maneuver  
- `flying`: In flight, ready for land or other commands
- `landing`: Executing landing maneuver
- `stopped`: Emergency stopped

This enables the UI to show appropriate controls and prevent conflicting commands.