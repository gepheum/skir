part of "../skir_client.dart";

abstract class _PrimitiveSerializer<T> extends _SerializerImpl<T> {
  String get typeName;
}

class _BoolSerializer extends _PrimitiveSerializer<bool> {
  @override
  bool isDefault(bool value) => !value;

  @override
  void encode(bool input, Uint8Buffer buffer) {
    buffer.add(input ? 1 : 0);
  }

  @override
  bool decode(_ByteStream stream, bool keepUnrecognizedValues) {
    return stream.decodeNumber().toInt() != 0;
  }

  @override
  void appendString(bool input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  dynamic toJson(bool input, bool readableFlavor) {
    return readableFlavor ? input : (input ? 1 : 0);
  }

  @override
  bool fromJson(dynamic json, bool keepUnrecognizedValues) {
    if (json is bool) return json;
    if (json is String) {
      return json != '0' && json != 'false';
    }
    return (json as num) != 0;
  }

  @override
  String get typeName => 'bool';

  @override
  ReflectiveTypeDescriptor<bool> get typeDescriptor => BoolDescriptor.instance;
}

class _Int32Serializer extends _PrimitiveSerializer<int> {
  @override
  bool isDefault(int value) => value == 0;

  @override
  void encode(int input, Uint8Buffer buffer) {
    _BinaryWriter.encodeInt32(input, buffer);
  }

  @override
  int decode(_ByteStream stream, bool keepUnrecognizedValues) {
    return stream.decodeNumber().toInt();
  }

  @override
  dynamic toJson(int input, bool readableFlavor) => input.toSigned(32);

  @override
  int fromJson(dynamic json, bool keepUnrecognizedValues) {
    final int number = switch (json) {
      int() => json,
      String() => int.parse(json),
      _ => (json as num).toInt(),
    };
    return number.toSigned(32);
  }

  @override
  void appendString(int input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  String get typeName => 'int32';

  @override
  ReflectiveTypeDescriptor<int> get typeDescriptor => Int32Descriptor.instance;
}

class _Int64Serializer extends _PrimitiveSerializer<int> {
  static const int minSafeJavaScriptInt = -9007199254740991; // -(2^53 - 1)
  static const int maxSafeJavaScriptInt = 9007199254740991; // 2^53 - 1

  @override
  bool isDefault(int value) => value == 0;

  @override
  void encode(int input, Uint8Buffer buffer) {
    if (input >= -2147483648 && input <= 2147483647) {
      _BinaryWriter.encodeInt32(input, buffer);
    } else {
      buffer.add(238);
      _BinaryWriter.writeLongLe(input, buffer);
    }
  }

  @override
  int decode(_ByteStream stream, bool keepUnrecognizedValues) {
    return stream.decodeNumber().toInt();
  }

  @override
  dynamic toJson(int input, bool readableFlavor) {
    return (input >= minSafeJavaScriptInt && input <= maxSafeJavaScriptInt)
        ? input
        : input.toString();
  }

  @override
  int fromJson(dynamic json, bool keepUnrecognizedValues) {
    return switch (json) {
      int() => json,
      String() => int.parse(json),
      _ => (json as num).toInt(),
    };
  }

  @override
  void appendString(int input, StringBuffer out, String eolIndent) {
    out.write(input);
  }

  @override
  String get typeName => 'int64';

  @override
  ReflectiveTypeDescriptor<int> get typeDescriptor => Int64Descriptor.instance;
}

class _Hash64Serializer extends _PrimitiveSerializer<BigInt> {
  static const int maxSafeJavaScriptInt = 9007199254740991; // 2^53 - 1
  static final BigInt maxHash64 = BigInt.parse("18446744073709551615");
  static final BigInt twoE64 = maxHash64 + BigInt.one;

  @override
  bool isDefault(BigInt value) => value == BigInt.zero;

  @override
  void encode(BigInt input, Uint8Buffer buffer) {
    if (input.isValidInt) {
      final int intValue = input.toInt();
      if (intValue < 232) {
        buffer.add(intValue);
      } else if (intValue < 4294967296) {
        if (intValue < 65536) {
          buffer.add(232);
          _BinaryWriter.writeShortLe(intValue, buffer);
        } else {
          buffer.add(233);
          _BinaryWriter.writeIntLe(intValue, buffer);
        }
      } else {
        buffer.add(234);
        _BinaryWriter.writeLongLe(intValue, buffer);
      }
    } else if (input < BigInt.zero) {
      buffer.add(0);
    } else {
      // max int64 < input <= max hash64
      buffer.add(234);
      if (input <= maxHash64) {
        _BinaryWriter.writeLongLe((input - twoE64).toInt(), buffer);
      } else {
        buffer.add(maxHash64.toInt());
      }
    }
  }

  @override
  BigInt decode(_ByteStream stream, bool keepUnrecognizedValues) {
    final intValue = stream.decodeNumber().toInt();
    if (intValue < 0) {
      return BigInt.from(intValue) + twoE64;
    } else {
      return BigInt.from(intValue);
    }
  }

  @override
  dynamic toJson(BigInt input, bool readableFlavor) {
    if (input.isValidInt) {
      final int intValue = input.toInt();
      if (0 <= intValue && intValue <= maxSafeJavaScriptInt) {
        return intValue;
      }
    }
    // Else
    if (input < BigInt.zero) {
      return "0";
    } else if (input <= maxHash64) {
      return input.toString();
    } else {
      return maxHash64.toString();
    }
  }

  @override
  BigInt fromJson(dynamic json, bool keepUnrecognizedValues) {
    return switch (json) {
      int() => json < 0 ? (BigInt.from(json) + twoE64) : BigInt.from(json),
      String() => BigInt.parse(json),
      _ => BigInt.from((json as num).toInt()),
    };
  }

  @override
  void appendString(BigInt input, StringBuffer out, String eolIndent) {
    if (input.isValidInt) {
      out.write('BigInt.from(${input.toString()})');
    } else {
      out.write('BigInt.parse("${input.toString()}")');
    }
  }

  @override
  String get typeName => 'hash64';

  @override
  ReflectiveTypeDescriptor<BigInt> get typeDescriptor =>
      Hash64Descriptor.instance;
}

class _Float32Serializer extends _PrimitiveSerializer<double> {
  @override
  bool isDefault(double value) => value == 0.0;

  @override
  void encode(double input, Uint8Buffer buffer) {
    if (input == 0.0) {
      buffer.add(0);
    } else {
      buffer.add(240);
      _BinaryWriter.writeFloatLe(input, buffer);
    }
  }

  @override
  double decode(_ByteStream stream, bool keepUnrecognizedValues) {
    return stream.decodeNumber().toDouble();
  }

  @override
  dynamic toJson(double input, bool readableFlavor) {
    return input.isFinite ? input : input.toString();
  }

  @override
  double fromJson(dynamic json, bool keepUnrecognizedValues) {
    if (json is double) return json;
    if (json is String) return double.parse(json);
    return (json as num).toDouble();
  }

  @override
  void appendString(double input, StringBuffer out, String eolIndent) {
    if (input.isFinite) {
      out.write(input);
    } else if (input.isNegative && input.isInfinite) {
      out.write('double.negativeInfinity');
    } else if (input.isInfinite) {
      out.write('double.infinity');
    } else {
      out.write('double.nan');
    }
  }

  @override
  String get typeName => 'float32';

  @override
  ReflectiveTypeDescriptor<double> get typeDescriptor =>
      Float32Descriptor.instance;
}

class _Float64Serializer extends _PrimitiveSerializer<double> {
  @override
  bool isDefault(double value) => value == 0.0;

  @override
  void encode(double input, Uint8Buffer buffer) {
    if (input == 0.0) {
      buffer.add(0);
    } else {
      buffer.add(241);
      _BinaryWriter.writeDoubleLe(input, buffer);
    }
  }

  @override
  double decode(_ByteStream stream, bool keepUnrecognizedValues) {
    return stream.decodeNumber().toDouble();
  }

  @override
  dynamic toJson(double input, bool readableFlavor) {
    return input.isFinite ? input : input.toString();
  }

  @override
  double fromJson(dynamic json, bool keepUnrecognizedValues) {
    if (json is double) return json;
    if (json is String) return double.parse(json);
    return (json as num).toDouble();
  }

  @override
  void appendString(double input, StringBuffer out, String eolIndent) {
    if (input.isFinite) {
      out.write(input);
    } else if (input.isNegative && input.isInfinite) {
      out.write('double.negativeInfinity');
    } else if (input.isInfinite) {
      out.write('double.infinity');
    } else {
      out.write('double.nan');
    }
  }

  @override
  String get typeName => 'float64';

  @override
  ReflectiveTypeDescriptor<double> get typeDescriptor =>
      Float64Descriptor.instance;
}

class _StringSerializer extends _PrimitiveSerializer<String> {
  @override
  bool isDefault(String value) => value.isEmpty;

  @override
  void encode(String input, Uint8Buffer buffer) {
    if (input.isEmpty) {
      buffer.add(242);
    } else {
      buffer.add(243);
      final bytes = utf8.encode(_sanitizeForUtf8(input));
      _BinaryWriter.encodeLengthPrefix(bytes.length, buffer);
      buffer.addAll(bytes);
    }
  }

  @override
  String decode(_ByteStream stream, bool keepUnrecognizedValues) {
    final wire = stream.readByte();
    if (wire == 0 || wire == 242) {
      return '';
    } else if (wire == 243) {
      final length = stream.decodeNumber().toInt();
      final bytes = stream.readBytes(length);
      return utf8.decode(bytes);
    } else {
      throw ArgumentError('Unexpected wire type for string: $wire');
    }
  }

  @override
  dynamic toJson(String input, bool readableFlavor) => input;

  @override
  String fromJson(dynamic json, bool keepUnrecognizedValues) {
    if (json is String) return json;
    if (json is num && json == 0) return '';
    return json.toString();
  }

  @override
  void appendString(String input, StringBuffer out, String eolIndent) {
    out.write('"');
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      switch (char) {
        case '\\':
          out.write('\\\\');
          break;
        case '"':
          out.write('\\"');
          break;
        case '\n':
          out.write('\\n');
          if (i < input.length - 1) {
            out.write('" +$eolIndent$_indentUnit"');
          }
          break;
        case '\r':
          out.write('\\r');
          break;
        case '\t':
          out.write('\\t');
          break;
        case '\b':
          out.write('\\b');
          break;
        case '\f':
          out.write('\\f');
          break;
        default:
          final code = char.codeUnitAt(0);
          if (code < 32 || (code >= 127 && code <= 159)) {
            out.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
          } else {
            out.write(char);
          }
      }
    }
    out.write('"');
  }

  @override
  String get typeName => 'string';

  @override
  ReflectiveTypeDescriptor<String> get typeDescriptor =>
      StringDescriptor.instance;

  // Replace malformed surrogate code units with U+FFFD while preserving valid pairs.
  String _sanitizeForUtf8(String input) {
    StringBuffer? out;
    int i = 0;
    while (i < input.length) {
      final cu = input.codeUnitAt(i);
      if (cu >= 0xD800 && cu <= 0xDBFF) {
        if (i + 1 < input.length) {
          final next = input.codeUnitAt(i + 1);
          if (next >= 0xDC00 && next <= 0xDFFF) {
            if (out != null) {
              out.writeCharCode(cu);
              out.writeCharCode(next);
            }
            i += 2;
            continue;
          }
        }
        out ??= StringBuffer()..write(input.substring(0, i));
        out.write('\uFFFD');
        i++;
        continue;
      }
      if (cu >= 0xDC00 && cu <= 0xDFFF) {
        out ??= StringBuffer()..write(input.substring(0, i));
        out.write('\uFFFD');
        i++;
        continue;
      }
      if (out != null) {
        out.writeCharCode(cu);
      }
      i++;
    }
    return out?.toString() ?? input;
  }
}

class _BytesSerializer extends _PrimitiveSerializer<ByteString> {
  @override
  bool isDefault(ByteString value) => value.isEmpty;

  @override
  void encode(ByteString input, Uint8Buffer buffer) {
    if (input.isEmpty) {
      buffer.add(244);
    } else {
      buffer.add(245);
      _BinaryWriter.encodeLengthPrefix(input.length, buffer);
      buffer.addAll(input.asUnmodifiableList);
    }
  }

  @override
  ByteString decode(_ByteStream stream, bool keepUnrecognizedValues) {
    final wire = stream.readByte();
    if (wire == 0 || wire == 244) {
      return ByteString.empty;
    } else {
      final length = stream.decodeNumber().toInt();
      return ByteString.copySlice(stream.readBytes(length));
    }
  }

  @override
  void appendString(ByteString input, StringBuffer out, String eolIndent) {
    out.write('"${input.toBase16()}"');
  }

  @override
  dynamic toJson(ByteString input, bool readableFlavor) {
    return readableFlavor ? 'hex:${input.toBase16()}' : input.toBase64();
  }

  @override
  ByteString fromJson(dynamic json, bool keepUnrecognizedValues) {
    if (json is String) {
      if (json.startsWith('hex:')) {
        return ByteString.fromBase16(json.substring(4));
      }
      return ByteString.fromBase64(json);
    } else if (json == 0) {
      return ByteString.empty;
    } else {
      throw ArgumentError('Expected: base64 string or hex-prefixed string');
    }
  }

  @override
  String get typeName => 'bytes';

  @override
  ReflectiveTypeDescriptor<ByteString> get typeDescriptor =>
      BytesDescriptor.instance;
}

class _TimestampSerializer extends _PrimitiveSerializer<DateTime> {
  @override
  bool isDefault(DateTime value) => value.millisecondsSinceEpoch == 0;

  @override
  void encode(DateTime input, Uint8Buffer buffer) {
    final unixMillis = _clampUnixMillis(input.millisecondsSinceEpoch);
    if (unixMillis == 0) {
      buffer.add(0);
    } else {
      buffer.add(239);
      _BinaryWriter.writeLongLe(unixMillis, buffer);
    }
  }

  @override
  DateTime decode(_ByteStream stream, bool keepUnrecognizedValues) {
    final unixMillis = _clampUnixMillis(stream.decodeNumber().toInt());
    return DateTime.fromMillisecondsSinceEpoch(unixMillis, isUtc: true);
  }

  @override
  dynamic toJson(DateTime input, bool readableFlavor) {
    final unixMillis = _clampUnixMillis(input.millisecondsSinceEpoch);
    return readableFlavor
        ? {
            'unix_millis': unixMillis,
            'formatted': DateTime.fromMillisecondsSinceEpoch(
              unixMillis,
              isUtc: true,
            ).toIso8601String(),
          }
        : unixMillis;
  }

  @override
  DateTime fromJson(dynamic json, bool keepUnrecognizedValues) {
    late int unixMillis;
    if (json is Map) {
      unixMillis = (json['unix_millis'] as num).toInt();
    } else if (json is num) {
      unixMillis = json.toInt();
    } else {
      unixMillis = int.parse(json as String);
    }
    return DateTime.fromMillisecondsSinceEpoch(
      _clampUnixMillis(unixMillis),
      isUtc: true,
    );
  }

  @override
  void appendString(DateTime input, StringBuffer out, String eolIndent) {
    out.write('DateTime.fromMillisecondsSinceEpoch(');
    out.write(eolIndent);
    out.write(_indentUnit);
    out.write('// ${input.toIso8601String()}');
    out.write(eolIndent);
    out.write(_indentUnit);
    out.write(input.millisecondsSinceEpoch);
    out.write(eolIndent);
    out.write(')');
  }

  static int _clampUnixMillis(int unixMillis) {
    return unixMillis.clamp(-8640000000000000, 8640000000000000);
  }

  @override
  String get typeName => 'timestamp';

  @override
  ReflectiveTypeDescriptor<DateTime> get typeDescriptor =>
      TimestampDescriptor.instance;
}
