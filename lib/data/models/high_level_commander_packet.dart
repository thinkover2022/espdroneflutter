import 'dart:typed_data';
import 'crtp_packet.dart';

// High-level commander port (0x08 as defined in ESP-Drone firmware)
// Now available as CrtpPort.setpointHl in crtp_packet.dart

// High-level command types based on ESP-Drone firmware
enum HighLevelCommand {
  setGroupMask(0),
  takeoff(1),          // Deprecated
  land(2),             // Deprecated  
  stop(3),
  goTo(4),
  startTrajectory(5),
  defineTrajectory(6),
  takeoff2(7),         // This is what we need!
  land2(8),
  takeoffWithVelocity(9),
  landWithVelocity(10);

  const HighLevelCommand(this.value);
  final int value;
}

/// High-level takeoff2 command packet
/// Based on the data_takeoff_2 structure from ESP-Drone firmware
class Takeoff2Packet extends CrtpPacket {
  final int groupMask;
  final double height;
  final double yaw;
  final bool useCurrentYaw;
  final double duration;

  Takeoff2Packet({
    required this.groupMask,
    required this.height,
    required this.yaw,
    required this.useCurrentYaw,
    required this.duration,
  }) : super(
          CrtpHeader(CrtpPort.setpointHl, 0),
          _serializeData(groupMask, height, yaw, useCurrentYaw, duration),
        );

  static Uint8List _serializeData(
    int groupMask,
    double height,
    double yaw,
    bool useCurrentYaw,
    double duration,
  ) {
    final buffer = ByteData(18); // 1 + 1 + 4 + 4 + 1 + 4 + 4 = 19 bytes, but pack tightly
    
    // Command ID (takeoff2 = 7)
    buffer.setUint8(0, HighLevelCommand.takeoff2.value);
    
    // Group mask
    buffer.setUint8(1, groupMask);
    
    // Height (float32)
    buffer.setFloat32(2, height, Endian.little);
    
    // Yaw (float32)
    buffer.setFloat32(6, yaw, Endian.little);
    
    // Use current yaw (bool)
    buffer.setUint8(10, useCurrentYaw ? 1 : 0);
    
    // Duration (float32)
    buffer.setFloat32(11, duration, Endian.little);
    
    return buffer.buffer.asUint8List(0, 15); // Trim to actual size
  }

  @override
  String toString() {
    return 'Takeoff2Packet{groupMask: $groupMask, height: $height, yaw: $yaw, useCurrentYaw: $useCurrentYaw, duration: $duration}';
  }
}

/// High-level land2 command packet
class Land2Packet extends CrtpPacket {
  final int groupMask;
  final double height;
  final double yaw;
  final bool useCurrentYaw;
  final double duration;

  Land2Packet({
    required this.groupMask,
    required this.height,
    required this.yaw,
    required this.useCurrentYaw,
    required this.duration,
  }) : super(
          CrtpHeader(CrtpPort.setpointHl, 0),
          _serializeData(groupMask, height, yaw, useCurrentYaw, duration),
        );

  static Uint8List _serializeData(
    int groupMask,
    double height,
    double yaw,
    bool useCurrentYaw,
    double duration,
  ) {
    final buffer = ByteData(18);
    
    // Command ID (land2 = 8)
    buffer.setUint8(0, HighLevelCommand.land2.value);
    
    // Group mask
    buffer.setUint8(1, groupMask);
    
    // Height (float32)
    buffer.setFloat32(2, height, Endian.little);
    
    // Yaw (float32)
    buffer.setFloat32(6, yaw, Endian.little);
    
    // Use current yaw (bool)
    buffer.setUint8(10, useCurrentYaw ? 1 : 0);
    
    // Duration (float32)
    buffer.setFloat32(11, duration, Endian.little);
    
    return buffer.buffer.asUint8List(0, 15);
  }

  @override
  String toString() {
    return 'Land2Packet{groupMask: $groupMask, height: $height, yaw: $yaw, useCurrentYaw: $useCurrentYaw, duration: $duration}';
  }
}

/// High-level stop command packet
class StopPacket extends CrtpPacket {
  final int groupMask;

  StopPacket({
    required this.groupMask,
  }) : super(
          CrtpHeader(CrtpPort.setpointHl, 0),
          _serializeData(groupMask),
        );

  static Uint8List _serializeData(int groupMask) {
    final buffer = ByteData(2);
    
    // Command ID (stop = 3)
    buffer.setUint8(0, HighLevelCommand.stop.value);
    
    // Group mask
    buffer.setUint8(1, groupMask);
    
    return buffer.buffer.asUint8List();
  }

  @override
  String toString() {
    return 'StopPacket{groupMask: $groupMask}';
  }
}