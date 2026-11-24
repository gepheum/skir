///|
/// Starts the async RPC service used by the e2e scripts.
async fn main {
  let users = @hashmap.HashMap([])

  let get_user = @client_async.MethodEntry::new(
    @skirout_service.get_user_method,
    (req, _meta) => {
      let user = users.get(req.user_id)
      Ok(@skirout_service.GetUserResponse::new(user~))
    },
  )

  let add_user = @client_async.MethodEntry::new(
    @skirout_service.add_user_method,
    (req, _meta) => {
      if req.user.user_id == 0 {
        Err(
          @client_async.ServiceError::new(
            "user_id must be non-zero",
            status_code=Some(@client_async.HttpErrorCode::Code_400_BadRequest),
          ),
        )
      } else {
        users.set(req.user.user_id, req.user)
        Ok(@skirout_service.AddUserResponse::new())
      }
    },
  )

  let service = match
    @client_async.Service::new(
      [get_user, add_user],
      unrecognized_values=@client.UnrecognizedValues::Keep,
    ) {
    Ok(service) => service
    Err(_) => panic()
  }

  let server = @http.Server(@socket.Addr::parse("0.0.0.0:8787"))
  println("Listening on http://localhost:8787/myapi")
  server.run_forever() <| ((request, body, conn) => {
    let body_text = match request.meth {
      Get => @client_async.get_percent_decoded_query_from_url(request.path)
      _ => body.read_all().text()
    }
    let response = service.handle_request(body_text, ())
    conn.send_response(response.status_code, response.status_text, extra_headers={
      "Content-Type": response.content_type,
    })
    conn.write_string(response.data)
  })
}
