part of "../skir_client.dart";

class _ByteStream {
  final Uint8List bytes;
  int position;
  final ByteData _byteData;

  _ByteStream(this.bytes, this.position)
      : _byteData = ByteData.sublistView(bytes);

  int peekByte() => bytes[position];

  int readByte() {
    return bytes[position++];
  }

  Uint8List readBytes(int count) {
    final result = bytes.sublist(position, position + count);
    position += count;
    return result;
  }

  num decodeNumber() {
    final wire = readByte();

    if (wire < 232) {
      return wire;
    }

    switch (wire - 232) {
      case 0:
        {
          final result = _byteData.getUint16(position, Endian.little);
          position += 2;
          return result;
        }
      case 1:
        {
          final result = _byteData.getUint32(position, Endian.little);
          position += 4;
          return result;
        }
      case 2:
      case 6:
      case 7:
        {
          final result = _byteData.getInt64(position, Endian.little);
          position += 8;
          return result;
        }
      case 3:
        return readByte() - 256;
      case 4:
        {
          final result = _byteData.getUint16(position, Endian.little) - 65536;
          position += 2;
          return result;
        }
      case 5:
        {
          final result = _byteData.getInt32(position, Endian.little);
          position += 4;
          return result;
        }
      case 8:
        {
          final result = _byteData.getFloat32(position, Endian.little);
          position += 4;
          return result;
        }
      case 9:
        {
          final result = _byteData.getFloat64(position, Endian.little);
          position += 8;
          return result;
        }
      default:
        throw FormatException("Invalid number wire type: $wire");
    }
  }

  void decodeUnused() {
    final wire = readByte() & 0xFF;
    if (wire < 232) {
      return;
    }

    switch (wire - 232) {
      case 0:
      case 4: // uint16, uint16 - 65536
        readBytes(2);
        break;
      case 1:
      case 5:
      case 8: // uint32, int32, float32
        readBytes(4);
        break;
      case 2:
      case 6:
      case 7:
      case 9: // uint64, int64, uint64 timestamp, float64
        readBytes(8);
        break;
      case 3: // uint8 - 256
        readBytes(1);
        break;
      case 11:
      case 13: // string, bytes
        {
          final length = decodeNumber().toInt();
          position += length;
          break;
        }
      case 15:
      case 19:
      case 20:
      case 21:
      case 22: // array length==1, enum value kind==1-4
        decodeUnused();
        break;
      case 16: // array length==2
        decodeUnused();
        decodeUnused();
        break;
      case 17: // array length==3
        decodeUnused();
        decodeUnused();
        decodeUnused();
        break;
      case 18: // array length==N
        {
          final length = decodeNumber().toInt();
          for (int i = 0; i < length; ++i) {
            decodeUnused();
          }
          break;
        }
    }
  }
}

class _BinaryWriter {
  static void encodeInt32(int value, Uint8Buffer buffer) {
    if (value < 0) {
      if (value >= -256) {
        buffer.add(235);
        buffer.add(value + 256);
      } else if (value >= -65536) {
        buffer.add(236);
        writeShortLe(value + 65536, buffer);
      } else {
        buffer.add(237);
        writeIntLe(value >= -2147483648 ? value : -2147483648, buffer);
      }
    } else if (value < 232) {
      buffer.add(value);
    } else if (value < 65536) {
      buffer.add(232);
      writeShortLe(value, buffer);
    } else {
      buffer.add(233);
      writeIntLe(value <= 2147483647 ? value : 2147483647, buffer);
    }
  }

  static void encodeLengthPrefix(int length, Uint8Buffer buffer) {
    if (length < 232) {
      buffer.add(length & 0xFF);
    } else if (length < 65536) {
      buffer.add(232 & 0xFF);
      writeShortLe(length, buffer);
    } else if (length < 2147483648) {
      buffer.add(233 & 0xFF);
      writeIntLe(length, buffer);
    } else {
      throw ArgumentError("Length overflow: $length");
    }
  }

  static void writeShortLe(int value, Uint8Buffer buffer) {
    buffer.add(value & 0xFF);
    buffer.add((value >> 8) & 0xFF);
  }

  static void writeIntLe(int value, Uint8Buffer buffer) {
    buffer.add(value & 0xFF);
    buffer.add((value >> 8) & 0xFF);
    buffer.add((value >> 16) & 0xFF);
    buffer.add((value >> 24) & 0xFF);
  }

  static void writeLongLe(int value, Uint8Buffer buffer) {
    buffer.add(value & 0xFF);
    buffer.add((value >> 8) & 0xFF);
    buffer.add((value >> 16) & 0xFF);
    buffer.add((value >> 24) & 0xFF);
    buffer.add((value >> 32) & 0xFF);
    buffer.add((value >> 40) & 0xFF);
    buffer.add((value >> 48) & 0xFF);
    buffer.add((value >> 56) & 0xFF);
  }

  static void writeFloatLe(double value, Uint8Buffer buffer) {
    final bytes = ByteData(4);
    bytes.setFloat32(0, value, Endian.little);
    buffer.addAll(bytes.buffer.asUint8List());
  }

  static void writeDoubleLe(double value, Uint8Buffer buffer) {
    final bytes = ByteData(8);
    bytes.setFloat64(0, value, Endian.little);
    buffer.addAll(bytes.buffer.asUint8List());
  }
}
