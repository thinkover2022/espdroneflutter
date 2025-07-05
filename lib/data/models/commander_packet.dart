import 'dart:typed_data';
import 'crtp_packet.dart';

class CommanderPacket extends CrtpPacket {
  final double roll;
  final double pitch;
  final double yaw;
  final int thrust;
  final bool xMode;

  CommanderPacket({
    required this.roll,
    required this.pitch,
    required this.yaw,
    required this.thrust,
    this.xMode = false,
  }) : super(
          CrtpHeader(CrtpPort.commander, 0),
          _serializeData(roll, pitch, yaw, thrust, xMode),
        );

  static Uint8List _serializeData(double roll, double pitch, double yaw, int thrust, bool xMode) {
    final buffer = ByteData(14);
    
    // Apply X-mode transformation if enabled
    if (xMode) {
      final rollX = 0.707 * (roll - pitch);
      final pitchX = 0.707 * (roll + pitch);
      
      buffer.setFloat32(0, rollX, Endian.little);
      buffer.setFloat32(4, -pitchX, Endian.little); // Invert pitch
    } else {
      buffer.setFloat32(0, roll, Endian.little);
      buffer.setFloat32(4, -pitch, Endian.little); // Invert pitch
    }
    
    buffer.setFloat32(8, yaw, Endian.little);
    buffer.setUint16(12, thrust, Endian.little);
    
    return buffer.buffer.asUint8List();
  }

  @override
  String toString() {
    return 'CommanderPacket{roll: $roll, pitch: $pitch, yaw: $yaw, thrust: $thrust, xMode: $xMode}';
  }
}