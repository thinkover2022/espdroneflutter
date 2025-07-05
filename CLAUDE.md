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
  - `commander_packet.dart`: Flight control command packets

#### Presentation Layer (`lib/presentation/`)
- **cubit/**: BLoC state management
  - `drone_connection_cubit.dart`: Manages UDP/BLE connection states
  - `flight_control_cubit.dart`: Flight control logic and command generation
- **pages/**: UI screens
  - `main_page.dart`: Main flight control interface with dual joysticks
- **widgets/**: Custom UI components
  - `virtual_joystick.dart`: Touch-based joystick controls
  - `flight_data_display.dart`: Real-time flight data visualization

### Communication Flow
1. UI joystick inputs → FlightControlCubit
2. FlightControlCubit generates CommanderPacket (20ms intervals)
3. DroneConnectionCubit sends packets via active driver (UDP/BLE)
4. ESP-Drone receives CRTP packets and responds with telemetry

### Flight Control Mapping
- **Left Joystick**: Thrust (Y-axis) / Yaw (X-axis)
- **Right Joystick**: Roll (X-axis) / Pitch (Y-axis)
- **Control Ranges**:
  - Roll/Pitch: ±20 degrees
  - Yaw Rate: ±200 degrees/second
  - Thrust: 10000-65535 (16-bit)

## Dependencies

### Core Dependencies
- `flutter_bloc`: State management
- `equatable`: Value equality comparisons
- `flutter_blue_plus`: BLE communication
- `permission_handler`: Runtime permissions
- `shared_preferences`: Local storage
- `provider`: Additional state management

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