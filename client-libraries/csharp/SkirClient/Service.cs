using System.Text.Json;
using System.Text.Json.Nodes;

namespace SkirClient;

/// <summary>
/// HTTP-style response returned by <see cref="Service{TMeta}.HandleRequest(string, TMeta)"/>.
/// </summary>
public sealed class RawResponse
{
    /// <summary>Response body to send to the caller.</summary>
    public required string Data { get; init; }

    /// <summary>HTTP status code to send to the caller.</summary>
    public required ushort StatusCode { get; init; }

    /// <summary>HTTP content type for <see cref="Data"/>.</summary>
    public required string ContentType { get; init; }

    internal static RawResponse OkJson(string data) => new()
    {
        Data = data,
        StatusCode = 200,
        ContentType = "application/json"
    };

    internal static RawResponse OkHtml(string data) => new()
    {
        Data = data,
        StatusCode = 200,
        ContentType = "text/html; charset=utf-8"
    };

    internal static RawResponse BadRequest(string msg) => new()
    {
        Data = msg,
        StatusCode = 400,
        ContentType = "text/plain; charset=utf-8"
    };

    internal static RawResponse ServerError(string msg, ushort statusCode) => new()
    {
        Data = msg,
        StatusCode = statusCode,
        ContentType = "text/plain; charset=utf-8"
    };
}

/// <summary>
/// HTTP error status values allowed in <see cref="ServiceError"/>.
/// </summary>
public enum HttpErrorCode : ushort
{
    _400_BadRequest = 400,
    _401_Unauthorized = 401,
    _402_PaymentRequired = 402,
    _403_Forbidden = 403,
    _404_NotFound = 404,
    _405_MethodNotAllowed = 405,
    _406_NotAcceptable = 406,
    _407_ProxyAuthenticationRequired = 407,
    _408_RequestTimeout = 408,
    _409_Conflict = 409,
    _410_Gone = 410,
    _411_LengthRequired = 411,
    _412_PreconditionFailed = 412,
    _413_ContentTooLarge = 413,
    _414_UriTooLong = 414,
    _415_UnsupportedMediaType = 415,
    _416_RangeNotSatisfiable = 416,
    _417_ExpectationFailed = 417,
    _418_ImATeapot = 418,
    _421_MisdirectedRequest = 421,
    _422_UnprocessableContent = 422,
    _423_Locked = 423,
    _424_FailedDependency = 424,
    _425_TooEarly = 425,
    _426_UpgradeRequired = 426,
    _428_PreconditionRequired = 428,
    _429_TooManyRequests = 429,
    _431_RequestHeaderFieldsTooLarge = 431,
    _451_UnavailableForLegalReasons = 451,
    _500_InternalServerError = 500,
    _501_NotImplemented = 501,
    _502_BadGateway = 502,
    _503_ServiceUnavailable = 503,
    _504_GatewayTimeout = 504,
    _505_HttpVersionNotSupported = 505,
    _506_VariantAlsoNegotiates = 506,
    _507_InsufficientStorage = 507,
    _508_LoopDetected = 508,
    _510_NotExtended = 510,
    _511_NetworkAuthenticationRequired = 511,
}

/// <summary>
/// Exception thrown by service method implementations to return a specific
/// HTTP error to the caller.
/// </summary>
public sealed class ServiceError : Exception
{
    /// <summary>The HTTP status code returned by the service.</summary>
    public HttpErrorCode StatusCode { get; }

    /// <summary>
    /// Creates a service error that will be returned by
    /// <see cref="Service{TMeta}.HandleRequest(string, TMeta)"/>.
    /// </summary>
    public ServiceError(HttpErrorCode statusCode, string message, Exception? source = null)
        : base(message, source)
    {
        StatusCode = statusCode;
    }
}

/// <summary>
/// Context passed to the service error logger and error visibility policy.
/// </summary>
public sealed class MethodErrorInfo<TMeta>
{
    /// <summary>The exception thrown while executing the method.</summary>
    public required Exception Error { get; init; }

    /// <summary>The method name as declared in generated <c>Methods</c>.</summary>
    public required string MethodName { get; init; }

    /// <summary>The raw JSON request payload for the method invocation.</summary>
    public required string RawRequest { get; init; }

    /// <summary>The metadata object passed to <see cref="Service{TMeta}.HandleRequest(string, TMeta)"/>.</summary>
    public required TMeta RequestMeta { get; init; }
}

/// <summary>
/// Runtime router for generated RPC methods.
/// <para>
/// Build an instance with <see cref="Builder"/>, register generated methods,
/// then call <see cref="HandleRequest(string, TMeta)"/> from your HTTP endpoint.
/// </para>
/// <para>
/// Typical setup:
/// </para>
/// <code>
/// var service = Service&lt;UnitMeta&gt;.Builder()
///     .AddMethod(Methods.GetUser, (req, _) =&gt;
///         Task.FromResult(new GetUserResponse { User = null }))
///     .AddMethod(Methods.AddUser, (req, _) =&gt;
///         Task.FromResult(AddUserResponse.Default))
///     .Build();
/// </code>
/// </summary>
public sealed class Service<TMeta>
{
    private readonly bool _keepUnrecognizedValues;
    private readonly Func<MethodErrorInfo<TMeta>, bool> _canSendUnknownErrorMessage;
    private readonly Action<MethodErrorInfo<TMeta>> _errorLogger;
    private readonly string _studioAppJsUrl;
    private readonly Dictionary<long, MethodEntry<TMeta>> _byNum;
    private readonly Dictionary<string, long> _byName;

    internal Service(
        bool keepUnrecognizedValues,
        Func<MethodErrorInfo<TMeta>, bool> canSendUnknownErrorMessage,
        Action<MethodErrorInfo<TMeta>> errorLogger,
        string studioAppJsUrl,
        Dictionary<long, MethodEntry<TMeta>> byNum,
        Dictionary<string, long> byName)
    {
        _keepUnrecognizedValues = keepUnrecognizedValues;
        _canSendUnknownErrorMessage = canSendUnknownErrorMessage;
        _errorLogger = errorLogger;
        _studioAppJsUrl = studioAppJsUrl;
        _byNum = byNum;
        _byName = byName;
    }

    /// <summary>
    /// Handles one RPC request and returns an HTTP-style response.
    /// <para>
    /// For GET routes, pass the decoded query string as <paramref name="body"/>.
    /// For POST routes, pass the request body text.
    /// </para>
    /// <para>
    /// The special bodies <c>"studio"</c> and <c>"list"</c> are reserved
    /// for built-in debug pages.
    /// </para>
    /// </summary>
    /// <param name="body">Incoming RPC payload.</param>
    /// <param name="meta">
    /// Per-request metadata forwarded to every registered method handler.
    /// </param>
    /// <returns>
    /// A response object containing status code, content type, and body.
    /// </returns>
    /// <remarks>
    /// Example ASP.NET integration:
    /// <code>
    /// app.MapGet("/myapi", async (HttpContext ctx) =&gt;
    /// {
    ///     string raw = ctx.Request.QueryString.HasValue
    ///         ? ctx.Request.QueryString.Value![1..]
    ///         : string.Empty;
    ///
    ///     string decoded;
    ///     try { decoded = Uri.UnescapeDataString(raw); }
    ///     catch { decoded = raw; }
    ///
    ///     RawResponse resp = await service.HandleRequest(decoded, new UnitMeta());
    ///     return Results.Content(resp.Data, resp.ContentType, Encoding.UTF8, resp.StatusCode);
    /// });
    ///
    /// app.MapPost("/myapi", async (HttpContext ctx) =&gt;
    /// {
    ///     using var reader = new StreamReader(ctx.Request.Body, Encoding.UTF8, detectEncodingFromByteOrderMarks: false);
    ///     string body = await reader.ReadToEndAsync();
    ///     RawResponse resp = await service.HandleRequest(body, new UnitMeta());
    ///     return Results.Content(resp.Data, resp.ContentType, Encoding.UTF8, resp.StatusCode);
    /// });
    /// </code>
    /// </remarks>
    public async Task<RawResponse> HandleRequest(string body, TMeta meta)
    {
        switch (body)
        {
            case "":
            case "studio":
                return ServeStudio(_studioAppJsUrl);
            case "list":
                return ServeList();
        }

        char first = body.Length == 0 ? ' ' : body[0];
        if (first == '{' || char.IsWhiteSpace(first))
            return await HandleJsonRequest(body, meta).ConfigureAwait(false);

        return await HandleColonRequest(body, meta).ConfigureAwait(false);
    }

    private RawResponse ServeList()
    {
        var entries = new List<MethodEntry<TMeta>>(_byNum.Values);
        entries.Sort((a, b) => a.Number.CompareTo(b.Number));

        var methods = new JsonArray();
        foreach (var entry in entries)
        {
            var obj = new JsonObject
            {
                ["method"] = entry.Name,
                ["number"] = entry.Number,
                ["request"] = ParseJsonOrNull(entry.RequestTypeDescriptorJson),
                ["response"] = ParseJsonOrNull(entry.ResponseTypeDescriptorJson),
            };
            if (!string.IsNullOrEmpty(entry.Doc))
                obj["doc"] = entry.Doc;
            methods.Add(obj);
        }

        var result = new JsonObject { ["methods"] = methods };
        string payload;
        try
        {
            payload = result.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
        }
        catch
        {
            payload = "{}";
        }

        return RawResponse.OkJson(payload);
    }

    private async Task<RawResponse> HandleJsonRequest(string body, TMeta meta)
    {
        JsonNode? root;
        try
        {
            root = JsonNode.Parse(body);
        }
        catch
        {
            return RawResponse.BadRequest("bad request: invalid JSON");
        }

        if (root is not JsonObject obj)
            return RawResponse.BadRequest("bad request: expected JSON object");

        if (!obj.TryGetPropertyValue("method", out JsonNode? methodNode) || methodNode == null)
            return RawResponse.BadRequest("bad request: missing 'method' field in JSON");

        MethodEntry<TMeta>? entry;
        switch (methodNode)
        {
            case JsonValue value when value.TryGetValue<long>(out long number):
                if (!_byNum.TryGetValue(number, out entry))
                    return RawResponse.BadRequest($"bad request: method not found: {number}");
                break;

            case JsonValue value when value.TryGetValue<string>(out string? name):
                if (name == null || !_byName.TryGetValue(name, out long numberByName))
                    return RawResponse.BadRequest($"bad request: method not found: {name}");
                entry = _byNum[numberByName];
                break;

            default:
                return RawResponse.BadRequest("bad request: 'method' field must be a string or integer");
        }

        if (!obj.TryGetPropertyValue("request", out JsonNode? requestNode) || requestNode == null)
            return RawResponse.BadRequest("bad request: missing 'request' field in JSON");

        string requestJson = requestNode.ToJsonString();
        return await InvokeEntry(entry!, requestJson, _keepUnrecognizedValues, readable: true, meta).ConfigureAwait(false);
    }

    private async Task<RawResponse> HandleColonRequest(string body, TMeta meta)
    {
        // Format: "name:number:format:requestJson"
        string[] parts = body.Split(':', 4);
        if (parts.Length != 4)
            return RawResponse.BadRequest("bad request: invalid request format");

        string nameStr = parts[0];
        string numberStr = parts[1];
        string format = parts[2];
        string requestJson = string.IsNullOrEmpty(parts[3]) ? "{}" : parts[3];

        MethodEntry<TMeta>? entry;
        if (string.IsNullOrEmpty(numberStr))
        {
            if (!_byName.TryGetValue(nameStr, out long numberFromName))
                return RawResponse.BadRequest($"bad request: method not found: {nameStr}");
            entry = _byNum[numberFromName];
        }
        else
        {
            if (!long.TryParse(numberStr, out long number))
                return RawResponse.BadRequest("bad request: can't parse method number");
            if (!_byNum.TryGetValue(number, out entry))
                return RawResponse.BadRequest($"bad request: method not found: {nameStr}; number: {number}");
        }

        bool readable = format == "readable";
        return await InvokeEntry(entry!, requestJson, _keepUnrecognizedValues, readable, meta).ConfigureAwait(false);
    }

    private async Task<RawResponse> InvokeEntry(
        MethodEntry<TMeta> entry,
        string requestJson,
        bool keepUnrecognized,
        bool readable,
        TMeta meta)
    {
        string rawRequest = requestJson;
        try
        {
            string responseJson = await entry.Invoke(requestJson, keepUnrecognized, readable, meta).ConfigureAwait(false);
            return RawResponse.OkJson(responseJson);
        }
        catch (Exception ex)
        {
            var info = new MethodErrorInfo<TMeta>
            {
                Error = ex,
                MethodName = entry.Name,
                RawRequest = rawRequest,
                RequestMeta = meta,
            };

            _errorLogger(info);

            if (ex is ServiceError svc)
            {
                string msg = string.IsNullOrEmpty(svc.Message)
                    ? HttpStatusText((ushort)svc.StatusCode)
                    : svc.Message;
                return RawResponse.ServerError(msg, (ushort)svc.StatusCode);
            }

            string unknownMessage = _canSendUnknownErrorMessage(info)
                ? $"server error: {ex.Message}"
                : "server error";
            return RawResponse.ServerError(unknownMessage, 500);
        }
    }

    private static JsonNode? ParseJsonOrNull(string json)
    {
        try
        {
            return JsonNode.Parse(json);
        }
        catch
        {
            return null;
        }
    }

    private static RawResponse ServeStudio(string jsUrl) => RawResponse.OkHtml(StudioHtml(jsUrl));

    private static string StudioHtml(string jsUrl)
    {
        string safe = HtmlEscapeAttr(jsUrl);
        return $"<!DOCTYPE html><html>\n  <head>\n    <meta charset=\"utf-8\" />\n    <title>RPC Studio</title>\n    <link rel=\"icon\" href=\"data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>%F0%9F%90%99</text></svg>\">\n    <script src=\"{safe}\"></script>\n  </head>\n  <body style=\"margin: 0; padding: 0;\">\n    <skir-studio-app></skir-studio-app>\n  </body>\n</html>";
    }

    private static string HtmlEscapeAttr(string s) =>
        s.Replace("&", "&amp;", StringComparison.Ordinal)
            .Replace("\"", "&#34;", StringComparison.Ordinal)
            .Replace("<", "&lt;", StringComparison.Ordinal)
            .Replace(">", "&gt;", StringComparison.Ordinal);

    private static string HttpStatusText(ushort code) =>
        code switch
        {
            200 => "OK",
            400 => "Bad Request",
            401 => "Unauthorized",
            403 => "Forbidden",
            404 => "Not Found",
            409 => "Conflict",
            422 => "Unprocessable Entity",
            429 => "Too Many Requests",
            500 => "Internal Server Error",
            502 => "Bad Gateway",
            503 => "Service Unavailable",
            _ => "Error",
        };

    private const string DefaultStudioAppJsUrl =
        "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js";

    /// <summary>
    /// Creates a fluent builder for registering generated methods.
    /// </summary>
    /// <remarks>
    /// Start with this method when wiring your service:
    /// <code>
    /// var service = Service&lt;UnitMeta&gt;.Builder()
    ///     .AddMethod(Methods.GetUser, (req, meta) =&gt;
    ///     {
    ///         // your domain logic here
    ///         return Task.FromResult(new GetUserResponse());
    ///     })
    ///     .Build();
    /// </code>
    /// </remarks>
    public static ServiceBuilder<TMeta> Builder() => new();

    internal static string DefaultStudioUrl => DefaultStudioAppJsUrl;
}

/// <summary>
/// Configures and builds a <see cref="Service{TMeta}"/>.
/// </summary>
public sealed class ServiceBuilder<TMeta>
{
    private bool _keepUnrecognizedValues;
    private Func<MethodErrorInfo<TMeta>, bool> _canSendUnknownErrorMessage = _ => false;
    private Action<MethodErrorInfo<TMeta>> _errorLogger =
        info => Console.Error.WriteLine($"skir: error in method \"{info.MethodName}\": {info.Error.Message}");
    private string _studioAppJsUrl = Service<TMeta>.DefaultStudioUrl;
    private readonly Dictionary<long, MethodEntry<TMeta>> _byNum = [];
    private readonly Dictionary<string, long> _byName = [];

    /// <summary>
    /// Registers one generated method implementation.
    /// </summary>
    /// <typeparam name="TRequest">Generated request type for the method.</typeparam>
    /// <typeparam name="TResponse">Generated response type for the method.</typeparam>
    /// <param name="method">Generated method descriptor from the <c>Methods</c> class.</param>
    /// <param name="impl">
    /// Method implementation. Throw <see cref="ServiceError"/> to return
    /// controlled client-facing HTTP errors.
    /// </param>
    /// <returns>The same builder for fluent chaining.</returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when another method with the same method number was already
    /// registered on this builder.
    /// </exception>
    /// <remarks>
    /// Example:
    /// <code>
    /// .AddMethod(Methods.AddUser, (req, _) =&gt;
    /// {
    ///     if (req.User.UserId == 0)
    ///         throw new ServiceError(HttpErrorCode._400_BadRequest, "user_id must be non-zero");
    ///
    ///     return Task.FromResult(AddUserResponse.Default);
    /// })
    /// </code>
    /// </remarks>
    public ServiceBuilder<TMeta> AddMethod<TRequest, TResponse>(
        Method<TRequest, TResponse> method,
        Func<TRequest, TMeta, Task<TResponse>> impl)
    {
        long number = method.Number;
        if (_byNum.ContainsKey(number))
            throw new InvalidOperationException($"skir: method number {number} already registered");

        var entry = new MethodEntry<TMeta>(
            method.Name,
            number,
            method.Doc,
            method.RequestSerializer.TypeDescriptor.AsJson(),
            method.ResponseSerializer.TypeDescriptor.AsJson(),
            async (requestJson, keepUnrecognized, readable, meta) =>
            {
                TRequest req;
                try
                {
                    req = method.RequestSerializer.FromJson(
                        requestJson,
                        keepUnrecognizedValues: keepUnrecognized);
                }
                catch (Exception ex)
                {
                    throw new ServiceError(
                        HttpErrorCode._400_BadRequest,
                        $"bad request: can't parse JSON: {ex.Message}");
                }

                TResponse resp = await impl(req, meta).ConfigureAwait(false);
                return method.ResponseSerializer.ToJson(resp, readable: readable);
            });

        _byName[method.Name] = number;
        _byNum[number] = entry;
        return this;
    }

    /// <summary>
    /// Controls whether unknown fields/variants are preserved while decoding
    /// incoming requests.
    /// </summary>
    /// <returns>The same builder for fluent chaining.</returns>
    public ServiceBuilder<TMeta> SetKeepUnrecognizedValues(bool keep)
    {
        _keepUnrecognizedValues = keep;
        return this;
    }

    /// <summary>
    /// Sets a global policy for whether unexpected server exceptions may be
    /// returned to clients with details.
    /// </summary>
    /// <returns>The same builder for fluent chaining.</returns>
    public ServiceBuilder<TMeta> SetCanSendUnknownErrorMessage(bool can)
    {
        _canSendUnknownErrorMessage = _ => can;
        return this;
    }

    /// <summary>
    /// Sets a per-request policy for whether unexpected server exception
    /// details may be returned to clients.
    /// </summary>
    /// <returns>The same builder for fluent chaining.</returns>
    public ServiceBuilder<TMeta> SetCanSendUnknownErrorMessageFn(Func<MethodErrorInfo<TMeta>, bool> predicate)
    {
        _canSendUnknownErrorMessage = predicate;
        return this;
    }

    /// <summary>
    /// Sets the callback invoked whenever a method implementation throws.
    /// </summary>
    /// <returns>The same builder for fluent chaining.</returns>
    public ServiceBuilder<TMeta> SetErrorLogger(Action<MethodErrorInfo<TMeta>> logger)
    {
        _errorLogger = logger;
        return this;
    }

    /// <summary>
    /// Overrides the JavaScript URL used by the built-in <c>studio</c> page.
    /// </summary>
    /// <returns>The same builder for fluent chaining.</returns>
    public ServiceBuilder<TMeta> SetStudioAppJsUrl(string url)
    {
        _studioAppJsUrl = url;
        return this;
    }

    /// <summary>
    /// Builds an immutable service instance ready to receive requests.
    /// </summary>
    public Service<TMeta> Build() =>
        new(
            _keepUnrecognizedValues,
            _canSendUnknownErrorMessage,
            _errorLogger,
            _studioAppJsUrl,
            _byNum,
            _byName);
}

/// <summary>
/// Internal method registration entry used by <see cref="Service{TMeta}"/>.
/// </summary>
internal sealed record MethodEntry<TMeta>(
    string Name,
    long Number,
    string Doc,
    string RequestTypeDescriptorJson,
    string ResponseTypeDescriptorJson,
    Func<string, bool, bool, TMeta, Task<string>> Invoke);
