part of "../skir_client.dart";

class _IterableSerializer<E, Collection extends Iterable<E>>
    extends ReflectiveArrayDescriptor<E, Collection>
    implements _SerializerImpl<Collection> {
  final _SerializerImpl<E> item;
  final String? getKeySpec;
  final Collection Function(Iterable<E>) iterableToCollection;
  final Collection Function(List<E>) listToCollection;
  final Collection emptyCollection;

  static _IterableSerializer<E, Iterable<E>> iterable<E>(
    _SerializerImpl<E> item,
  ) =>
      _IterableSerializer<E, Iterable<E>>(
        item,
        null,
        (it) => it.toList(growable: false),
        (it) => it,
      );

  static _IterableSerializer<E, KeyedIterable<E, K>> keyedIterable<E, K>(
    _SerializerImpl<E> item,
    String? getKeySpec,
    K Function(E) getKey,
  ) {
    KeyedIterable<E, K> toCollection(Iterable<E> it) =>
        KeyedIterable.copy(it, getKey);
    return _IterableSerializer<E, KeyedIterable<E, K>>(
      item,
      getKeySpec,
      toCollection,
      toCollection,
    );
  }

  _IterableSerializer(
    this.item,
    this.getKeySpec,
    this.iterableToCollection,
    this.listToCollection,
  )   : emptyCollection = iterableToCollection(<E>[]),
        super._();

  @override
  bool isDefault(Iterable<E> value) => value.isEmpty;

  @override
  void encode(Iterable<E> input, Uint8Buffer buffer) {
    final length = input.length;
    if (length <= 3) {
      buffer.add(246 + length);
    } else {
      buffer.add(250);
      _BinaryWriter.encodeLengthPrefix(input.length, buffer);
    }
    for (final element in input) {
      item.encode(element, buffer);
    }
  }

  @override
  Collection decode(_ByteStream stream, bool keepUnrecognizedValues) {
    final wire = stream.readByte();
    if (wire == 0 || wire == 246) {
      return emptyCollection;
    }
    late final int length;
    if (247 <= wire && wire <= 249) {
      length = wire - 246;
    } else if (wire == 250) {
      length = stream.decodeNumber().toInt();
      if (length <= 0) {
        return emptyCollection;
      }
    } else {
      throw FormatException('Expected: list; wire: $wire');
    }
    final first = item.decode(stream, keepUnrecognizedValues);
    final result = List.filled(length, first, growable: false);
    for (int i = 1; i < length; i++) {
      result[i] = item.decode(stream, keepUnrecognizedValues);
    }
    return listToCollection(result);
  }

  @override
  void appendString(Iterable<E> input, StringBuffer out, String eolIndent) {
    if (input.isEmpty) {
      out.write('[]');
    } else {
      final newEolIndent = eolIndent + _indentUnit;
      out.write('[');
      for (final E element in input) {
        out.write(newEolIndent);
        item.appendString(element, out, newEolIndent);
        out.write(",");
      }
      out.write(eolIndent);
      out.write(']');
    }
  }

  @override
  dynamic toJson(Iterable<E> input, bool readableFlavor) {
    return input
        .map((e) => item.toJson(e, readableFlavor))
        .toList(growable: false);
  }

  @override
  Collection fromJson(dynamic json, bool keepUnrecognizedValues) {
    if (json == 0) {
      return emptyCollection;
    }
    final list = json as List;
    return iterableToCollection(
      list.map((e) => item.fromJson(e, keepUnrecognizedValues)),
    );
  }

  @override
  Collection get defaultValue => emptyCollection;

  @override
  ReflectiveTypeDescriptor<E> get itemType => item.typeDescriptor;

  @override
  String? get keyExtractor => getKeySpec;

  @override
  Collection toCollection(Iterable<E> iterable) {
    return iterableToCollection(iterable);
  }

  @override
  ReflectiveTypeDescriptor<Collection> get typeDescriptor => this;
}
