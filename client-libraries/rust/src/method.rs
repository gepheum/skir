use super::serializer::Serializer;

/// Identifies one method in a SkirRPC service.
///
/// - `Request` is the type of the request parameter.
/// - `Response` is the type of the response returned by this method.
#[derive(Debug, Clone)]
pub struct Method<Request: 'static, Response: 'static> {
    /// The name of the method.
    pub name: String,
    /// The unique number identifying this method within the service.
    pub number: i64,
    /// Serializes and deserializes the request type.
    pub request_serializer: Serializer<Request>,
    /// Serializes and deserializes the response type.
    pub response_serializer: Serializer<Response>,
    /// The documentation string for this method.
    pub doc: String,
}
