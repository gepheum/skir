/// Identifies one method in a SkirRPC service.
///
/// - `Request` is the type of the request parameter.
/// - `Response` is the type of the response returned by this method.
public struct Method<Request, Response> {
  /// The name of the method.
  public let name: String
  /// The unique number identifying this method within the service.
  public let number: Int64
  /// Serializes and deserializes the request type.
  public let requestSerializer: Serializer<Request>
  /// Serializes and deserializes the response type.
  public let responseSerializer: Serializer<Response>
  /// The documentation string for this method.
  public let doc: String

  public init(
    name: String,
    number: Int64,
    requestSerializer: Serializer<Request>,
    responseSerializer: Serializer<Response>,
    doc: String
  ) {
    self.name = name
    self.number = number
    self.requestSerializer = requestSerializer
    self.responseSerializer = responseSerializer
    self.doc = doc
  }
}
