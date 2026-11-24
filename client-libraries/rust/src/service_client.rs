use super::method::Method;
use super::serializer::{JsonFlavor, UnrecognizedValues};

// =============================================================================
// RpcError
// =============================================================================

/// Error returned by [`ServiceClient::invoke_remote`] when the server responds
/// with a non-2xx status code or when a network-level failure occurs.
#[derive(Debug, Clone, thiserror::Error)]
#[error("rpc error {status_code}: {message}")]
pub struct RpcError {
    /// The HTTP status code returned by the server, or `0` for network-level
    /// failures (e.g. DNS error, connection refused, timeout).
    pub status_code: u16,
    /// A human-readable description of the error.
    pub message: String,
}

// =============================================================================
// ServiceClient
// =============================================================================

/// Sends RPCs to a SkirRPC service.
///
/// # Example
///
/// ```no_run
/// # use skir_client::service_client::ServiceClient;
/// # async fn example() {
/// let client = ServiceClient::new("http://localhost:8787/myapi").unwrap();
/// // let resp = client.invoke_remote(my_method, &request, &[]).await.unwrap();
/// # }
/// ```
pub struct ServiceClient {
    service_url: String,
    default_headers: Vec<(String, String)>,
    http_client: reqwest::Client,
}

impl ServiceClient {
    /// Creates a `ServiceClient` pointing at `service_url`.
    ///
    /// # Errors
    ///
    /// Returns an error if `service_url` contains a query string.
    pub fn new(service_url: impl Into<String>) -> Result<Self, String> {
        let url = service_url.into();
        if url.contains('?') {
            return Err("service URL must not contain a query string".to_owned());
        }
        Ok(Self {
            service_url: url,
            default_headers: Vec::new(),
            http_client: reqwest::Client::new(),
        })
    }

    /// Adds a default HTTP header sent with every invocation.
    ///
    /// Can be chained: `client.with_default_header("Authorization", "Bearer …")`.
    pub fn with_default_header(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.default_headers.push((key.into(), value.into()));
        self
    }

    /// Invokes `method` on the remote service with the given `request`.
    ///
    /// `extra_headers` is a slice of `(name, value)` pairs added (or
    /// overriding) the default headers for this specific call only.
    ///
    /// The request is serialized as dense JSON.  The response is deserialized
    /// keeping any unrecognized values (the server may have a newer schema).
    ///
    /// # Errors
    ///
    /// Returns [`RpcError`] if the server responds with a non-2xx status code
    /// or if a network-level failure occurs.
    ///
    /// # Calling from synchronous code
    ///
    /// If you need to call this from a synchronous context, spin up a
    /// single-threaded Tokio runtime yourself:
    ///
    /// ```ignore
    /// # use skir_client::service_client::ServiceClient;
    /// # fn example() {
    /// # let client = ServiceClient::new("http://localhost:8787/myapi").unwrap();
    /// # let (method, request) = todo!();
    /// let result = tokio::runtime::Builder::new_current_thread()
    ///     .enable_all()
    ///     .build()
    ///     .unwrap()
    ///     .block_on(client.invoke_remote(method, &request, &[]));
    /// # }
    /// ```
    pub async fn invoke_remote<Req, Resp>(
        &self,
        method: &Method<Req, Resp>,
        request: &Req,
        extra_headers: &[(&str, &str)],
    ) -> Result<Resp, RpcError>
    where
        Req: 'static,
        Resp: 'static,
    {
        // Serialize the request as dense JSON.
        let request_json = method
            .request_serializer
            .to_json(request, JsonFlavor::Dense);

        // Wire body: "MethodName:number::requestJson"
        // The empty third field means the server may reply in dense JSON.
        let wire_body = format!("{}:{}::{}", method.name, method.number, request_json);

        let mut req_builder = self
            .http_client
            .post(&self.service_url)
            .header("Content-Type", "text/plain; charset=utf-8");
        for (k, v) in &self.default_headers {
            req_builder = req_builder.header(k.as_str(), v.as_str());
        }
        for &(k, v) in extra_headers {
            req_builder = req_builder.header(k, v);
        }

        let resp = req_builder
            .body(wire_body)
            .send()
            .await
            .map_err(|e| RpcError {
                status_code: e.status().map(|s| s.as_u16()).unwrap_or(0),
                message: e.to_string(),
            })?;

        let status = resp.status();
        if !status.is_success() {
            let status_code = status.as_u16();
            let message = if resp
                .headers()
                .get("content-type")
                .and_then(|ct| ct.to_str().ok())
                .map(|ct| ct.contains("text/plain"))
                .unwrap_or(false)
            {
                resp.text().await.unwrap_or_default()
            } else {
                String::new()
            };
            return Err(RpcError {
                status_code,
                message,
            });
        }

        let resp_body = resp.text().await.map_err(|e| RpcError {
            status_code: 0,
            message: format!("failed to read response body: {e}"),
        })?;

        method
            .response_serializer
            .from_json(&resp_body, UnrecognizedValues::Keep)
            .map_err(|e| RpcError {
                status_code: 0,
                message: format!("failed to decode response: {e}"),
            })
    }
}
