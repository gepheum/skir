part of "../skir_client.dart";

class _JsonObjectBuilder {
  final Map<String, dynamic> _map = {};

  _JsonObjectBuilder put(String key, dynamic value) {
    _map[key] = value;
    return this;
  }

  _JsonObjectBuilder putIf<T>(String key, T value, bool Function(T) predicate) {
    if (predicate(value)) {
      _map[key] = value;
    }
    return this;
  }

  Map<String, dynamic> build() => _map;
}
