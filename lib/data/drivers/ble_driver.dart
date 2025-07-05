import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:espdroneflutter/data/models/crtp_packet.dart';

class BleDriver {
  static const String _serviceUuid = '00000201-1c7f-4f9e-947d-9797024fb5b4';
  static const String _characteristicUuid =
      '00000202-1c7f-4f9e-947d-9797024fb5b4';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _crtpCharacteristic;
  final StreamController<CrtpPacket> _incomingController =
      StreamController<CrtpPacket>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  bool _isConnected = false;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _characteristicSubscription;

  Stream<CrtpPacket> get incomingPackets => _incomingController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  Future<void> startScan() async {
    try {
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception('Bluetooth not available');
      }

      // Check if Bluetooth is on
      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.on) {
        throw Exception('Bluetooth is off');
      }

      // Start scanning for devices
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.platformName.contains('Crazyflie') ||
              result.device.platformName.contains('ESP-Drone')) {
            _connect(result.device);
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(_serviceUuid)],
      );
    } catch (e) {
      throw Exception('Failed to start BLE scan: $e');
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      _device = device;
      await FlutterBluePlus.stopScan();

      await device.connect();

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find CRTP service
      BluetoothService? crtpService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() ==
            _serviceUuid.toLowerCase()) {
          crtpService = service;
          break;
        }
      }

      if (crtpService == null) {
        throw Exception('CRTP service not found');
      }

      // Find CRTP characteristic
      for (BluetoothCharacteristic characteristic
          in crtpService.characteristics) {
        if (characteristic.uuid.toString().toLowerCase() ==
            _characteristicUuid.toLowerCase()) {
          _crtpCharacteristic = characteristic;
          break;
        }
      }

      if (_crtpCharacteristic == null) {
        throw Exception('CRTP characteristic not found');
      }

      // Enable notifications
      await _crtpCharacteristic!.setNotifyValue(true);

      // Listen for incoming data
      _characteristicSubscription =
          _crtpCharacteristic!.onValueReceived.listen((data) {
        _handleIncomingData(Uint8List.fromList(data));
      });

      _isConnected = true;
      _connectionStateController.add(true);

      print('BLE connection established');
    } catch (e) {
      _isConnected = false;
      _connectionStateController.add(false);
      throw Exception('Failed to connect BLE: $e');
    }
  }

  void disconnect() async {
    try {
      _scanSubscription?.cancel();
      _characteristicSubscription?.cancel();

      if (_crtpCharacteristic != null) {
        await _crtpCharacteristic!.setNotifyValue(false);
      }

      if (_device != null && _device!.isConnected) {
        await _device!.disconnect();
      }

      _device = null;
      _crtpCharacteristic = null;
      _isConnected = false;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(false);
      }

      print('BLE connection closed');
    } catch (e) {
      print('Error disconnecting BLE: $e');
    }
  }

  void sendPacket(CrtpPacket packet) async {
    if (!_isConnected || _crtpCharacteristic == null) {
      throw StateError('Not connected');
    }

    try {
      final packetBytes = packet.toBytes();

      // Fragment packet if needed (BLE has 20 byte limit)
      if (packetBytes.length <= 20) {
        await _crtpCharacteristic!.write(packetBytes);
      } else {
        // Fragment large packets
        for (int i = 0; i < packetBytes.length; i += 20) {
          final end =
              (i + 20 < packetBytes.length) ? i + 20 : packetBytes.length;
          final fragment = packetBytes.sublist(i, end);
          await _crtpCharacteristic!.write(fragment);
        }
      }
    } catch (e) {
      print('Error sending BLE packet: $e');
    }
  }

  void _handleIncomingData(Uint8List data) {
    try {
      final packet = CrtpPacket.fromBytes(data);
      _incomingController.add(packet);
    } catch (e) {
      print('Error parsing incoming BLE packet: $e');
    }
  }

  void dispose() {
    disconnect();
    _incomingController.close();
    _connectionStateController.close();
  }
}
