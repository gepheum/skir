namespace SkirClient;

/// <summary>
/// Represents a service method declared with the <c>method</c> keyword in the
/// .skir file. Carries metadata (name, number, documentation) and the
/// request/response serializers needed for routing and encoding RPC calls.
/// </summary>
/// <typeparam name="TRequest">Generated request payload type.</typeparam>
/// <typeparam name="TResponse">Generated response payload type.</typeparam>
/// <param name="Name">Method name in the schema.</param>
/// <param name="Number">Stable numeric method identifier.</param>
/// <param name="Doc">Method documentation from the schema.</param>
/// <param name="RequestSerializer">Serializer used for request values.</param>
/// <param name="ResponseSerializer">Serializer used for response values.</param>
public sealed record Method<TRequest, TResponse>(
    string Name,
    int Number,
    string Doc,
    Serializer<TRequest> RequestSerializer,
    Serializer<TResponse> ResponseSerializer);
