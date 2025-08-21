import 'dart:typed_data';
import 'crtp_packet.dart';

/// CRTP LOG system packet types
enum LogCommand {
  getToc,        // Get Table of Contents info
  getItem,       // Get specific log variable info
  getTocV2,      // Get TOC info (version 2)
  getItemV2,     // Get item info (version 2)
}

enum LogControlCommand {
  createBlock,
  appendBlock,
  deleteBlock,
  startBlock,
  stopBlock,
  reset,
  createBlockV2,
  appendBlockV2,
}

/// Log variable types (must match ESP-Drone firmware definitions)
enum LogType {
  // Note: ESP-Drone uses 1-based indexing, but we convert in parsing code
  uint8,    // ESP-Drone: LOG_UINT8 = 1
  uint16,   // ESP-Drone: LOG_UINT16 = 2  
  uint32,   // ESP-Drone: LOG_UINT32 = 3
  int8,     // ESP-Drone: LOG_INT8 = 4
  int16,    // ESP-Drone: LOG_INT16 = 5
  int32,    // ESP-Drone: LOG_INT32 = 6
  float,    // ESP-Drone: LOG_FLOAT = 7
  fp16,     // ESP-Drone: LOG_FP16 = 8
}

/// Log variable information
class LogVariable {
  final int id;
  final String group;
  final String name;
  final LogType type;
  
  const LogVariable({
    required this.id,
    required this.group,
    required this.name,
    required this.type,
  });
  
  String get fullName => '$group.$name';
  
  @override
  String toString() => 'LogVariable($id: $fullName, type: ${type.name})';
}

/// TOC info request packet
class LogTocInfoPacket extends CrtpPacket {
  LogTocInfoPacket() : super(
    CrtpHeader(CrtpPort.log, 0), // TOC channel = 0
    Uint8List.fromList([3]), // CMD_GET_INFO_V2 = 3
  );
}

/// TOC item request packet
class LogTocItemPacket extends CrtpPacket {
  LogTocItemPacket(int itemId) : super(
    CrtpHeader(CrtpPort.log, 0), // TOC channel = 0
    _createPayload(itemId),
  );
  
  static Uint8List _createPayload(int itemId) {
    final buffer = ByteData(3);
    buffer.setUint8(0, 2); // CMD_GET_ITEM_V2 = 2
    buffer.setUint16(1, itemId, Endian.little);
    return buffer.buffer.asUint8List();
  }
}

/// Log block creation packet
class LogCreateBlockPacket extends CrtpPacket {
  LogCreateBlockPacket(int blockId, List<LogVariableConfig> variables) : super(
    CrtpHeader(CrtpPort.log, 1), // Control channel = 1
    _createPayload(blockId, variables),
  );
  
  static Uint8List _createPayload(int blockId, List<LogVariableConfig> variables) {
    final buffer = ByteData(2 + variables.length * 3); // cmd + blockId + (logType + varId) * count
    buffer.setUint8(0, 6); // CONTROL_CREATE_BLOCK_V2 = 6
    buffer.setUint8(1, blockId);
    
    int offset = 2;
    for (final variable in variables) {
      buffer.setUint8(offset, variable.logType.index + 1); // LogType enum is 0-based, protocol is 1-based
      buffer.setUint16(offset + 1, variable.variableId, Endian.little);
      offset += 3;
    }
    
    return buffer.buffer.asUint8List();
  }
}

/// Log block start packet
class LogStartBlockPacket extends CrtpPacket {
  LogStartBlockPacket(int blockId, int periodMs) : super(
    CrtpHeader(CrtpPort.log, 1), // Control channel = 1
    _createPayload(blockId, periodMs),
  );
  
  static Uint8List _createPayload(int blockId, int periodMs) {
    final buffer = ByteData(3);
    buffer.setUint8(0, 3); // CONTROL_START_BLOCK = 3
    buffer.setUint8(1, blockId);
    buffer.setUint8(2, (periodMs / 10).round()); // Period in 10ms units
    return buffer.buffer.asUint8List();
  }
}

/// Log block stop packet
class LogStopBlockPacket extends CrtpPacket {
  LogStopBlockPacket(int blockId) : super(
    CrtpHeader(CrtpPort.log, 1), // Control channel = 1
    _createPayload(blockId),
  );
  
  static Uint8List _createPayload(int blockId) {
    final buffer = ByteData(2);
    buffer.setUint8(0, 4); // CONTROL_STOP_BLOCK = 4
    buffer.setUint8(1, blockId);
    return buffer.buffer.asUint8List();
  }
}

/// Configuration for a log variable in a block
class LogVariableConfig {
  final int variableId;
  final LogType logType;
  
  const LogVariableConfig({
    required this.variableId,
    required this.logType,
  });
}

/// Received log data packet
class LogDataPacket {
  final int blockId;
  final int timestamp;
  final Map<String, dynamic> data;
  
  const LogDataPacket({
    required this.blockId,
    required this.timestamp,
    required this.data,
  });
  
  @override
  String toString() => 'LogDataPacket(block: $blockId, time: $timestamp, data: $data)';
}

/// Parse incoming log data packet
LogDataPacket? parseLogDataPacket(CrtpPacket packet, List<LogVariable> blockVariables) {
  if (packet.header.port != CrtpPort.log || packet.header.channel != 2) {
    return null; // Not a log data packet
  }
  
  if (packet.payload.length < 4) {
    return null; // Invalid packet size
  }
  
  final blockId = packet.payload[0];
  final timestamp = packet.payload[1] | 
                   (packet.payload[2] << 8) | 
                   (packet.payload[3] << 16);
  
  final data = <String, dynamic>{};
  int offset = 4;
  
  for (final variable in blockVariables) {
    if (offset >= packet.payload.length) break;
    
    dynamic value;
    switch (variable.type) {
      case LogType.uint8:
        value = packet.payload[offset];
        offset += 1;
        break;
      case LogType.uint16:
        value = ByteData.sublistView(packet.payload, offset, offset + 2)
                  .getUint16(0, Endian.little);
        offset += 2;
        break;
      case LogType.uint32:
        value = ByteData.sublistView(packet.payload, offset, offset + 4)
                  .getUint32(0, Endian.little);
        offset += 4;
        break;
      case LogType.int8:
        value = ByteData.sublistView(packet.payload, offset, offset + 1)
                  .getInt8(0);
        offset += 1;
        break;
      case LogType.int16:
        value = ByteData.sublistView(packet.payload, offset, offset + 2)
                  .getInt16(0, Endian.little);
        offset += 2;
        break;
      case LogType.int32:
        value = ByteData.sublistView(packet.payload, offset, offset + 4)
                  .getInt32(0, Endian.little);
        offset += 4;
        break;
      case LogType.float:
        value = ByteData.sublistView(packet.payload, offset, offset + 4)
                  .getFloat32(0, Endian.little);
        offset += 4;
        break;
      case LogType.fp16:
        // FP16 not implemented, skip
        offset += 2;
        continue;
    }
    
    data[variable.fullName] = value;
  }
  
  return LogDataPacket(
    blockId: blockId,
    timestamp: timestamp,
    data: data,
  );
}