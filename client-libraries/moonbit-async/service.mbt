///|
/// Immutable RPC service runtime.
///
/// Create with `Service::new`, then call `handle_request` for each incoming
/// request payload.
pub struct Service[Meta] {
  priv unrecognized_values : @client.UnrecognizedValues
  priv can_send_unknown_error_message : (MethodErrorInfo[Meta]) -> Bool
  priv error_logger : (MethodErrorInfo[Meta]) -> Unit
  priv studio_app_js_url : String
  priv by_num : @hashmap.HashMap[Int32, MethodEntry[Meta]]
  priv by_name : @hashmap.HashMap[String, Int32]
}

///|
/// Handles a single incoming request body and returns a raw response.
///
/// The `body` parameter must match the HTTP method exactly:
/// - for POST requests, pass the raw HTTP request body text;
/// - for GET requests, pass the percent-decoded query fragment.
///
/// For GET requests, obtain this value with
/// `get_percent_decoded_query_from_url(request.path)`.
///
/// Example from e2e (`start_service.mbt`):
/// `let body_text = match request.meth {`
/// `  Get => @client_async.get_percent_decoded_query_from_url(request.path)`
/// `  _ => body.read_all().text()`
/// `}`
/// `let response = service.handle_request(body_text, ())`
/// `conn.send_response(response.status_code, response.status_text, extra_headers={`
/// `  "Content-Type": response.content_type,`
/// `})`
/// `conn.write_string(response.data)`
pub async fn[Meta] Service::handle_request(
  self : Service[Meta],
  body : String,
  meta : Meta,
) -> RawResponse {
  match body {
    "" | "studio" => return serve_studio(self.studio_app_js_url)
    "list" => return self.serve_list()
    _ => ()
  }

  if body.has_prefix("{") ||
    body.has_prefix(" ") ||
    body.has_prefix("\n") ||
    body.has_prefix("\t") {
    self.handle_json_request(body, meta)
  } else {
    self.handle_colon_request(body, meta)
  }
}

///|
/// Raw HTTP-like response returned by the service runtime.
///
/// This is primarily produced by `Service::handle_request`.
pub(all) struct RawResponse {
  data : String
  status_code : Int32
  status_text : String
  content_type : String
}

///|
/// HTTP status codes used by service-side errors.
///
/// The constructors mirror common 4xx/5xx responses and can be converted
/// to integers via `HttpErrorCode::as_int`.
#derive(Eq, Hash, Debug)
pub(all) enum HttpErrorCode {
  Code_400_BadRequest
  Code_401_Unauthorized
  Code_402_PaymentRequired
  Code_403_Forbidden
  Code_404_NotFound
  Code_405_MethodNotAllowed
  Code_406_NotAcceptable
  Code_407_ProxyAuthenticationRequired
  Code_408_RequestTimeout
  Code_409_Conflict
  Code_410_Gone
  Code_411_LengthRequired
  Code_412_PreconditionFailed
  Code_413_ContentTooLarge
  Code_414_UriTooLong
  Code_415_UnsupportedMediaType
  Code_416_RangeNotSatisfiable
  Code_417_ExpectationFailed
  Code_418_ImATeapot
  Code_421_MisdirectedRequest
  Code_422_UnprocessableContent
  Code_423_Locked
  Code_424_FailedDependency
  Code_425_TooEarly
  Code_426_UpgradeRequired
  Code_428_PreconditionRequired
  Code_429_TooManyRequests
  Code_431_RequestHeaderFieldsTooLarge
  Code_451_UnavailableForLegalReasons
  Code_500_InternalServerError
  Code_501_NotImplemented
  Code_502_BadGateway
  Code_503_ServiceUnavailable
  Code_504_GatewayTimeout
  Code_505_HttpVersionNotSupported
  Code_506_VariantAlsoNegotiates
  Code_507_InsufficientStorage
  Code_508_LoopDetected
  Code_510_NotExtended
  Code_511_NetworkAuthenticationRequired
}

///|
/// Converts a status enum value to its integer HTTP code.
pub fn HttpErrorCode::as_int(self : HttpErrorCode) -> Int32 {
  match self {
    Code_400_BadRequest => 400
    Code_401_Unauthorized => 401
    Code_402_PaymentRequired => 402
    Code_403_Forbidden => 403
    Code_404_NotFound => 404
    Code_405_MethodNotAllowed => 405
    Code_406_NotAcceptable => 406
    Code_407_ProxyAuthenticationRequired => 407
    Code_408_RequestTimeout => 408
    Code_409_Conflict => 409
    Code_410_Gone => 410
    Code_411_LengthRequired => 411
    Code_412_PreconditionFailed => 412
    Code_413_ContentTooLarge => 413
    Code_414_UriTooLong => 414
    Code_415_UnsupportedMediaType => 415
    Code_416_RangeNotSatisfiable => 416
    Code_417_ExpectationFailed => 417
    Code_418_ImATeapot => 418
    Code_421_MisdirectedRequest => 421
    Code_422_UnprocessableContent => 422
    Code_423_Locked => 423
    Code_424_FailedDependency => 424
    Code_425_TooEarly => 425
    Code_426_UpgradeRequired => 426
    Code_428_PreconditionRequired => 428
    Code_429_TooManyRequests => 429
    Code_431_RequestHeaderFieldsTooLarge => 431
    Code_451_UnavailableForLegalReasons => 451
    Code_500_InternalServerError => 500
    Code_501_NotImplemented => 501
    Code_502_BadGateway => 502
    Code_503_ServiceUnavailable => 503
    Code_504_GatewayTimeout => 504
    Code_505_HttpVersionNotSupported => 505
    Code_506_VariantAlsoNegotiates => 506
    Code_507_InsufficientStorage => 507
    Code_508_LoopDetected => 508
    Code_510_NotExtended => 510
    Code_511_NetworkAuthenticationRequired => 511
  }
}

///|
/// Error returned by method implementations.
///
/// - `message` is logged and may be returned to clients depending on policy.
/// - `status_code` when present drives the HTTP response code.
pub(all) struct ServiceError {
  message : String
  status_code : HttpErrorCode?
}

///|
/// Builds a `ServiceError`.
///
/// Example:
/// `ServiceError::new("user_id must be non-zero", status_code=Some(HttpErrorCode::Code_400_BadRequest))`
pub fn ServiceError::new(
  message : String,
  status_code~ : HttpErrorCode? = None,
) -> ServiceError {
  { status_code, message, }
}

///|
/// Context passed to error hooks configured in `Service::new`.
pub(all) struct MethodErrorInfo[Meta] {
  error_message : String
  method_name : String
  status_code : HttpErrorCode?
  request_meta : Meta
}

///|
/// Precompiled method entry consumed by `Service::new`.
///
/// Entries are created through `MethodEntry::new`.
pub struct MethodEntry[Meta] {
  priv name : String
  priv number : Int32
  priv doc : String
  priv request_type_descriptor_json : Json
  priv response_type_descriptor_json : Json
  priv invoke : async (String, @client.UnrecognizedValues, Bool, Meta) -> Result[
    String,
    ServiceError,
  ]
}

///|
/// Creates a method entry from generated method metadata and an implementation.
///
/// Example from e2e:
/// `let get_user = @client_async.MethodEntry::new(@skirout_service_skir.get_user_method, (req, _meta) => { ... })`
pub fn[Req, Resp, Meta] MethodEntry::new(
  rpc_method : @client.Method[Req, Resp],
  impl_fn : async (Req, Meta) -> Result[Resp, ServiceError],
) -> MethodEntry[Meta] {
  let req_serializer = rpc_method.request_serializer
  let resp_serializer = rpc_method.response_serializer
  {
    name: rpc_method.name,
    number: rpc_method.number,
    doc: rpc_method.doc,
    request_type_descriptor_json: req_serializer.type_descriptor().as_json(),
    response_type_descriptor_json: resp_serializer.type_descriptor().as_json(),
    invoke: (request_json, unrecognized_values, readable, meta) => {
      let req = match
        req_serializer.from_json_code(request_json, unrecognized_values~) {
        Ok(v) => v
        Err(e) =>
          return Err(
            ServiceError::new(
              "bad request: can't parse JSON: " + e,
              status_code=Some(HttpErrorCode::Code_400_BadRequest),
            ),
          )
      }

      match impl_fn(req, meta) {
        Ok(resp) => {
          let response_json = if readable {
            resp_serializer.to_readable_json(resp).stringify()
          } else {
            resp_serializer.to_dense_json_code(resp)
          }
          Ok(response_json)
        }
        Err(service_err) => Err(service_err)
      }
    },
  }
}

///|
/// Builds a `Service` from method entries and runtime hooks.
///
/// Parameters:
/// - `methods`: registered RPC methods (required).
/// - `unrecognized_values`: controls whether unknown fields are preserved or
///   dropped during request decoding (default: `Drop`).
/// - `can_send_unknown_error_message`: decides whether unknown/internal error
///   details can be sent back to clients (default: `_ => false`).
/// - `error_logger`: receives method error context for logging/observability
///   (default: prints `method_name` + `error_message`).
/// - `studio_app_js_url`: JS bundle URL used by the built-in `"studio"`
///   endpoint (default: Skir CDN standalone URL).
///
/// Example from e2e:
/// `@client_async.Service::new(`
/// `  [get_user, add_user],`
/// `  unrecognized_values=@client.UnrecognizedValues::Keep,`
/// `)`
pub fn[Meta] Service::new(
  methods : Array[MethodEntry[Meta]],
  unrecognized_values~ : @client.UnrecognizedValues = @client.UnrecognizedValues::Drop,
  can_send_unknown_error_message~ : (MethodErrorInfo[Meta]) -> Bool = _ => false,
  error_logger~ : (MethodErrorInfo[Meta]) -> Unit = info => {
    println(
      "skir: error in method \"" +
      info.method_name +
      "\": " +
      info.error_message,
    )
  },
  studio_app_js_url~ : String = "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js",
) -> Result[Service[Meta], String] {
  let by_num = @hashmap.HashMap([], capacity=methods.length())
  let by_name = @hashmap.HashMap([], capacity=methods.length())
  for _, entry in methods {
    if by_num.contains(entry.number) {
      return Err(
        "skir: method number " +
        entry.number.to_string() +
        " already registered",
      )
    }
    by_name.set(entry.name, entry.number)
    by_num.set(entry.number, entry)
  }

  Ok({
    unrecognized_values,
    can_send_unknown_error_message,
    error_logger,
    studio_app_js_url,
    by_num,
    by_name,
  })
}

///|
fn[Meta] Service::serve_list(self : Service[Meta]) -> RawResponse {
  let methods : Array[Json] = []
  for _, entry in self.by_num {
    let fields : Array[(String, Json)] = [
      ("method", ToJson::to_json(entry.name)),
      ("number", ToJson::to_json(entry.number)),
      ("request", entry.request_type_descriptor_json),
      ("response", entry.response_type_descriptor_json),
    ]
    if entry.doc != "" {
      fields.push(("doc", ToJson::to_json(entry.doc)))
    }
    methods.push(Json::object(Map(fields)))
  }
  raw_ok_json(
    Json::object(Map([("methods", ToJson::to_json(methods))])).stringify(
      indent=2,
    ),
  )
}

///|
async fn[Meta] Service::handle_json_request(
  self : Service[Meta],
  body : String,
  meta : Meta,
) -> RawResponse {
  let root = @json.parse(body) catch {
    _ => return raw_bad_request("bad request: invalid JSON")
  }

  let obj = match root {
    Json::Object(v) => v
    _ => return raw_bad_request("bad request: expected JSON object")
  }

  let entry = match obj.get("method") {
    Some(Json::Number(n, ..)) => {
      let number = n.to_int()
      match self.by_num.get(number) {
        Some(e) => e
        None =>
          return raw_bad_request(
            "bad request: method not found: " + number.to_string(),
          )
      }
    }
    Some(Json::String(name)) =>
      match self.by_name.get(name) {
        Some(number) =>
          match self.by_num.get(number) {
            Some(e) => e
            None =>
              return raw_bad_request("bad request: method index out of sync")
          }
        None => return raw_bad_request("bad request: method not found: " + name)
      }
    Some(_) =>
      return raw_bad_request(
        "bad request: 'method' field must be a string or integer",
      )
    None =>
      return raw_bad_request("bad request: missing 'method' field in JSON")
  }

  let request_val = match obj.get("request") {
    Some(v) => v
    None =>
      return raw_bad_request("bad request: missing 'request' field in JSON")
  }

  self.invoke_entry(
    entry,
    request_val.stringify(),
    self.unrecognized_values,
    true,
    meta,
  )
}

///|
async fn[Meta] Service::handle_colon_request(
  self : Service[Meta],
  body : String,
  meta : Meta,
) -> RawResponse {
  let chunks = body.split(":").collect()
  if chunks.length() < 4 {
    return raw_bad_request("bad request: invalid request format")
  }

  let name_str = chunks[0].to_owned()
  let number_str = chunks[1].to_owned()
  let format = chunks[2].to_owned()

  let request_builder = StringBuilder()
  for i in 3..<chunks.length() {
    if i > 3 {
      request_builder.write_char(':')
    }
    request_builder.write_string(chunks[i].to_owned())
  }
  let request_json = if request_builder.is_empty() {
    "{}"
  } else {
    request_builder.to_string()
  }

  let entry = if number_str == "" {
    match self.by_name.get(name_str) {
      Some(number) =>
        match self.by_num.get(number) {
          Some(e) => e
          None =>
            return raw_bad_request("bad request: method index out of sync")
        }
      None =>
        return raw_bad_request("bad request: method not found: " + name_str)
    }
  } else {
    let number = @string.parse_int(number_str) catch {
      _ => return raw_bad_request("bad request: can't parse method number")
    }
    match self.by_num.get(number) {
      Some(e) => e
      None =>
        return raw_bad_request(
          "bad request: method not found: " +
          name_str +
          "; number: " +
          number.to_string(),
        )
    }
  }

  self.invoke_entry(
    entry,
    request_json,
    self.unrecognized_values,
    format == "readable",
    meta,
  )
}

///|
async fn[Meta] Service::invoke_entry(
  self : Service[Meta],
  entry : MethodEntry[Meta],
  request_json : String,
  unrecognized_values : @client.UnrecognizedValues,
  readable : Bool,
  meta : Meta,
) -> RawResponse {
  match (entry.invoke)(request_json, unrecognized_values, readable, meta) {
    Ok(response_json) => raw_ok_json(response_json)
    Err(service_error) =>
      match service_error.status_code {
        Some(status_code) => {
          let msg = if service_error.message == "" {
            http_status_text(status_code)
          } else {
            service_error.message
          }
          let info : MethodErrorInfo[Meta] = {
            error_message: msg,
            method_name: entry.name,
            status_code: Some(status_code),
            request_meta: meta,
          }
          (self.error_logger)(info)
          raw_server_error(msg, status_code)
        }
        None => {
          let info : MethodErrorInfo[Meta] = {
            error_message: service_error.message,
            method_name: entry.name,
            status_code: None,
            request_meta: meta,
          }
          let can_send = (self.can_send_unknown_error_message)(info)
          (self.error_logger)(info)
          let msg = if can_send {
            if service_error.message == "" {
              "server error"
            } else {
              "server error: " + service_error.message
            }
          } else {
            "server error"
          }
          raw_server_error(msg, HttpErrorCode::Code_500_InternalServerError)
        }
      }
  }
}

///|
fn raw_ok_json(data : String) -> RawResponse {
  {
    data,
    status_code: 200,
    status_text: "OK",
    content_type: "application/json",
  }
}

///|
fn raw_ok_html(data : String) -> RawResponse {
  {
    data,
    status_code: 200,
    status_text: "OK",
    content_type: "text/html; charset=utf-8",
  }
}

///|
fn raw_bad_request(msg : String) -> RawResponse {
  {
    data: msg,
    status_code: 400,
    status_text: "Bad Request",
    content_type: "text/plain; charset=utf-8",
  }
}

///|
fn raw_server_error(msg : String, status_code : HttpErrorCode) -> RawResponse {
  {
    data: msg,
    status_code: status_code.as_int(),
    status_text: http_status_text(status_code),
    content_type: "text/plain; charset=utf-8",
  }
}

///|
fn serve_studio(js_url : String) -> RawResponse {
  raw_ok_html(studio_html(js_url))
}

///|
fn studio_html(js_url : String) -> String {
  let safe = html_escape_attr(js_url)
  "<!DOCTYPE html><html><head><meta charset=\"utf-8\" />" +
  "<title>RPC Studio</title>" +
  "<script src=\"" +
  safe +
  "\"></script></head><body style=\"margin: 0; padding: 0;\">" +
  "<skir-studio-app></skir-studio-app></body></html>"
}

///|
fn html_escape_attr(s : String) -> String {
  s
  .replace_all(old="&", new="&amp;")
  .replace_all(old="\"", new="&#34;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
}

///|
/// Extracts the query section from a URL path and percent-decodes it.
///
/// Returns `""` if the URL has no `?query` section.
///
/// Example from e2e:
/// `Get => @client_async.get_percent_decoded_query_from_url(request.path)`
pub fn get_percent_decoded_query_from_url(path : String) -> String {
  let i = match path.find("?") {
    Some(v) => v
    None => return ""
  }
  let raw = path[i + 1:]
  percent_decode(raw)
}

///|
fn percent_decode(input : StringView) -> String {
  let bytes = @utf8.encode(input.to_owned())
  let out : Array[Byte] = []
  let mut i = 0
  while i < bytes.length() {
    let c = bytes[i]
    if c == b'+' {
      out.push(b' ')
      i = i + 1
    } else if c == b'%' && i + 2 < bytes.length() {
      match (hex_value(bytes[i + 1]), hex_value(bytes[i + 2])) {
        (Some(hi), Some(lo)) => {
          out.push((hi * 16 + lo).to_byte())
          i = i + 3
        }
        _ => {
          out.push(c)
          i = i + 1
        }
      }
    } else {
      out.push(c)
      i = i + 1
    }
  }
  @utf8.decode(Bytes::from_array(out)[:]) catch {
    _ => input.to_owned()
  }
}

///|
fn hex_value(b : Byte) -> Int32? {
  if b >= b'0' && b <= b'9' {
    Some((b - b'0').to_int())
  } else if b >= b'a' && b <= b'f' {
    Some(10 + (b - b'a').to_int())
  } else if b >= b'A' && b <= b'F' {
    Some(10 + (b - b'A').to_int())
  } else {
    None
  }
}

///|
fn http_status_text(code : HttpErrorCode) -> String {
  match code {
    Code_400_BadRequest => "Bad Request"
    Code_401_Unauthorized => "Unauthorized"
    Code_402_PaymentRequired => "Payment Required"
    Code_403_Forbidden => "Forbidden"
    Code_404_NotFound => "Not Found"
    Code_405_MethodNotAllowed => "Method Not Allowed"
    Code_406_NotAcceptable => "Not Acceptable"
    Code_407_ProxyAuthenticationRequired => "Proxy Authentication Required"
    Code_408_RequestTimeout => "Request Timeout"
    Code_409_Conflict => "Conflict"
    Code_410_Gone => "Gone"
    Code_411_LengthRequired => "Length Required"
    Code_412_PreconditionFailed => "Precondition Failed"
    Code_413_ContentTooLarge => "Content Too Large"
    Code_414_UriTooLong => "URI Too Long"
    Code_415_UnsupportedMediaType => "Unsupported Media Type"
    Code_416_RangeNotSatisfiable => "Range Not Satisfiable"
    Code_417_ExpectationFailed => "Expectation Failed"
    Code_418_ImATeapot => "I'm a Teapot"
    Code_421_MisdirectedRequest => "Misdirected Request"
    Code_422_UnprocessableContent => "Unprocessable Content"
    Code_423_Locked => "Locked"
    Code_424_FailedDependency => "Failed Dependency"
    Code_425_TooEarly => "Too Early"
    Code_426_UpgradeRequired => "Upgrade Required"
    Code_428_PreconditionRequired => "Precondition Required"
    Code_429_TooManyRequests => "Too Many Requests"
    Code_431_RequestHeaderFieldsTooLarge => "Request Header Fields Too Large"
    Code_451_UnavailableForLegalReasons => "Unavailable For Legal Reasons"
    Code_500_InternalServerError => "Internal Server Error"
    Code_501_NotImplemented => "Not Implemented"
    Code_502_BadGateway => "Bad Gateway"
    Code_503_ServiceUnavailable => "Service Unavailable"
    Code_504_GatewayTimeout => "Gateway Timeout"
    Code_505_HttpVersionNotSupported => "HTTP Version Not Supported"
    Code_506_VariantAlsoNegotiates => "Variant Also Negotiates"
    Code_507_InsufficientStorage => "Insufficient Storage"
    Code_508_LoopDetected => "Loop Detected"
    Code_510_NotExtended => "Not Extended"
    Code_511_NetworkAuthenticationRequired => "Network Authentication Required"
  }
}
