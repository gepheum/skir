import Foundation

/// Dispatches Skir RPC requests to registered method implementations.
///
/// `Meta` carries per-request context (e.g. HTTP headers, an authenticated
/// user identity) from your HTTP handler into each method implementation.
/// Use `Void` if you don't need per-request metadata.
///
/// ## Quick-start
///
/// 1. Define a metadata type (or use `Void`):
///    ```swift
///    struct RequestMeta { let userId: String }
///    ```
///
/// 2. Implement methods as a struct (or class):
///    ```swift
///    struct ServiceImpl {
///        func getUser(_ req: MySvc_skir.GetUserRequest, meta: RequestMeta) async throws
///                -> MySvc_skir.GetUserResponse {
///            // ... your logic here ...
///            // Throw a ServiceError to control the HTTP response status:
///            // throw ServiceError(statusCode: ._404_NotFound, message: "not found")
///        }
///
///        func addUser(_ req: MySvc_skir.AddUserRequest, meta: RequestMeta) async throws
///                -> MySvc_skir.AddUserResponse { ... }
///    }
///    ```
///
/// 3. Build the service:
///    ```swift
///    let impl = ServiceImpl()
///    let service = try Service<RequestMeta>(methods: [
///        .init(MySvc_skir.getUser()) { req, meta in try await impl.getUser(req, meta: meta) },
///        .init(MySvc_skir.addUser()) { req, meta in try await impl.addUser(req, meta: meta) },
///    ])
///    ```
///
/// 4. Wire into your HTTP framework (e.g. Vapor). The service accepts both
///    POST requests (pass the raw body) and GET requests (pass the decoded
///    query string — the part of the URL after `?`):
///    ```swift
///    app.on(.POST, .GET, "myapi") { req async in
///        let body: String
///        if req.method == .GET {
///            body = req.url.query ?? ""   // decoded query string
///        } else {
///            body = req.body.string ?? ""
///        }
///        let meta = RequestMeta(userId: req.headers.first(name: "X-User-Id") ?? "")
///        let raw = await service.handleRequest(body, meta: meta)
///        return Response(status: .init(statusCode: raw.statusCode), body: .init(string: raw.data))
///    }
///    ```
public final class Service<Meta> {
  /// Creates a `Service` ready to handle requests.
  ///
  /// - Parameters:
  ///   - methods: The method implementations to register. Throws if two
  ///     methods share the same number.
  ///   - keepUnrecognizedValues: When `true`, unrecognized fields in
  ///     requests are preserved. Only enable for trusted sources.
  ///     Defaults to `false`.
  ///   - canSendUnknownErrorMessage: Predicate for whether the message of
  ///     an unknown (non-`ServiceError`) error may be sent to the client.
  ///     Defaults to always returning `false` to avoid leaking internals.
  ///   - errorLogger: Callback invoked on every method error. Defaults to
  ///     printing the method name and error to stderr.
  ///   - studioAppJsUrl: URL to the Skir Studio JavaScript bundle served
  ///     when the request body is `""` or `"studio"`. Defaults to the
  ///     CDN-hosted version.
  public init(
    methods: [MethodImpl],
    keepUnrecognizedValues: Bool = false,
    canSendUnknownErrorMessage: @escaping (MethodErrorInfo) -> Bool = { _ in false },
    errorLogger: @escaping (MethodErrorInfo) -> Void = { info in
      fputs("skir: error in method \(String(reflecting: info.methodName)): \(info.error)\n", stderr)
    },
    studioAppJsUrl: String =
      "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js"
  ) throws {
    self.keepUnrecognizedValues = keepUnrecognizedValues
    self.canSendUnknownErrorMessage = canSendUnknownErrorMessage
    self.errorLogger = errorLogger
    self.studioAppJsUrl = studioAppJsUrl

    var byNum: [Int64: MethodEntry] = [:]
    var byName: [String: Int64] = [:]
    for m in methods {
      let entry = m.entry
      guard byNum[entry.number] == nil else {
        throw ServiceError(
          statusCode: ._500_InternalServerError,
          message: "skir: method number \(entry.number) already registered"
        )
      }
      byNum[entry.number] = entry
      byName[entry.name] = entry.number
    }
    self.byNum = byNum
    self.byName = byName
  }

  // =========================================================================
  // Request handling
  // =========================================================================

  /// Parses `body` and dispatches to the appropriate registered method.
  ///
  /// For GET requests in a standard HTTP stack, pass the decoded query
  /// string as `body`. For POST requests, pass the raw request body.
  public func handleRequest(_ body: String, meta: Meta) async -> ServiceRawResponse {
    switch body {
    case "", "studio":
      return serveStudio(studioAppJsUrl)
    case "list":
      return serveList()
    default:
      break
    }
    let first = body.unicodeScalars.first.map { Character($0) } ?? " "
    if first == "{" || first.isWhitespace {
      return await handleJsonRequest(body, meta: meta)
    } else {
      return await handleColonRequest(body, meta: meta)
    }
  }

  // =========================================================================
  // MethodErrorInfo
  // =========================================================================

  /// Context passed to the error logger when a method returns an error.
  public struct MethodErrorInfo {
    /// The error returned by the method. Cast to `ServiceError` to
    /// distinguish HTTP errors from unknown internal errors.
    public let error: Error
    /// The name of the method that failed.
    public let methodName: String
    /// The raw JSON of the request that caused the error.
    public let rawRequest: String
    /// The per-request metadata supplied by the HTTP handler.
    public let requestMeta: Meta
  }

  // =========================================================================
  // MethodImpl
  // =========================================================================

  /// Pairs a method descriptor with its server-side implementation.
  ///
  /// Pass an array of these to `Service.init(methods:)`.
  public struct MethodImpl {
    // internal so MethodImpl (which is public) can hold it
    let entry: MethodEntry

    /// Creates a method implementation.
    ///
    /// - Parameters:
    ///   - method: The method descriptor (name, number, serializers).
    ///   - impl: The handler closure. It receives the deserialized request
    ///     and the per-request metadata. Throw `ServiceError` to send a
    ///     specific HTTP status code; any other error produces a 500.
    public init<Request, Response>(
      _ method: SkirClient.Method<Request, Response>,
      impl: @escaping (Request, Meta) async throws -> Response
    ) {
      let reqSerializer = method.requestSerializer
      let respSerializer = method.responseSerializer
      entry = MethodEntry(
        name: method.name,
        number: method.number,
        doc: method.doc,
        requestTypeDescriptorJson: reqSerializer.typeDescriptor.asJson(),
        responseTypeDescriptorJson: respSerializer.typeDescriptor.asJson(),
        invoke: { requestJson, keepUnrecognized, readable, meta in
          let req: Request
          do {
            req = try reqSerializer.fromJson(requestJson, keepUnrecognized: keepUnrecognized)
          } catch {
            throw ServiceError(
              statusCode: ._400_BadRequest,
              message: "bad request: can't parse JSON: \(error)"
            )
          }
          let resp = try await impl(req, meta)
          return respSerializer.toJson(resp, readable: readable)
        }
      )
    }
  }

  // =========================================================================
  // MethodEntry (internal implementation detail)
  // =========================================================================

  struct MethodEntry {
    let name: String
    let number: Int64
    let doc: String
    let requestTypeDescriptorJson: String
    let responseTypeDescriptorJson: String
    /// (requestJson, keepUnrecognized, readable, meta) -> responseJson
    let invoke: (String, Bool, Bool, Meta) async throws -> String
  }

  // =========================================================================
  // Service state
  // =========================================================================

  private let keepUnrecognizedValues: Bool
  private let canSendUnknownErrorMessage: (MethodErrorInfo) -> Bool
  private let errorLogger: (MethodErrorInfo) -> Void
  private let studioAppJsUrl: String
  private let byNum: [Int64: MethodEntry]
  private let byName: [String: Int64]

  // =========================================================================
  // Request handling implementation
  // =========================================================================

  private func serveList() -> ServiceRawResponse {
    let entries = byNum.values.sorted { $0.number < $1.number }
    var methods: [[String: Any]] = []
    for e in entries {
      var obj: [String: Any] = [
        "method": e.name,
        "number": e.number,
      ]
      if let reqDesc = try? JSONSerialization.jsonObject(
        with: Data(e.requestTypeDescriptorJson.utf8))
      {
        obj["request"] = reqDesc
      }
      if let respDesc = try? JSONSerialization.jsonObject(
        with: Data(e.responseTypeDescriptorJson.utf8))
      {
        obj["response"] = respDesc
      }
      if !e.doc.isEmpty {
        obj["doc"] = e.doc
      }
      methods.append(obj)
    }
    let result: [String: Any] = ["methods": methods]
    guard let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
      let json = String(data: data, encoding: .utf8)
    else {
      return ServiceRawResponse.okJson("{}")
    }
    return ServiceRawResponse.okJson(json)
  }

  private func handleJsonRequest(_ body: String, meta: Meta) async -> ServiceRawResponse {
    guard let data = body.data(using: .utf8),
      let jsonValue = try? JSONSerialization.jsonObject(with: data)
    else {
      return ServiceRawResponse.badRequest("bad request: invalid JSON")
    }
    guard let obj = jsonValue as? [String: Any] else {
      return ServiceRawResponse.badRequest("bad request: expected JSON object")
    }
    guard let methodVal = obj["method"] else {
      return ServiceRawResponse.badRequest("bad request: missing 'method' field in JSON")
    }
    let entry: MethodEntry
    if let number = methodVal as? Int {
      guard let e = byNum[Int64(number)] else {
        return ServiceRawResponse.badRequest("bad request: method not found: \(number)")
      }
      entry = e
    } else if let number = methodVal as? Double, number == number.rounded() {
      guard let e = byNum[Int64(number)] else {
        return ServiceRawResponse.badRequest("bad request: method not found: \(Int64(number))")
      }
      entry = e
    } else if let name = methodVal as? String {
      guard let number = byName[name], let e = byNum[number] else {
        return ServiceRawResponse.badRequest("bad request: method not found: \(methodVal)")
      }
      entry = e
    } else {
      return ServiceRawResponse.badRequest(
        "bad request: 'method' field must be a string or integer")
    }
    guard let requestVal = obj["request"] else {
      return ServiceRawResponse.badRequest("bad request: missing 'request' field in JSON")
    }
    guard let requestData = try? JSONSerialization.data(withJSONObject: requestVal),
      let requestJson = String(data: requestData, encoding: .utf8)
    else {
      return ServiceRawResponse.badRequest("bad request: cannot re-serialize 'request' field")
    }
    return await invokeEntry(
      entry,
      requestJson: requestJson,
      keepUnrecognized: keepUnrecognizedValues,
      readable: true,
      meta: meta
    )
  }

  private func handleColonRequest(_ body: String, meta: Meta) async -> ServiceRawResponse {
    // Format: "name:number:format:requestJson"
    // number may be empty (lookup by name); format may be empty (dense).
    let parts = body.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
    guard parts.count == 4 else {
      return ServiceRawResponse.badRequest("bad request: invalid request format")
    }
    let nameStr = String(parts[0])
    let numberStr = String(parts[1])
    let format = String(parts[2])
    let requestJson = parts[3].isEmpty ? "{}" : String(parts[3])

    let entry: MethodEntry
    if numberStr.isEmpty {
      guard let number = byName[nameStr], let e = byNum[number] else {
        return ServiceRawResponse.badRequest("bad request: method not found: \(nameStr)")
      }
      entry = e
    } else {
      guard let number = Int64(numberStr) else {
        return ServiceRawResponse.badRequest("bad request: can't parse method number")
      }
      guard let e = byNum[number] else {
        return ServiceRawResponse.badRequest(
          "bad request: method not found: \(nameStr); number: \(number)")
      }
      entry = e
    }
    let readable = format == "readable"
    return await invokeEntry(
      entry,
      requestJson: requestJson,
      keepUnrecognized: keepUnrecognizedValues,
      readable: readable,
      meta: meta
    )
  }

  private func invokeEntry(
    _ entry: MethodEntry,
    requestJson: String,
    keepUnrecognized: Bool,
    readable: Bool,
    meta: Meta
  ) async -> ServiceRawResponse {
    do {
      let responseJson = try await entry.invoke(requestJson, keepUnrecognized, readable, meta)
      return ServiceRawResponse.okJson(responseJson)
    } catch {
      let info = MethodErrorInfo(
        error: error,
        methodName: entry.name,
        rawRequest: requestJson,
        requestMeta: meta
      )
      errorLogger(info)
      if let svcErr = error as? ServiceError {
        let msg =
          svcErr.message.isEmpty
          ? httpStatusText(svcErr.statusCode.asInt)
          : svcErr.message
        return ServiceRawResponse.serverError(msg, statusCode: svcErr.statusCode.asInt)
      } else {
        let msg =
          canSendUnknownErrorMessage(info)
          ? "server error: \(error)"
          : "server error"
        return ServiceRawResponse.serverError(msg, statusCode: 500)
      }
    }
  }

  private func serveStudio(_ jsUrl: String) -> ServiceRawResponse {
    ServiceRawResponse.okHtml(studioHtml(jsUrl))
  }
}

// =========================================================================
// Helpers
// =========================================================================

private func studioHtml(_ jsUrl: String) -> String {
  let safe = htmlEscapeAttr(jsUrl)
  // Copied from https://github.com/gepheum/skir-studio/blob/main/index.jsdeliver.html
  return """
    <!DOCTYPE html><html>
      <head>
        <meta charset="utf-8" />
        <title>RPC Studio</title>
        <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>\u{26A1}</text></svg>">
        <script src="\(safe)"></script>
      </head>
      <body style="margin: 0; padding: 0;">
        <skir-studio-app></skir-studio-app>
      </body>
    </html>
    """
}

private func htmlEscapeAttr(_ s: String) -> String {
  s.replacingOccurrences(of: "&", with: "&amp;")
    .replacingOccurrences(of: "\"", with: "&#34;")
    .replacingOccurrences(of: "<", with: "&lt;")
    .replacingOccurrences(of: ">", with: "&gt;")
}

private func httpStatusText(_ code: Int) -> String {
  switch code {
  case 200: return "OK"
  case 400: return "Bad Request"
  case 401: return "Unauthorized"
  case 403: return "Forbidden"
  case 404: return "Not Found"
  case 409: return "Conflict"
  case 422: return "Unprocessable Entity"
  case 429: return "Too Many Requests"
  case 500: return "Internal Server Error"
  case 502: return "Bad Gateway"
  case 503: return "Service Unavailable"
  default: return "Error"
  }
}

// =========================================================================
// ServiceRawResponse
// =========================================================================

/// The raw HTTP response to return from a service handler.
///
/// Pass these fields directly to your HTTP framework's response writer.
public struct ServiceRawResponse {
  /// The response body.
  public let data: String
  /// The HTTP status code (e.g. 200, 400, 500).
  public let statusCode: Int
  /// The value for the `Content-Type` response header.
  public let contentType: String

  static func okJson(_ data: String) -> ServiceRawResponse {
    ServiceRawResponse(data: data, statusCode: 200, contentType: "application/json")
  }

  static func okHtml(_ data: String) -> ServiceRawResponse {
    ServiceRawResponse(data: data, statusCode: 200, contentType: "text/html; charset=utf-8")
  }

  static func badRequest(_ msg: String) -> ServiceRawResponse {
    ServiceRawResponse(data: msg, statusCode: 400, contentType: "text/plain; charset=utf-8")
  }

  static func serverError(_ msg: String, statusCode: Int) -> ServiceRawResponse {
    ServiceRawResponse(data: msg, statusCode: statusCode, contentType: "text/plain; charset=utf-8")
  }
}

// =========================================================================
// HttpErrorCode
// =========================================================================

/// An HTTP error status code (4xx or 5xx).
public enum HttpErrorCode: Int {
  case _400_BadRequest = 400
  case _401_Unauthorized = 401
  case _402_PaymentRequired = 402
  case _403_Forbidden = 403
  case _404_NotFound = 404
  case _405_MethodNotAllowed = 405
  case _406_NotAcceptable = 406
  case _407_ProxyAuthenticationRequired = 407
  case _408_RequestTimeout = 408
  case _409_Conflict = 409
  case _410_Gone = 410
  case _411_LengthRequired = 411
  case _412_PreconditionFailed = 412
  case _413_ContentTooLarge = 413
  case _414_UriTooLong = 414
  case _415_UnsupportedMediaType = 415
  case _416_RangeNotSatisfiable = 416
  case _417_ExpectationFailed = 417
  case _418_ImATeapot = 418
  case _421_MisdirectedRequest = 421
  case _422_UnprocessableContent = 422
  case _423_Locked = 423
  case _424_FailedDependency = 424
  case _425_TooEarly = 425
  case _426_UpgradeRequired = 426
  case _428_PreconditionRequired = 428
  case _429_TooManyRequests = 429
  case _431_RequestHeaderFieldsTooLarge = 431
  case _451_UnavailableForLegalReasons = 451
  case _500_InternalServerError = 500
  case _501_NotImplemented = 501
  case _502_BadGateway = 502
  case _503_ServiceUnavailable = 503
  case _504_GatewayTimeout = 504
  case _505_HttpVersionNotSupported = 505
  case _506_VariantAlsoNegotiates = 506
  case _507_InsufficientStorage = 507
  case _508_LoopDetected = 508
  case _510_NotExtended = 510
  case _511_NetworkAuthenticationRequired = 511

  /// The numeric HTTP status code.
  public var asInt: Int { rawValue }
}

// =========================================================================
// ServiceError
// =========================================================================

/// Throw this from a method implementation to control the HTTP response
/// sent to the client on error.
///
/// Any other error propagated from a method implementation results in a 500
/// response; the message is optionally forwarded to the client via
/// `Service.init(canSendUnknownErrorMessage:)`.
public struct ServiceError: Error {
  /// The HTTP status code to send (e.g. 400, 403, 404, 500).
  public let statusCode: HttpErrorCode
  /// The message to send to the client.
  public let message: String

  public init(statusCode: HttpErrorCode, message: String) {
    self.statusCode = statusCode
    self.message = message
  }
}
