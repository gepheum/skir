namespace SkirClient;

/// <summary>
/// Error returned by <see cref="ServiceClient.InvokeRemote{TRequest,TResponse}(Method{TRequest,TResponse}, TRequest, IEnumerable{KeyValuePair{string, string}}?, CancellationToken)"/>
/// when the server responds with a non-2xx status code or when a network-level failure occurs.
/// </summary>
public sealed class RpcError : Exception
{
    /// <summary>
    /// HTTP status code from the server, or <c>0</c> when no HTTP response was
    /// available (for example timeout, cancellation, or transport failure).
    /// </summary>
    public ushort StatusCode { get; }

    /// <summary>Creates a new RPC error.</summary>
    /// <param name="statusCode">HTTP status code, or <c>0</c> when unavailable.</param>
    /// <param name="message">Human-readable error message.</param>
    public RpcError(ushort statusCode, string message)
        : base(message)
    {
        StatusCode = statusCode;
    }
}

/// <summary>
/// Sends RPCs to a SkirRPC service.
/// <para>
/// Reuse the same instance for multiple calls so default headers and
/// connection pooling are shared.
/// </para>
/// <para>
/// Example:
/// </para>
/// <code>
/// var client = new ServiceClient("http://localhost:8787/myapi");
///
/// await client.InvokeRemote(
///     Methods.AddUser,
///     new AddUserRequest { User = user });
///
/// var resp = await client.InvokeRemote(
///     Methods.GetUser,
///     new GetUserRequest { UserId = 42 });
/// </code>
/// </summary>
public sealed class ServiceClient : IDisposable
{
    private readonly string _serviceUrl;
    private readonly List<KeyValuePair<string, string>> _defaultHeaders = [];
    private readonly HttpClient _httpClient;
    private bool _disposed;

    /// <summary>
    /// Creates a client for a service endpoint.
    /// </summary>
    /// <param name="serviceUrl">
    /// Endpoint URL (for example <c>http://localhost:8787/myapi</c>). Do not
    /// include a query string.
    /// </param>
    public ServiceClient(string serviceUrl)
    {
        if (serviceUrl.Contains('?', StringComparison.Ordinal))
            throw new ArgumentException("service URL must not contain a query string", nameof(serviceUrl));

        _serviceUrl = serviceUrl;
        _httpClient = new HttpClient();
    }

    /// <summary>
    /// Adds a default HTTP header sent with every invocation.
    /// <para>
    /// Useful for auth tokens, tenant IDs, or tracing metadata.
    /// </para>
    /// </summary>
    public ServiceClient WithDefaultHeader(string key, string value)
    {
        ThrowIfDisposed();
        _defaultHeaders.Add(new KeyValuePair<string, string>(key, value));
        return this;
    }

    /// <summary>
    /// Invokes <paramref name="method"/> on the remote service with the given request.
    /// </summary>
    /// <typeparam name="TRequest">Generated request type.</typeparam>
    /// <typeparam name="TResponse">Generated response type.</typeparam>
    /// <param name="method">Generated method descriptor from the <c>Methods</c> class.</param>
    /// <param name="request">Request payload value.</param>
    /// <param name="extraHeaders">
    /// Optional per-call headers added in addition to default headers.
    /// </param>
    /// <param name="cancellationToken">Cancellation token for the HTTP request.</param>
    /// <exception cref="RpcError">
    /// Thrown when the server returns a non-success status code or when the
    /// request/response transport fails.
    /// </exception>
    /// <remarks>
    /// Per-call headers are useful for request-scoped metadata:
    /// <code>
    /// var response = await client.InvokeRemote(
    ///     Methods.GetUser,
    ///     new GetUserRequest { UserId = 42 },
    ///     extraHeaders: new[]
    ///     {
    ///         new KeyValuePair&lt;string, string&gt;("x-request-id", requestId)
    ///     },
    ///     cancellationToken: ct);
    /// </code>
    /// </remarks>
    public async Task<TResponse> InvokeRemote<TRequest, TResponse>(
        Method<TRequest, TResponse> method,
        TRequest request,
        IEnumerable<KeyValuePair<string, string>>? extraHeaders = null,
        CancellationToken cancellationToken = default)
    {
        ThrowIfDisposed();
        string requestJson = method.RequestSerializer.ToJson(request);

        // Wire body: "MethodName:number::requestJson"
        string wireBody = $"{method.Name}:{method.Number}::{requestJson}";

        using var requestMessage = new HttpRequestMessage(HttpMethod.Post, _serviceUrl)
        {
            Content = new StringContent(wireBody)
        };
        requestMessage.Content.Headers.ContentType =
            new System.Net.Http.Headers.MediaTypeHeaderValue("text/plain")
            {
                CharSet = "utf-8"
            };

        foreach (var header in _defaultHeaders)
            requestMessage.Headers.TryAddWithoutValidation(header.Key, header.Value);

        if (extraHeaders != null)
        {
            foreach (var header in extraHeaders)
                requestMessage.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }

        HttpResponseMessage response;
        try
        {
            response = await _httpClient.SendAsync(requestMessage, cancellationToken).ConfigureAwait(false);
        }
        catch (HttpRequestException ex)
        {
            ushort statusCode = ex.StatusCode.HasValue ? (ushort)ex.StatusCode.Value : (ushort)0;
            throw new RpcError(statusCode, ex.Message);
        }
        catch (TaskCanceledException ex)
        {
            throw new RpcError(0, ex.Message);
        }

        using (response)
        {
            if (!response.IsSuccessStatusCode)
            {
                ushort statusCode = (ushort)response.StatusCode;
                string message = string.Empty;
                string? contentType = response.Content.Headers.ContentType?.ToString();
                if (contentType != null && contentType.Contains("text/plain", StringComparison.Ordinal))
                    message = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

                throw new RpcError(statusCode, message);
            }

            string responseBody;
            try
            {
                responseBody = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                throw new RpcError(0, $"failed to read response body: {ex.Message}");
            }

            try
            {
                return method.ResponseSerializer.FromJson(responseBody, keepUnrecognizedValues: true);
            }
            catch (Exception ex)
            {
                throw new RpcError(0, $"failed to decode response: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Disposes the underlying HTTP resources owned by this client.
    /// </summary>
    public void Dispose()
    {
        if (_disposed)
            return;

        _httpClient.Dispose();
        _disposed = true;
        GC.SuppressFinalize(this);
    }

    private void ThrowIfDisposed()
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(ServiceClient));
    }
}
