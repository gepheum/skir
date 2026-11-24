part of "../skir_client.dart";

/// Exception thrown when an RPC call fails.
///
/// This exception encapsulates both network-level errors and server-side
/// failures, providing access to the HTTP status code and error message.
class RpcException implements Exception {
  /// The HTTP status code associated with the error.
  final int statusCode;

  /// A descriptive error message.
  final String message;

  /// Creates a new RPC exception.
  ///
  /// [statusCode] The HTTP status code (0 for non-HTTP errors)
  /// [message] A descriptive error message
  const RpcException(this.statusCode, this.message);

  @override
  String toString() => 'RpcException($statusCode): $message';
}

/// Sends RPCs to a SkirRPC service.
class ServiceClient {
  final Uri _serviceUri;
  final Map<String, String> _defaultHeaders;
  final http.Client _httpClient;

  /// Creates a new service client.
  ///
  /// [serviceUrl] The base URL of the service. Must not contain a query string.
  /// [defaultHeaders] Default headers to include with every request.
  /// [httpClient] The HTTP client to use. If not provided, a default client will be created.
  ServiceClient(
    String serviceUrl, {
    Map<String, String> defaultHeaders = const {},
    http.Client? httpClient,
  })  : _serviceUri = Uri.parse(serviceUrl),
        _defaultHeaders = {...defaultHeaders},
        _httpClient = httpClient ?? http.Client() {
    if (_serviceUri.hasQuery) {
      throw ArgumentError('Service URL must not contain a query string');
    }
  }

  /// Wraps a method descriptor to create a callable remote method.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.wrap(getFooMethod).invoke(
  ///   GetFooRequest(data: 'example'),
  ///   headers: {'Authorization': 'Bearer token'},
  ///   timeout: Duration(seconds: 30),
  /// );
  /// ```
  RemoteMethodWrapper<Request, Response> wrap<Request, Response>(
    Method<Request, Response> method,
  ) {
    return RemoteMethodWrapper._(method, this);
  }

  Future<Response> _invokeImpl<Request, Response>(
    Method<Request, Response> method,
    Request request,
    Map<String, String> headers,
    Duration? timeout,
  ) async {
    final requestJson = method.requestSerializer.toJsonCode(request);
    final requestBody = [
      method.name,
      method.number.toString(),
      '',
      requestJson,
    ].join(':');

    // Merge headers
    final mergedHeaders = {..._defaultHeaders};

    // Add request-specific headers
    for (final entry in headers.entries) {
      mergedHeaders[entry.key] = entry.value;
    }

    late final http.Response httpResponse;

    try {
      final postRequest = http.Request('POST', _serviceUri)
        ..headers.addAll(mergedHeaders)
        ..body = requestBody;

      final streamedResponse = timeout != null
          ? await _httpClient.send(postRequest).timeout(timeout)
          : await _httpClient.send(postRequest);

      httpResponse = await http.Response.fromStream(streamedResponse);

      if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
        final jsonCode = httpResponse.body;
        return method.responseSerializer.fromJsonCode(
          jsonCode,
          keepUnrecognizedValues: true,
        );
      } else {
        var message = '';
        final contentType = httpResponse.headers['content-type'] ?? '';
        if (contentType.toLowerCase().contains('text/plain')) {
          message = ': ${httpResponse.body}';
        }
        throw RpcException(
          httpResponse.statusCode,
          'HTTP status ${httpResponse.statusCode}$message',
        );
      }
    } catch (e) {
      if (e is RpcException) {
        rethrow;
      }
      // Wrap other exceptions as RpcException
      throw RpcException(0, 'Request failed: $e');
    }
  }

  /// Closes the underlying HTTP client.
  ///
  /// This should be called when the service client is no longer needed
  /// to free up resources.
  void close() {
    _httpClient.close();
  }
}

/// A wrapper around a remote service method that provides invocation.
class RemoteMethodWrapper<Request, Response> {
  final Method<Request, Response> _method;
  final ServiceClient _client;

  RemoteMethodWrapper._(this._method, this._client);

  /// Invokes the remote method with the given request.
  ///
  /// Sends an RPC request to the remote service and returns the response.
  /// This method handles serialization of the request, network communication,
  /// and deserialization of the response.
  ///
  /// [request] The request object to send to the remote method
  /// [headers] Additional HTTP headers to include with the request (optional)
  /// [timeout] Maximum time to wait for the response (optional)
  ///
  /// Returns a [Future] that completes with the deserialized response.
  ///
  /// Throws [RpcException] if the request fails due to network errors,
  /// HTTP errors, or timeout.
  Future<Response> invoke(
    Request request, {
    Map<String, String> headers = const {},
    Duration? timeout,
  }) {
    return _client._invokeImpl(_method, request, headers, timeout);
  }
}
