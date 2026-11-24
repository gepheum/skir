part of "../skir_client.dart";

/// Raw response returned by the server.
class RawResponse {
  final String data;
  final int statusCode;
  final String contentType;

  const RawResponse({
    required this.data,
    required this.statusCode,
    required this.contentType,
  });

  static RawResponse _okJson(String data) {
    return RawResponse(
      data: data,
      statusCode: 200,
      contentType: 'application/json',
    );
  }

  static RawResponse _okHtml(String data) {
    return RawResponse(
      data: data,
      statusCode: 200,
      contentType: 'text/html; charset=utf-8',
    );
  }

  static RawResponse _badRequest(String data) {
    return RawResponse(
      data: data,
      statusCode: 400,
      contentType: 'text/plain; charset=utf-8',
    );
  }

  static RawResponse _serverError(String data, [int statusCode = 500]) {
    return RawResponse(
      data: data,
      statusCode: statusCode,
      contentType: 'text/plain; charset=utf-8',
    );
  }
}

/// HTTP status codes for errors.
enum HttpErrorCode {
  badRequest(400),
  unauthorized(401),
  paymentRequired(402),
  forbidden(403),
  notFound(404),
  methodNotAllowed(405),
  notAcceptable(406),
  proxyAuthenticationRequired(407),
  requestTimeout(408),
  conflict(409),
  gone(410),
  lengthRequired(411),
  preconditionFailed(412),
  contentTooLarge(413),
  uriTooLong(414),
  unsupportedMediaType(415),
  rangeNotSatisfiable(416),
  expectationFailed(417),
  imATeapot(418),
  misdirectedRequest(421),
  unprocessableContent(422),
  locked(423),
  failedDependency(424),
  tooEarly(425),
  upgradeRequired(426),
  preconditionRequired(428),
  tooManyRequests(429),
  requestHeaderFieldsTooLarge(431),
  unavailableForLegalReasons(451),
  internalServerError(500),
  notImplemented(501),
  badGateway(502),
  serviceUnavailable(503),
  gatewayTimeout(504),
  httpVersionNotSupported(505),
  variantAlsoNegotiates(506),
  insufficientStorage(507),
  loopDetected(508),
  notExtended(510),
  networkAuthenticationRequired(511);

  final int code;

  const HttpErrorCode(this.code);
}

/// If this error is thrown from a method implementation, the specified status
/// code and message will be returned in the HTTP response.
///
/// If any other type of exception is thrown, the response status code will be
/// 500 (Internal Server Error).
class ServiceError implements Exception {
  final HttpErrorCode statusCode;
  final String? message;

  ServiceError(this.statusCode, [this.message]);

  RawResponse toRawResponse() {
    final msg = message ?? _defaultMessage(statusCode);
    return RawResponse._serverError(msg, statusCode.code);
  }

  @override
  String toString() => message ?? _defaultMessage(statusCode);

  static String _defaultMessage(HttpErrorCode code) {
    switch (code) {
      case HttpErrorCode.badRequest:
        return 'Bad Request';
      case HttpErrorCode.unauthorized:
        return 'Unauthorized';
      case HttpErrorCode.paymentRequired:
        return 'Payment Required';
      case HttpErrorCode.forbidden:
        return 'Forbidden';
      case HttpErrorCode.notFound:
        return 'Not Found';
      case HttpErrorCode.methodNotAllowed:
        return 'Method Not Allowed';
      case HttpErrorCode.notAcceptable:
        return 'Not Acceptable';
      case HttpErrorCode.proxyAuthenticationRequired:
        return 'Proxy Authentication Required';
      case HttpErrorCode.requestTimeout:
        return 'Request Timeout';
      case HttpErrorCode.conflict:
        return 'Conflict';
      case HttpErrorCode.gone:
        return 'Gone';
      case HttpErrorCode.lengthRequired:
        return 'Length Required';
      case HttpErrorCode.preconditionFailed:
        return 'Precondition Failed';
      case HttpErrorCode.contentTooLarge:
        return 'Content Too Large';
      case HttpErrorCode.uriTooLong:
        return 'URI Too Long';
      case HttpErrorCode.unsupportedMediaType:
        return 'Unsupported Media Type';
      case HttpErrorCode.rangeNotSatisfiable:
        return 'Range Not Satisfiable';
      case HttpErrorCode.expectationFailed:
        return 'Expectation Failed';
      case HttpErrorCode.imATeapot:
        return "I'm a teapot";
      case HttpErrorCode.misdirectedRequest:
        return 'Misdirected Request';
      case HttpErrorCode.unprocessableContent:
        return 'Unprocessable Content';
      case HttpErrorCode.locked:
        return 'Locked';
      case HttpErrorCode.failedDependency:
        return 'Failed Dependency';
      case HttpErrorCode.tooEarly:
        return 'Too Early';
      case HttpErrorCode.upgradeRequired:
        return 'Upgrade Required';
      case HttpErrorCode.preconditionRequired:
        return 'Precondition Required';
      case HttpErrorCode.tooManyRequests:
        return 'Too Many Requests';
      case HttpErrorCode.requestHeaderFieldsTooLarge:
        return 'Request Header Fields Too Large';
      case HttpErrorCode.unavailableForLegalReasons:
        return 'Unavailable For Legal Reasons';
      case HttpErrorCode.internalServerError:
        return 'Internal Server Error';
      case HttpErrorCode.notImplemented:
        return 'Not Implemented';
      case HttpErrorCode.badGateway:
        return 'Bad Gateway';
      case HttpErrorCode.serviceUnavailable:
        return 'Service Unavailable';
      case HttpErrorCode.gatewayTimeout:
        return 'Gateway Timeout';
      case HttpErrorCode.httpVersionNotSupported:
        return 'HTTP Version Not Supported';
      case HttpErrorCode.variantAlsoNegotiates:
        return 'Variant Also Negotiates';
      case HttpErrorCode.insufficientStorage:
        return 'Insufficient Storage';
      case HttpErrorCode.loopDetected:
        return 'Loop Detected';
      case HttpErrorCode.notExtended:
        return 'Not Extended';
      case HttpErrorCode.networkAuthenticationRequired:
        return 'Network Authentication Required';
    }
  }
}

/// Information about an error thrown during the execution of a method on the
/// server side.
class MethodErrorInfo<RequestMeta> {
  /// The exception that was thrown.
  dynamic error;

  /// The method that was being executed when the error occurred.
  Method<dynamic, dynamic> method;

  /// Parsed request passed to the method's implementation.
  dynamic request;

  /// Metadata coming from the HTTP headers of the request.
  RequestMeta requestMeta;

  MethodErrorInfo({
    required this.error,
    required this.method,
    required this.request,
    required this.requestMeta,
  });
}

/// Configuration options for a SkirRPC service.
class ServiceOptions<RequestMeta> {
  /// Whether to keep unrecognized values when deserializing requests.
  ///
  /// Only enable this for data from trusted sources. Malicious actors could
  /// inject fields with IDs not yet defined in your schema. If you preserve
  /// this data and later define those IDs in a future schema version, the
  /// injected data could be deserialized as valid fields, leading to security
  /// vulnerabilities or data corruption.
  bool keepUnrecognizedValues = false;

  /// A predicate which determines whether the message of an unknown error (i.e.
  /// not a [ServiceError]) can be sent to the client in the response body. Can
  /// help with debugging.
  ///
  /// By default, unknown errors are masked and the client receives a generic
  /// 'server error' message with status 500. This is to prevent leaking
  /// sensitive information to the client.
  ///
  /// You can enable this if your server is internal or if you are sure that
  /// your error messages are safe to expose. By passing a predicate instead of
  /// true or false, you can control on a per-error basis whether to expose the
  /// error message; for example, you can send error messages only if the user
  /// is an admin.
  bool Function(MethodErrorInfo<RequestMeta>) canSendUnknownErrorMessage =
      (_) => false;

  /// Callback invoked whenever an error is thrown during method execution.
  ///
  /// Use this to log errors for monitoring, debugging, or alerting purposes.
  ///
  /// Defaults to a function which prints the method name and error message to
  /// stderr.
  void Function(MethodErrorInfo<RequestMeta>) errorLogger =
      _defaultErrorLogger<RequestMeta>;

  /// URL to the JavaScript file for the Skir Studio app.
  ///
  /// Skir Studio is a web interface for exploring and testing your Skir
  /// service. It is served when the service receives a request at
  /// '${serviceUrl}?studio'.
  String studioAppJsUrl =
      'https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js';

  static void _defaultErrorLogger<RequestMeta>(
      MethodErrorInfo<RequestMeta> errorInfo) {
    final methodName = errorInfo.method.name;
    stderr.writeln('Error in method $methodName: ${errorInfo.error}');
  }
}

/// Unmodifiable view of a [Service].
abstract class RequestHandler<RequestMeta> {
  /// Parses the content of a user request and invokes the appropriate method.
  ///
  /// If the request is a GET request, pass in the decoded query string as the
  /// request's body. The query string is the part of the URL after '?', and it
  /// can be decoded with [Uri.decodeComponent].
  Future<RawResponse> handleRequest(
    String requestBody,
    RequestMeta requestMeta,
  );
}

/// Implementation of a skir RPC service that handles incoming requests.
///
/// A service manages method implementations and provides request routing,
/// serialization, and error handling for RPC operations.
///
/// See https://github.com/gepheum/skir-dart-example/blob/main/bin/start_service.dart
/// for a full example of how to create a SkirRPC service and install it on an
/// HTTP server using the Shelf framework.
class Service<RequestMeta> implements RequestHandler<RequestMeta> {
  final Map<int, _MethodImpl<dynamic, dynamic, RequestMeta>> _methodImpls;
  final options = ServiceOptions<RequestMeta>();

  Service() : _methodImpls = {};

  /// Adds a method implementation to the service.
  void addMethod<Request, Response>(
    Method<Request, Response> method,
    Future<Response> Function(Request request, RequestMeta requestMeta) impl,
  ) {
    final number = method.number;
    if (_methodImpls.containsKey(number)) {
      throw ArgumentError(
        'Method with the same number already registered ($number)',
      );
    }
    // Type-safe wrapper
    Future<dynamic> dynamicImpl(dynamic request, RequestMeta requestMeta) {
      return impl(request as Request, requestMeta);
    }

    _methodImpls[number] = _MethodImpl(method, dynamicImpl);
  }

  /// Parses the content of a user request and invokes the appropriate method.
  ///
  /// If the request is a GET request, pass in the decoded query string as the
  /// request's body. The query string is the part of the URL after '?', and it
  /// can be decoded with [Uri.decodeComponent].
  @override
  Future<RawResponse> handleRequest(
    String requestBody,
    RequestMeta requestMeta,
  ) async {
    if (requestBody == 'list') {
      final methodsData = _methodImpls.values
          .map(
            (methodImpl) => _JsonObjectBuilder()
                .put("method", methodImpl.method.name)
                .put("number", methodImpl.method.number)
                .put(
                  "request",
                  methodImpl.method.requestSerializer.typeDescriptor.asJson,
                )
                .put(
                  "response",
                  methodImpl.method.responseSerializer.typeDescriptor.asJson,
                )
                .putIf("doc", methodImpl.method.doc, (doc) => doc.isNotEmpty)
                .build(),
          )
          .toList();

      final json = {'methods': methodsData};
      const encoder = JsonEncoder.withIndent('  ');
      final jsonCode = encoder.convert(json);
      return RawResponse._okJson(jsonCode);
    } else if (requestBody.isEmpty || requestBody == 'studio') {
      final studioHtml = _getStudioHtml(options.studioAppJsUrl);
      return RawResponse._okHtml(studioHtml);
    }

    // Parse request
    final String methodName;
    final int? methodNumber;
    final String format;
    final dynamic requestData;
    final bool requestDataIsJson;

    final firstChar = requestBody[0];
    if (firstChar == '{' || firstChar.trim().isEmpty) {
      // A JSON object
      final dynamic reqBodyJson;
      try {
        reqBodyJson = jsonDecode(requestBody);
      } catch (e) {
        return RawResponse._badRequest('bad request: invalid JSON');
      }

      if (reqBodyJson is! Map) {
        return RawResponse._badRequest('bad request: expected JSON object');
      }

      final methodField = reqBodyJson['method'];
      if (methodField == null) {
        return RawResponse._badRequest(
          'bad request: missing \'method\' field in JSON',
        );
      }

      if (methodField is String) {
        methodName = methodField;
        methodNumber = null;
      } else if (methodField is int) {
        methodName = '?';
        methodNumber = methodField;
      } else {
        return RawResponse._badRequest(
          'bad request: \'method\' field must be a string or an integer',
        );
      }

      format = 'readable';
      final requestField = reqBodyJson['request'];
      if (requestField == null) {
        return RawResponse._badRequest(
          'bad request: missing \'request\' field in JSON',
        );
      }
      requestData = requestField;
      requestDataIsJson = true;
    } else {
      // A colon-separated string
      final regex = RegExp(r'^([^:]*):([^:]*):([^:]*):([\s\S]*?)$');
      final match = regex.firstMatch(requestBody);
      if (match == null) {
        return RawResponse._badRequest('bad request: invalid request format');
      }

      methodName = match.group(1)!;
      final methodNumberStr = match.group(2)!;
      format = match.group(3)!;
      requestData = match.group(4)!;
      requestDataIsJson = false;

      if (methodNumberStr.isNotEmpty) {
        final methodNumberRegex = RegExp(r'^-?[0-9]+$');
        if (!methodNumberRegex.hasMatch(methodNumberStr)) {
          return RawResponse._badRequest(
            'bad request: can\'t parse method number',
          );
        }
        methodNumber = int.parse(methodNumberStr);
      } else {
        methodNumber = null;
      }
    }

    // Look up method by number or name
    final int resolvedMethodNumber;
    if (methodNumber == null) {
      // Try to get the method number by name
      final nameMatches = _methodImpls.values
          .where((m) => m.method.name == methodName)
          .toList();
      if (nameMatches.isEmpty) {
        return RawResponse._badRequest(
          'bad request: method not found: $methodName',
        );
      } else if (nameMatches.length > 1) {
        return RawResponse._badRequest(
          'bad request: method name \'$methodName\' is ambiguous; '
          'use method number instead',
        );
      }
      resolvedMethodNumber = nameMatches[0].method.number;
    } else {
      resolvedMethodNumber = methodNumber;
    }

    final methodImpl = _methodImpls[resolvedMethodNumber];
    if (methodImpl == null) {
      return RawResponse._badRequest(
        'bad request: method not found: $methodName; number: $resolvedMethodNumber',
      );
    }

    final dynamic request;
    try {
      if (requestDataIsJson) {
        request = methodImpl.method.requestSerializer.fromJson(
          requestData,
          keepUnrecognizedValues: options.keepUnrecognizedValues,
        );
      } else {
        request = methodImpl.method.requestSerializer.fromJsonCode(
          requestData as String,
          keepUnrecognizedValues: options.keepUnrecognizedValues,
        );
      }
    } catch (e) {
      return RawResponse._badRequest(
        'bad request: can\'t parse JSON: ${e.toString()}',
      );
    }

    final dynamic response;
    try {
      response = await methodImpl.impl(request, requestMeta);
    } catch (e) {
      final errorInfo = MethodErrorInfo<RequestMeta>(
        error: e,
        method: methodImpl.method,
        request: request,
        requestMeta: requestMeta,
      );
      options.errorLogger(errorInfo);
      if (e is ServiceError) {
        return e.toRawResponse();
      } else {
        final message = options.canSendUnknownErrorMessage(errorInfo)
            ? 'server error: ${e.toString()}'
            : 'server error';
        return RawResponse._serverError(message);
      }
    }

    final String responseJson;
    try {
      final readableFlavor = format == 'readable';
      responseJson = methodImpl.method.responseSerializer.toJsonCode(
        response,
        readableFlavor: readableFlavor,
      );
    } catch (e) {
      return RawResponse._serverError(
        "server error: can't serialize response to JSON: ${e.toString()}",
      );
    }

    return RawResponse._okJson(responseJson);
  }
}

/// Internal method implementation wrapper.
class _MethodImpl<Request, Response, RequestMeta> {
  final Method<Request, Response> method;
  final Future<dynamic> Function(dynamic, RequestMeta) impl;

  _MethodImpl(this.method, this.impl);
}

/// Generates the Studio HTML content for interactive API testing.
String _getStudioHtml(String studioAppJsUrl) {
  // Copied from
  //   https://github.com/gepheum/skir-studio/blob/main/index.jsdeliver.html
  final escapedUrl = const HtmlEscape().convert(studioAppJsUrl);
  return '''<!DOCTYPE html>

<html>
  <head>
    <meta charset="utf-8" />
    <title>RPC Studio</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🐙</text></svg>">
    <script src="$escapedUrl"></script>
  </head>
  <body style="margin: 0; padding: 0;">
    <skir-studio-app></skir-studio-app>
  </body>
</html>
''';
}
