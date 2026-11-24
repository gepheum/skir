import skir_client/serializer.{type Serializer}

/// Metadata for a Skir RPC method.
pub type Method(request, response) {
  Method(
    /// The method name as declared in the .skir file.
    name: String,
    /// The stable numeric identifier of the method.
    number: Int,
    /// The documentation comment from the .skir file.
    doc: String,
    /// Serializer for request values.
    request_serializer: Serializer(request),
    /// Serializer for response values.
    response_serializer: Serializer(response),
  )
}
