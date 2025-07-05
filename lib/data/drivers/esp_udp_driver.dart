import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:espdroneflutter/data/models/crtp_packet.dart';

class EspUdpDriver {
  static const String _targetIp = '192.168.43.42';
  static const int _targetPort = 2390;
  static const int _localPort = 2399;

  RawDatagramSocket? _socket;
  final StreamController<CrtpPacket> _incomingController =
      StreamController<CrtpPacket>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  bool _isConnected = false;
  Timer? _heartbeatTimer;

  Stream<CrtpPacket> get incomingPackets => _incomingController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      _socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, _localPort);
      _socket!.listen(_handleIncomingPacket);

      _isConnected = true;
      _connectionStateController.add(true);

      // Start heartbeat to maintain connection
      _startHeartbeat();

      print('UDP connection established on port $_localPort');
    } catch (e) {
      _isConnected = false;
      _connectionStateController.add(false);
      throw Exception('Failed to connect UDP: $e');
    }
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _heartbeatTimer?.cancel();
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(false);
    }
    print('UDP connection closed');
  }

  void sendPacket(CrtpPacket packet) {
    if (!_isConnected || _socket == null) {
      throw StateError('Not connected');
    }

    try {
      final packetBytes = packet.toBytes();
      final checksummedPacket = _addChecksum(packetBytes);

      _socket!.send(
        checksummedPacket,
        InternetAddress(_targetIp),
        _targetPort,
      );
    } catch (e) {
      print('Error sending packet: $e');
    }
  }

  void _handleIncomingPacket(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket!.receive();
      if (datagram != null) {
        try {
          final packet = _parsePacket(datagram.data);
          if (packet != null) {
            _incomingController.add(packet);
          }
        } catch (e) {
          print('Error parsing incoming packet: $e');
        }
      }
    }
  }

  CrtpPacket? _parsePacket(Uint8List data) {
    if (data.length < 2) {
      return null; // Too short to be valid
    }

    // Verify checksum
    final checksum = data.last;
    final packetData = data.sublist(0, data.length - 1);
    final calculatedChecksum = _calculateChecksum(packetData);

    if (checksum != calculatedChecksum) {
      print('Checksum mismatch: expected $calculatedChecksum, got $checksum');
      return null;
    }

    return CrtpPacket.fromBytes(packetData);
  }

  Uint8List _addChecksum(Uint8List data) {
    final checksum = _calculateChecksum(data);
    final result = Uint8List(data.length + 1);
    result.setAll(0, data);
    result[data.length] = checksum;
    return result;
  }

  int _calculateChecksum(Uint8List data) {
    int checksum = 0;
    for (int byte in data) {
      checksum = (checksum + byte) & 0xFF;
    }
    return checksum;
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isConnected) {
        // Send a null packet as heartbeat
        final heartbeat =
            CrtpPacket(CrtpHeader(CrtpPort.linkctrl, 0), Uint8List(0));
        sendPacket(heartbeat);
      }
    });
  }

  void dispose() {
    disconnect();
    _incomingController.close();
    _connectionStateController.close();
  }
}
