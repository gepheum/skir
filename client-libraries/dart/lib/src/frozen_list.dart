part of "../skir_client.dart";

sealed class _FrozenList<E> implements List<E> {}

class _FrozenListImpl<E> extends UnmodifiableListView<E>
    implements _FrozenList<E> {
  _FrozenListImpl(List<E> super.list);

  @override
  bool operator ==(Object other) => _equalsImpl(this, other);
  @override
  int get hashCode => _hashCodeImpl(this);
}

/// An immutable iterable that supports fast lookup by key through [findByKey].
///
/// A key is extracted from each element using the function passed to
/// [copy]. Each element in the iterable is assumed to "contain" its own key.
///
/// This is a specialized collection that combines the functionality of a list
/// with fast key-based lookup, similar to a map but maintaining insertion
/// order.
sealed class KeyedIterable<E, K> implements Iterable<E> {
  /// An empty keyed iterable instance.
  static const KeyedIterable<Never, Never> empty = _EmptyFrozenList();

  /// Creates a new keyed iterable from the given elements.
  ///
  /// [elements] The elements to include in the iterable
  /// [getKey] A function that extracts the key from each element
  factory KeyedIterable.copy(Iterable<E> elements, K Function(E) getKey) {
    return internal__keyedCopy(elements, '', getKey);
  }

  /// Finds an element by its key.
  ///
  /// Returns the element associated with the given [key], or null if no
  /// element with that key exists.
  /// If multiple elements have the same key, returns the last one.
  E? findByKey(K key);
}

class _KeyedIterableImpl<E, K> extends UnmodifiableListView<E>
    implements KeyedIterable<E, K>, _FrozenList<E> {
  final String _getKeySpec;
  final K Function(E) _getKey;
  Map<K, E>? _mapView;

  _KeyedIterableImpl(List<E> super.list, this._getKeySpec, this._getKey);

  @override
  E? findByKey(K key) {
    final mapView = (_mapView ??= {for (var e in this) _getKey(e): e});
    return mapView[key];
  }

  @override
  bool operator ==(Object other) => _equalsImpl(this, other);
  @override
  int get hashCode => _hashCodeImpl(this);
}

class _EmptyFrozenList extends DelegatingList<Never>
    implements KeyedIterable<Never, Never>, _FrozenList<Never> {
  const _EmptyFrozenList() : super(const []);

  @override
  Never? findByKey(dynamic key) => null;

  @override
  bool operator ==(Object other) => _equalsImpl(this, other);
  @override
  int get hashCode => _hashCodeImpl(this);
}

Iterable<E> internal__frozenCopy<E>(Iterable<E> elements) {
  if (elements is _FrozenList<E>) {
    return elements;
  } else {
    return _FrozenListImpl(elements.toList(growable: false));
  }
}

Iterable<E> internal__frozenMappedCopy<E extends M, M>(
  Iterable<M> elements,
  E Function(M) toFrozen,
) {
  if (elements is _FrozenList<E>) {
    return elements;
  } else {
    return _FrozenListImpl(elements.map(toFrozen).toList(growable: false));
  }
}

KeyedIterable<E, K> internal__keyedCopy<E, K>(
  Iterable<E> elements,
  String getKeySpec,
  K Function(E) getKey,
) {
  if (elements.isEmpty) {
    return KeyedIterable.empty;
  } else if (elements is _KeyedIterableImpl<E, K> &&
      elements._getKeySpec.isNotEmpty &&
      elements._getKeySpec == getKeySpec) {
    return elements;
  } else {
    return _KeyedIterableImpl(
      elements.toList(growable: false),
      getKeySpec,
      getKey,
    );
  }
}

KeyedIterable<E, K> internal__keyedMappedCopy<E extends M, K, M>(
  Iterable<M> elements,
  String getKeySpec,
  K Function(E) getKey,
  E Function(M) toFrozen,
) {
  if (elements.isEmpty) {
    return KeyedIterable.empty;
  } else if (elements is _KeyedIterableImpl<E, K> &&
      elements._getKeySpec.isNotEmpty &&
      elements._getKeySpec == getKeySpec) {
    return elements;
  } else {
    return _KeyedIterableImpl<E, K>(
      elements.map(toFrozen).toList(growable: false),
      getKeySpec,
      getKey,
    );
  }
}

bool _equalsImpl(_FrozenList<dynamic> a, Object b) {
  if (identical(a, b)) return true;
  if (b is! _FrozenList<dynamic>) return false;
  return internal__listEquality.equals(a, b);
}

int _hashCodeImpl(_FrozenList<dynamic> list) {
  return internal__listEquality.hash(list);
}
