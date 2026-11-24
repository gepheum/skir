part of "../skir_client.dart";

/// Represents a remote procedure call (RPC) method definition.
///
/// A method defines the contract for a specific RPC operation, including
/// its name, unique identifier number, and serializers for both request
/// and response data types.
class Method<Request, Response> {
  /// The human-readable name of the method.
  final String name;

  /// The unique numeric identifier for this method.
  final int number;

  /// Serializer for the request type.
  final Serializer<Request> requestSerializer;

  /// Serializer for the response type.
  final Serializer<Response> responseSerializer;

  /// Documentation for this method.
  final String doc;

  Method(
    this.name,
    this.number,
    this.requestSerializer,
    this.responseSerializer,
    this.doc,
  );
}
