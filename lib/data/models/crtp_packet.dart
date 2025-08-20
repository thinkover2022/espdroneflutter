import 'dart:typed_data';

enum CrtpPort {
  console(0x00),
  param(0x02),
  commander(0x03),
  mem(0x04),
  logging(0x05),
  locSrv(0x06),
  setpointHl(0x08),    // High-level commander port
  platform(0x0D),
  clientSide(0x0E),
  linkctrl(0x0F),
  all(0xFF);

  const CrtpPort(this.value);
  final int value;
}

class CrtpHeader {
  final CrtpPort port;
  final int channel;

  CrtpHeader(this.port, this.channel);

  int toByte() {
    return (port.value << 4) | (channel & 0x0F);
  }

  static CrtpHeader fromByte(int byte) {
    final portValue = (byte >> 4) & 0x0F;
    final channel = byte & 0x0F;
    
    final port = CrtpPort.values.firstWhere(
      (p) => p.value == portValue,
      orElse: () => CrtpPort.all,
    );
    
    return CrtpHeader(port, channel);
  }
}

class CrtpPacket {
  final CrtpHeader header;
  final Uint8List payload;

  CrtpPacket(this.header, this.payload);

  factory CrtpPacket.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('Empty packet bytes');
    }
    
    final header = CrtpHeader.fromByte(bytes[0]);
    final payload = bytes.length > 1 ? bytes.sublist(1) : Uint8List(0);
    
    return CrtpPacket(header, payload);
  }

  Uint8List toBytes() {
    final buffer = ByteData(payload.length + 1);
    buffer.setUint8(0, header.toByte());
    
    for (int i = 0; i < payload.length; i++) {
      buffer.setUint8(i + 1, payload[i]);
    }
    
    return buffer.buffer.asUint8List();
  }

  @override
  String toString() {
    return 'CrtpPacket{port: ${header.port}, channel: ${header.channel}, payload: ${payload.length} bytes}';
  }
}