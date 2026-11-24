import Foundation

/// Sends RPCs to a SkirRPC service.
///
/// ## Example
///
/// ```swift
/// let client = try SkirClient.ServiceClient(serviceUrl: "http://localhost:8787/myapi")
/// let resp = try await client.invokeRemote(MyMethod, request: request)
/// ```
public final class ServiceClient {
  private let serviceUrl: String
  private var defaultHeaders: [(String, String)]
  private let urlSession: URLSession

  /// Creates a `ServiceClient` pointing at `serviceUrl`.
  ///
  /// Throws if `serviceUrl` contains a query string.
  public init(serviceUrl: String, urlSession: URLSession = .shared) throws {
    if serviceUrl.contains("?") {
      throw RpcError(
        statusCode: 0,
        message: "service URL must not contain a query string"
      )
    }
    self.serviceUrl = serviceUrl
    self.defaultHeaders = []
    self.urlSession = urlSession
  }

  /// Adds a default HTTP header sent with every invocation.
  ///
  /// Can be chained: `client.withDefaultHeader("Authorization", "Bearer …")`.
  @discardableResult
  public func withDefaultHeader(_ key: String, _ value: String) -> Self {
    defaultHeaders.append((key, value))
    return self
  }

  /// Invokes `method` on the remote service with the given `request`.
  ///
  /// `extraHeaders` is a sequence of `(name, value)` pairs added (or
  /// overriding) the default headers for this specific call only.
  ///
  /// The request is serialized as dense JSON. The response is deserialized
  /// keeping any unrecognized values (the server may have a newer schema).
  ///
  /// Throws `RpcError` if the server responds with a non-2xx status code
  /// or if a network-level failure occurs.
  public func invokeRemote<Req, Resp>(
    _ method: Method<Req, Resp>,
    request: Req,
    extraHeaders: [(String, String)] = []
  ) async throws -> Resp {
    // Serialize the request as dense JSON.
    let requestJson = method.requestSerializer.toJson(request, readable: false)

    // Wire body: "MethodName:number::requestJson"
    // The empty third field means the server may reply in dense JSON.
    let wireBody = "\(method.name):\(method.number)::\(requestJson)"

    guard let url = URL(string: serviceUrl) else {
      throw RpcError(statusCode: 0, message: "invalid service URL: \(serviceUrl)")
    }
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
    for (key, value) in defaultHeaders {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }
    for (key, value) in extraHeaders {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }
    urlRequest.httpBody = wireBody.data(using: .utf8)

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await urlSession.data(for: urlRequest)
    } catch {
      throw RpcError(statusCode: 0, message: error.localizedDescription)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw RpcError(statusCode: 0, message: "unexpected non-HTTP response")
    }

    let statusCode = httpResponse.statusCode
    if !(200..<300).contains(statusCode) {
      let isTextPlain = (httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "")
        .contains("text/plain")
      let message =
        isTextPlain
        ? (String(data: data, encoding: .utf8) ?? "")
        : ""
      throw RpcError(statusCode: statusCode, message: message)
    }

    guard let respBody = String(data: data, encoding: .utf8) else {
      throw RpcError(statusCode: 0, message: "failed to read response body: invalid UTF-8")
    }

    do {
      return try method.responseSerializer.fromJson(respBody, keepUnrecognized: true)
    } catch {
      throw RpcError(statusCode: 0, message: "failed to decode response: \(error)")
    }
  }
}

/// Error returned by `ServiceClient.invokeRemote` when the server responds
/// with a non-2xx status code or when a network-level failure occurs.
struct RpcError: Error, CustomStringConvertible {
  /// The HTTP status code returned by the server, or `0` for network-level
  /// failures (e.g. DNS error, connection refused, timeout).
  let statusCode: Int
  /// A human-readable description of the error.
  let message: String

  var description: String {
    "rpc error \(statusCode): \(message)"
  }
}
