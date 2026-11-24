use std::collections::HashMap;
use std::future::Future;
use std::pin::Pin;

use super::method::Method;
use super::serializer::{JsonFlavor, UnrecognizedValues};

// =============================================================================
// RawResponse
// =============================================================================

/// The raw HTTP response returned by [`Service::handle_request`].
///
/// Pass these fields directly to your HTTP framework's response writer.
#[derive(Debug, Clone)]
pub struct RawResponse {
    /// The response body.
    pub data: String,
    /// The HTTP status code (e.g. 200, 400, 500).
    pub status_code: u16,
    /// The value for the `Content-Type` response header.
    pub content_type: &'static str,
}

impl RawResponse {
    fn ok_json(data: String) -> Self {
        Self {
            data,
            status_code: 200,
            content_type: "application/json",
        }
    }

    fn ok_html(data: String) -> Self {
        Self {
            data,
            status_code: 200,
            content_type: "text/html; charset=utf-8",
        }
    }

    fn bad_request(msg: impl Into<String>) -> Self {
        Self {
            data: msg.into(),
            status_code: 400,
            content_type: "text/plain; charset=utf-8",
        }
    }

    fn server_error(msg: impl Into<String>, status_code: u16) -> Self {
        Self {
            data: msg.into(),
            status_code,
            content_type: "text/plain; charset=utf-8",
        }
    }
}

// =============================================================================
// HttpErrorCode
// =============================================================================

/// An HTTP error status code (4xx or 5xx).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(u16)]
#[allow(non_camel_case_types)]
pub enum HttpErrorCode {
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

impl HttpErrorCode {
    /// Returns the numeric HTTP status code.
    pub fn as_u16(self) -> u16 {
        self as u16
    }
}

impl std::fmt::Display for HttpErrorCode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_u16())
    }
}

// =============================================================================
// ServiceError
// =============================================================================

/// Return this from a method implementation (via [`anyhow::Error`]) to control
/// the HTTP response sent to the client on error.
///
/// Any other error type propagated through `anyhow` results in a 500 response;
/// the message is optionally forwarded to the client via
/// [`ServiceBuilder::set_can_send_unknown_error_message`].
#[derive(Debug, thiserror::Error)]
#[error("service error ({status_code}): {message}")]
pub struct ServiceError {
    /// The HTTP status code to send (e.g. 400, 403, 404, 500).
    pub status_code: HttpErrorCode,
    /// The message to send to the client.
    pub message: String,
    /// An optional underlying cause, not sent to the client.
    #[source]
    pub source: Option<anyhow::Error>,
}

// =============================================================================
// MethodErrorInfo
// =============================================================================

/// Context passed to the error logger when a method returns an error.
pub struct MethodErrorInfo<'a, Meta> {
    /// The error returned by the method. Downcast to [`ServiceError`] to
    /// distinguish HTTP errors from unknown internal errors.
    pub error: anyhow::Error,
    /// The name of the method that failed.
    pub method_name: &'a str,
    /// The raw JSON of the request that caused the error.
    pub raw_request: &'a str,
    /// The per-request metadata supplied by the HTTP handler.
    pub request_meta: &'a Meta,
}

// =============================================================================
// Service
// =============================================================================

/// Dispatches Skir RPC requests to registered method implementations.
///
/// Create one using [`ServiceBuilder`].
///
/// `RequestMeta` carries per-request context (e.g. HTTP headers, an
/// authenticated user identity) from your HTTP handler into method
/// implementations. Use `()` if you don't need per-request metadata.
pub struct Service<Meta> {
    keep_unrecognized_values: bool,
    can_send_unknown_error_message:
        Box<dyn for<'a> Fn(&MethodErrorInfo<'a, Meta>) -> bool + Send + Sync>,
    error_logger: Box<dyn for<'a> Fn(&MethodErrorInfo<'a, Meta>) + Send + Sync>,
    studio_app_js_url: String,
    by_num: HashMap<i64, MethodEntry<Meta>>,
    by_name: HashMap<String, i64>,
}

impl<Meta> Service<Meta>
where
    Meta: Clone + Send + Sync + 'static,
{
    /// Parses `body` and dispatches to the appropriate registered method.
    ///
    /// For GET requests in a standard HTTP stack, pass the decoded query string
    /// as `body`. For POST requests, pass the raw request body.
    pub async fn handle_request(&self, body: &str, meta: Meta) -> RawResponse {
        match body {
            "" | "studio" => return serve_studio(&self.studio_app_js_url),
            "list" => return self.serve_list(),
            _ => {}
        }
        let first = body.chars().next().unwrap_or(' ');
        if first == '{' || first.is_ascii_whitespace() {
            self.handle_json_request(body, meta).await
        } else {
            self.handle_colon_request(body, meta).await
        }
    }

    fn serve_list(&self) -> RawResponse {
        let mut entries: Vec<&MethodEntry<Meta>> = self.by_num.values().collect();
        entries.sort_by_key(|e| e.number);

        let methods: Vec<serde_json::Value> = entries
            .iter()
            .map(|e| {
                let mut obj = serde_json::Map::new();
                obj.insert("method".into(), serde_json::Value::String(e.name.clone()));
                obj.insert("number".into(), serde_json::Value::Number(e.number.into()));
                obj.insert(
                    "request".into(),
                    serde_json::from_str(&e.request_type_descriptor_json)
                        .unwrap_or(serde_json::Value::Null),
                );
                obj.insert(
                    "response".into(),
                    serde_json::from_str(&e.response_type_descriptor_json)
                        .unwrap_or(serde_json::Value::Null),
                );
                if !e.doc.is_empty() {
                    obj.insert("doc".into(), serde_json::Value::String(e.doc.clone()));
                }
                serde_json::Value::Object(obj)
            })
            .collect();

        let mut result = serde_json::Map::new();
        result.insert("methods".into(), methods.into());
        RawResponse::ok_json(
            serde_json::to_string_pretty(&serde_json::Value::Object(result))
                .unwrap_or_else(|_| "{}".into()),
        )
    }

    async fn handle_json_request(&self, body: &str, meta: Meta) -> RawResponse {
        let v: serde_json::Value = match serde_json::from_str(body) {
            Ok(v) => v,
            Err(_) => return RawResponse::bad_request("bad request: invalid JSON"),
        };
        let obj = match v.as_object() {
            Some(obj) => obj,
            None => return RawResponse::bad_request("bad request: expected JSON object"),
        };
        let method_val = match obj.get("method") {
            Some(v) => v,
            None => return RawResponse::bad_request("bad request: missing 'method' field in JSON"),
        };
        let entry: &MethodEntry<Meta> = match method_val {
            serde_json::Value::Number(n) => {
                let number = match n.as_i64() {
                    Some(n) => n,
                    None => {
                        return RawResponse::bad_request("bad request: 'method' number is invalid");
                    }
                };
                match self.by_num.get(&number) {
                    Some(e) => e,
                    None => {
                        return RawResponse::bad_request(format!(
                            "bad request: method not found: {number}"
                        ));
                    }
                }
            }
            serde_json::Value::String(name) => match self.by_name.get(name.as_str()) {
                Some(number) => self.by_num.get(number).expect("by_name/by_num out of sync"),
                None => {
                    return RawResponse::bad_request(format!(
                        "bad request: method not found: {name}"
                    ));
                }
            },
            _ => {
                return RawResponse::bad_request(
                    "bad request: 'method' field must be a string or integer",
                );
            }
        };
        let request_val = match obj.get("request") {
            Some(v) => v,
            None => {
                return RawResponse::bad_request("bad request: missing 'request' field in JSON");
            }
        };
        let request_json = request_val.to_string();
        self.invoke_entry(
            entry,
            request_json,
            self.keep_unrecognized_values,
            true, // readable
            meta,
        )
        .await
    }

    async fn handle_colon_request(&self, body: &str, meta: Meta) -> RawResponse {
        // Format: "name:number:format:requestJson"
        // number may be empty (lookup by name); format may be empty (dense).
        let parts: Vec<&str> = body.splitn(4, ':').collect();
        if parts.len() != 4 {
            return RawResponse::bad_request("bad request: invalid request format");
        }
        let (name_str, number_str, format, request_json) = (parts[0], parts[1], parts[2], parts[3]);
        let request_json: String = if request_json.is_empty() {
            "{}".to_owned()
        } else {
            request_json.to_owned()
        };

        let entry: &MethodEntry<Meta> = if number_str.is_empty() {
            match self.by_name.get(name_str) {
                Some(number) => self.by_num.get(number).expect("by_name/by_num out of sync"),
                None => {
                    return RawResponse::bad_request(format!(
                        "bad request: method not found: {name_str}"
                    ));
                }
            }
        } else {
            let number: i64 = match number_str.parse() {
                Ok(n) => n,
                Err(_) => {
                    return RawResponse::bad_request("bad request: can't parse method number");
                }
            };
            match self.by_num.get(&number) {
                Some(e) => e,
                None => {
                    return RawResponse::bad_request(format!(
                        "bad request: method not found: {name_str}; number: {number}"
                    ));
                }
            }
        };

        let readable = format == "readable";
        self.invoke_entry(
            entry,
            request_json,
            self.keep_unrecognized_values,
            readable,
            meta,
        )
        .await
    }

    async fn invoke_entry(
        &self,
        entry: &MethodEntry<Meta>,
        request_json: String,
        keep_unrecognized: bool,
        readable: bool,
        meta: Meta,
    ) -> RawResponse {
        let raw_request = request_json.clone();
        match (entry.invoke)(request_json, keep_unrecognized, readable, meta.clone()).await {
            Ok(response_json) => RawResponse::ok_json(response_json),
            Err(e) => {
                let info = MethodErrorInfo {
                    error: e,
                    method_name: &entry.name,
                    raw_request: &raw_request,
                    request_meta: &meta,
                };
                (self.error_logger)(&info);

                if let Some(svc) = info.error.downcast_ref::<ServiceError>() {
                    let msg = if svc.message.is_empty() {
                        http_status_text(svc.status_code.as_u16()).to_owned()
                    } else {
                        svc.message.clone()
                    };
                    RawResponse::server_error(msg, svc.status_code.as_u16())
                } else {
                    let msg = if (self.can_send_unknown_error_message)(&info) {
                        format!("server error: {}", info.error)
                    } else {
                        "server error".to_owned()
                    };
                    RawResponse::server_error(msg, 500)
                }
            }
        }
    }
}

// =============================================================================
// ServiceBuilder
// =============================================================================

/// Builder for [`Service`].
///
/// Register method implementations with [`add_method`][Self::add_method], tune
/// options with the `set_*` methods, then call [`build`][Self::build].
pub struct ServiceBuilder<Meta> {
    keep_unrecognized_values: bool,
    can_send_unknown_error_message:
        Box<dyn for<'a> Fn(&MethodErrorInfo<'a, Meta>) -> bool + Send + Sync>,
    error_logger: Box<dyn for<'a> Fn(&MethodErrorInfo<'a, Meta>) + Send + Sync>,
    studio_app_js_url: String,
    by_num: HashMap<i64, MethodEntry<Meta>>,
    by_name: HashMap<String, i64>,
}

impl<Meta> Default for ServiceBuilder<Meta>
where
    Meta: Clone + Send + Sync + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}

impl<Meta> ServiceBuilder<Meta>
where
    Meta: Clone + Send + Sync + 'static,
{
    /// Creates a new `ServiceBuilder` with sensible defaults.
    pub fn new() -> Self {
        Self {
            keep_unrecognized_values: false,
            can_send_unknown_error_message: Box::new(|_| false),
            error_logger: Box::new(|info| {
                eprintln!(
                    "skir: error in method {:?}: {}",
                    info.method_name, info.error
                );
            }),
            studio_app_js_url: DEFAULT_STUDIO_APP_JS_URL.to_owned(),
            by_num: HashMap::new(),
            by_name: HashMap::new(),
        }
    }

    /// Registers the implementation of a method.
    ///
    /// The closure receives the deserialized request and the per-request
    /// metadata, and must return an [`anyhow::Result`]. Return a [`ServiceError`]
    /// to send a specific HTTP status code and message to the client; any other
    /// error type results in a 500 response treated as an unknown internal error.
    ///
    /// Returns an error if a method with the same number has already been
    /// registered.
    pub fn add_method<Req, Resp, Fut>(
        mut self,
        method: &Method<Req, Resp>,
        impl_fn: impl Fn(Req, Meta) -> Fut + Send + Sync + 'static,
    ) -> Result<Self, String>
    where
        Req: 'static,
        Resp: 'static,
        Fut: Future<Output = anyhow::Result<Resp>> + Send + 'static,
    {
        if self.by_num.contains_key(&method.number) {
            return Err(format!(
                "skir: method number {} already registered",
                method.number
            ));
        }
        let req_serializer = method.request_serializer.clone();
        let resp_serializer: super::Serializer<Resp> = method.response_serializer.clone();
        let entry = MethodEntry {
            name: method.name.clone(),
            number: method.number,
            doc: method.doc.clone(),
            request_type_descriptor_json: method.request_serializer.type_descriptor().as_json(),
            response_type_descriptor_json: method.response_serializer.type_descriptor().as_json(),
            invoke: Box::new(
                move |request_json: String, keep_unrecognized: bool, readable: bool, meta: Meta| {
                    let policy = if keep_unrecognized {
                        UnrecognizedValues::Keep
                    } else {
                        UnrecognizedValues::Drop
                    };
                    let req = match req_serializer.from_json(&request_json, policy) {
                        Ok(r) => r,
                        Err(e) => {
                            let err = ServiceError {
                                status_code: HttpErrorCode::_400_BadRequest,
                                message: format!("bad request: can't parse JSON: {e}"),
                                source: None,
                            };
                            return Box::pin(async move { Err(anyhow::Error::from(err)) })
                                as Pin<Box<dyn Future<Output = anyhow::Result<String>> + Send>>;
                        }
                    };
                    let fut = impl_fn(req, meta);
                    let resp_serializer = resp_serializer.clone();
                    Box::pin(async move {
                        let resp = fut.await?;
                        let flavor = if readable {
                            JsonFlavor::Readable
                        } else {
                            JsonFlavor::Dense
                        };
                        Ok(resp_serializer.to_json(&resp, flavor))
                    })
                        as Pin<Box<dyn Future<Output = anyhow::Result<String>> + Send>>
                },
            ),
        };
        self.by_name.insert(method.name.clone(), method.number);
        self.by_num.insert(method.number, entry);
        Ok(self)
    }

    /// Whether to keep unrecognized values when deserializing requests.
    ///
    /// Only enable this for data from trusted sources. Malicious actors could
    /// inject fields with IDs not yet defined in your schema.
    ///
    /// Defaults to `false`.
    pub fn set_keep_unrecognized_values(mut self, keep: bool) -> Self {
        self.keep_unrecognized_values = keep;
        self
    }

    /// Whether the message of an unknown (non-[`ServiceError`]) error can be
    /// sent to the client in the response body.
    ///
    /// Defaults to `false` to avoid leaking sensitive information.
    pub fn set_can_send_unknown_error_message(mut self, can: bool) -> Self {
        self.can_send_unknown_error_message = Box::new(move |_| can);
        self
    }

    /// Per-invocation predicate for whether to expose unknown (non-[`ServiceError`]) error messages.
    pub fn set_can_send_unknown_error_message_fn(
        mut self,
        f: impl for<'a> Fn(&MethodErrorInfo<'a, Meta>) -> bool + Send + Sync + 'static,
    ) -> Self {
        self.can_send_unknown_error_message = Box::new(f);
        self
    }

    /// Callback invoked whenever an error occurs during method execution.
    ///
    /// Use this to log errors for monitoring, debugging, or alerting purposes.
    /// Defaults to printing the method name and error message to stderr.
    pub fn set_error_logger(
        mut self,
        logger: impl for<'a> Fn(&MethodErrorInfo<'a, Meta>) + Send + Sync + 'static,
    ) -> Self {
        self.error_logger = Box::new(logger);
        self
    }

    /// URL to the Skir Studio JavaScript bundle.
    ///
    /// Skir Studio is a web UI for exploring and testing your service. It is
    /// served when the request body is `""` or `"studio"`.
    ///
    /// Defaults to the CDN-hosted version.
    pub fn set_studio_app_js_url(mut self, url: impl Into<String>) -> Self {
        self.studio_app_js_url = url.into();
        self
    }

    /// Builds the [`Service`].
    pub fn build(self) -> Service<Meta> {
        Service {
            keep_unrecognized_values: self.keep_unrecognized_values,
            can_send_unknown_error_message: self.can_send_unknown_error_message,
            error_logger: self.error_logger,
            studio_app_js_url: self.studio_app_js_url,
            by_num: self.by_num,
            by_name: self.by_name,
        }
    }
}

// =============================================================================
// Helpers
// =============================================================================

struct MethodEntry<Meta> {
    name: String,
    number: i64,
    doc: String,
    request_type_descriptor_json: String,
    response_type_descriptor_json: String,
    invoke: Box<
        dyn Fn(
                String,
                bool,
                bool,
                Meta,
            ) -> Pin<Box<dyn Future<Output = anyhow::Result<String>> + Send>>
            + Send
            + Sync,
    >,
}

fn serve_studio(js_url: &str) -> RawResponse {
    RawResponse::ok_html(studio_html(js_url))
}

fn studio_html(js_url: &str) -> String {
    let safe = html_escape_attr(js_url);
    // Copied from https://github.com/gepheum/skir-studio/blob/main/index.jsdeliver.html
    format!(
        r#"<!DOCTYPE html><html>
  <head>
    <meta charset="utf-8" />
    <title>RPC Studio</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🐙</text></svg>">
    <script src="{safe}"></script>
  </head>
  <body style="margin: 0; padding: 0;">
    <skir-studio-app></skir-studio-app>
  </body>
</html>"#
    )
}

fn html_escape_attr(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('"', "&#34;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

fn http_status_text(code: u16) -> &'static str {
    match code {
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
    }
}

const DEFAULT_STUDIO_APP_JS_URL: &str =
    "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js";
