import 'package:flutter_bloc/flutter_bloc.dart';
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

class DroneConnectionCubit extends Cubit<DroneConnectionState> {
  final EspUdpDriver _udpDriver;
  final BleDriver _bleDriver;

  DroneConnectionCubit(this._udpDriver, this._bleDriver)
      : super(DroneDisconnected()) {
    // Listen to connection state changes
    _udpDriver.connectionState.listen((connected) {
      if (connected && state is DroneConnecting) {
        emit(DroneConnected(ConnectionType.udp));
      } else if (!connected && state is DroneConnected) {
        emit(DroneDisconnected());
      }
    });

    _bleDriver.connectionState.listen((connected) {
      if (connected && state is DroneConnecting) {
        emit(DroneConnected(ConnectionType.ble));
      } else if (!connected && state is DroneConnected) {
        emit(DroneDisconnected());
      }
    });
  }

  Future<void> connectUdp() async {
    if (state is DroneConnecting || state is DroneConnected) {
      return;
    }

    emit(DroneConnecting(ConnectionType.udp));

    try {
      await _udpDriver.connect();
      // Connection state will be updated by the stream listener
    } catch (e) {
      emit(DroneConnectionFailed(e.toString()));
    }
  }

  Future<void> connectBle() async {
    if (state is DroneConnecting || state is DroneConnected) {
      return;
    }

    emit(DroneConnecting(ConnectionType.ble));

    try {
      await _bleDriver.startScan();
      // Connection state will be updated by the stream listener
    } catch (e) {
      emit(DroneConnectionFailed(e.toString()));
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

    emit(DroneDisconnected());
  }

  EspUdpDriver? get udpDriver => _udpDriver.isConnected ? _udpDriver : null;
  BleDriver? get bleDriver => _bleDriver.isConnected ? _bleDriver : null;

  @override
  Future<void> close() {
    _udpDriver.dispose();
    _bleDriver.dispose();
    return super.close();
  }
}
