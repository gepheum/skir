part of "../skir_client.dart";

class _OptionalSerializer<NotNull> extends ReflectiveOptionalDescriptor<NotNull>
    implements _SerializerImpl<NotNull?> {
  final _SerializerImpl<NotNull> other;

  _OptionalSerializer(this.other) : super._();

  @override
  bool isDefault(NotNull? value) => value == null;

  @override
  void encode(NotNull? input, Uint8Buffer buffer) {
    if (input == null) {
      buffer.add(255);
    } else {
      other.encode(input, buffer);
    }
  }

  @override
  NotNull? decode(_ByteStream stream, bool keepUnrecognizedValues) {
    if (stream.peekByte() == 255) {
      stream.position++;
      return null;
    } else {
      return other.decode(stream, keepUnrecognizedValues);
    }
  }

  @override
  void appendString(NotNull? input, StringBuffer out, String eolIndent) {
    if (input == null) {
      out.write('null');
    } else {
      other.appendString(input, out, eolIndent);
    }
  }

  @override
  dynamic toJson(NotNull? input, bool readableFlavor) {
    return input == null ? null : other.toJson(input, readableFlavor);
  }

  @override
  NotNull? fromJson(dynamic json, bool keepUnrecognizedValues) {
    return json == null ? null : other.fromJson(json, keepUnrecognizedValues);
  }

  @override
  NotNull? get defaultValue => null;

  @override
  ReflectiveTypeDescriptor<NotNull> get otherType => other.typeDescriptor;

  @override
  ReflectiveTypeDescriptor<NotNull?> get typeDescriptor => this;
}
