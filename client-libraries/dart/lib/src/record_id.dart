part of "../skir_client.dart";

/// Parsed record identifier
class _RecordId {
  final String name;
  final String qualifiedName;
  final String modulePath;

  _RecordId(this.name, this.qualifiedName, this.modulePath);

  static _RecordId parse(String recordId) {
    final parts = recordId.split(':');
    final modulePath = parts[0];
    final qualifiedName = parts[1];
    final name = qualifiedName.split('.').last;
    return _RecordId(name, qualifiedName, modulePath);
  }
}
