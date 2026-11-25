///|
/// Error returned by the RPC client.
///
/// `status_code=0` represents transport/decoding failures.
pub(all) struct RpcError {
  status_code : Int
  message : String
}

///|
/// Client for invoking methods on a remote Skir service endpoint.
///
/// Construct with `ServiceClient::new` and call `invoke_remote`.
pub struct ServiceClient {
  priv service_url : String
  priv default_headers : @hashmap.HashMap[String, String]
}

///|
/// Creates a service client.
///
/// - `default_headers` is copied so later caller mutations do not affect
///   the client.
///
/// Example from e2e:
/// `let client = @client_async.ServiceClient::new("http://localhost:8787/myapi")`
pub fn ServiceClient::new(
  service_url : String,
  default_headers? : @hashmap.HashMap[String, String] = @hashmap.HashMap([]),
) -> ServiceClient {
  let default_headers = default_headers.copy()
  let service_url = match service_url.find("?") {
    Some(i) => service_url[:i].to_owned()
    None => service_url
  }
  { service_url, default_headers, }
}

///|
/// Invokes a remote method and decodes the typed response.
///
/// `extra_headers` are merged on top of `default_headers` for this call.
///
/// Example from e2e:
/// `client.invoke_remote(@skirout_service_skir.get_user_method, get_req, [])`
pub async fn[Req, Resp] ServiceClient::invoke_remote(
  self : ServiceClient,
  rpc_method : @client.Method[Req, Resp],
  request : Req,
  extra_headers : Array[(String, String)],
) -> Result[Resp, RpcError] {
  let request_json = rpc_method.request_serializer.to_dense_json_code(request)
  let wire_body = rpc_method.name +
    ":" +
    rpc_method.number.to_string() +
    "::" +
    request_json

  let merged_headers : Array[(@http.CaseInsensitiveString, String)] = []
  for key, value in self.default_headers {
    merged_headers.push((@http.CaseInsensitiveString(key), value))
  }
  for _, pair in extra_headers {
    match pair {
      (key, value) =>
        merged_headers.push((@http.CaseInsensitiveString(key), value))
    }
  }
  merged_headers.push(
    (@http.CaseInsensitiveString("Content-Type"), "text/plain; charset=utf-8"),
  )

  let (response, body) = @http.post(
    self.service_url,
    wire_body,
    headers=Map(merged_headers),
  ) catch {
    e => return Err({ status_code: 0, message: e.to_string(), })
  }

  if response.code < 200 || response.code >= 300 {
    return Err({ status_code: response.code, message: body.text(), })
  }

  let response_body = body.text()
  rpc_method.response_serializer.from_json_code(
    response_body,
    unrecognized_values=@client.UnrecognizedValues::Keep,
  )
  |> result => {
    match result {
      Ok(resp) => Ok(resp)
      Err(e) => {
        let rpc_error : RpcError = {
          status_code: 0,
          message: "failed to decode response: " + e,
        }
        Err(rpc_error)
      }
    }
  }
}
