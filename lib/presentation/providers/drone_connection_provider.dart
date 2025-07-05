import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:espdroneflutter/data/drivers/esp_udp_driver.dart';
import 'package:espdroneflutter/data/drivers/ble_driver.dart';

enum ConnectionType { udp, ble }

abstract class DroneConnectionState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DroneDisconnected extends DroneConnectionState {}

class DroneConnecting extends DroneConnectionState {
  final ConnectionType type;

  DroneConnecting(this.type);

  @override
  List<Object?> get props => [type];
}

class DroneConnected extends DroneConnectionState {
  final ConnectionType type;

  DroneConnected(this.type);

  @override
  List<Object?> get props => [type];
}

class DroneConnectionFailed extends DroneConnectionState {
  final String error;

  DroneConnectionFailed(this.error);

  @override
  List<Object?> get props => [error];
}

class DroneConnectionNotifier extends StateNotifier<DroneConnectionState> {
  late final EspUdpDriver _udpDriver;
  late final BleDriver _bleDriver;

  DroneConnectionNotifier() : super(DroneDisconnected()) {
    _udpDriver = EspUdpDriver();
    _bleDriver = BleDriver();
    
    _udpDriver.connectionState.listen((connected) {
      if (connected && state is DroneConnecting) {
        state = DroneConnected(ConnectionType.udp);
      } else if (!connected && state is DroneConnected) {
        state = DroneDisconnected();
      }
    });

    _bleDriver.connectionState.listen((connected) {
      if (connected && state is DroneConnecting) {
        state = DroneConnected(ConnectionType.ble);
      } else if (!connected && state is DroneConnected) {
        state = DroneDisconnected();
      }
    });
  }

  Future<void> connectUdp() async {
    if (state is DroneConnecting || state is DroneConnected) {
      return;
    }

    state = DroneConnecting(ConnectionType.udp);

    try {
      await _udpDriver.connect();
    } catch (e) {
      state = DroneConnectionFailed(e.toString());
    }
  }

  Future<void> connectBle() async {
    if (state is DroneConnecting || state is DroneConnected) {
      return;
    }

    state = DroneConnecting(ConnectionType.ble);

    try {
      await _bleDriver.startScan();
    } catch (e) {
      state = DroneConnectionFailed(e.toString());
    }
  }

  void disconnect() {
    if (state is DroneConnected) {
      final currentState = state as DroneConnected;

      switch (currentState.type) {
        case ConnectionType.udp:
          _udpDriver.disconnect();
          break;
        case ConnectionType.ble:
          _bleDriver.disconnect();
          break;
      }
    }

    state = DroneDisconnected();
  }

  EspUdpDriver? get udpDriver => _udpDriver.isConnected ? _udpDriver : null;
  BleDriver? get bleDriver => _bleDriver.isConnected ? _bleDriver : null;

  @override
  void dispose() {
    _udpDriver.dispose();
    _bleDriver.dispose();
    super.dispose();
  }
}

final droneConnectionProvider = StateNotifierProvider<DroneConnectionNotifier, DroneConnectionState>((ref) {
  return DroneConnectionNotifier();
});