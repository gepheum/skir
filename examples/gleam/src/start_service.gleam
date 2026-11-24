// Run with: gleam run -m start_service

import gleam/bit_array
import gleam/bytes_tree
import gleam/dict
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/option
import gleam/result
import gleam/uri
import mist
import skir_client/service as service_
import skirout/service
import skirout/user

type UserStore =
  dict.Dict(Int, user.User)

type StateMessage {
  KeepState
  UpdateStore(UserStore)
}

type ServerState {
  ServerState(service: RpcService, store: UserStore)
}

type ServerMessage {
  HandleRpc(body: String, reply: process.Subject(service_.RawResponse))
}

type ServerName =
  process.Name(ServerMessage)

type RpcService =
  service_.Service(Nil, UserStore, StateMessage)

pub fn main() {
  let rpc_service = make_service()
  let initial_state = ServerState(service: rpc_service, store: dict.new())
  let server_name = process.new_name("skir_gleam_example_rpc_server")

  let _server_pid =
    process.spawn(fn() { start_server_loop(server_name, initial_state) })

  let assert Ok(_) =
    fn(req: request.Request(mist.Connection)) { handle_http(req, server_name) }
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.with_ipv6
    |> mist.port(8787)
    |> mist.after_start(fn(_port, _scheme, _interface) {
      io.println("Listening on http://localhost:8787/myapi")
    })
    |> mist.start

  process.sleep_forever()
}

fn make_service() -> RpcService {
  service_.new(empty_message: KeepState)
  |> service_.add_method(service.get_user_method(), get_user_handler)
  |> service_.add_method(service.add_user_method(), add_user_handler)
}

fn get_user_handler(
  req: service.GetUserRequest,
  req_meta: Nil,
  store: UserStore,
) -> #(
  Result(service.GetUserResponse, service_.ServiceError),
  Nil,
  StateMessage,
) {
  let found_user = case dict.get(store, req.user_id) {
    Ok(found) -> option.Some(found)
    Error(_) -> option.None
  }

  #(Ok(service.get_user_response_new(user: found_user)), req_meta, KeepState)
}

fn add_user_handler(
  req: service.AddUserRequest,
  req_meta: Nil,
  store: UserStore,
) -> #(
  Result(service.AddUserResponse, service_.ServiceError),
  Nil,
  StateMessage,
) {
  case req.user.user_id == 0 {
    True -> #(
      Error(service_.ServiceError(
        status: service_.E400xBadRequest,
        message: "user_id must be non-zero",
      )),
      req_meta,
      KeepState,
    )
    False -> {
      let updated_store = dict.insert(store, req.user.user_id, req.user)
      #(
        Ok(service.add_user_response_new()),
        req_meta,
        UpdateStore(updated_store),
      )
    }
  }
}

fn handle_server_message(
  state: ServerState,
  message: ServerMessage,
) -> ServerState {
  case message {
    HandleRpc(body, reply) -> {
      let #(raw, state_message) =
        service_.handle_request(state.service, body, Nil, state.store)
      process.send(reply, raw)

      let new_store = case state_message {
        UpdateStore(store) -> store
        KeepState -> state.store
      }

      ServerState(..state, store: new_store)
    }
  }
}

fn start_server_loop(name: ServerName, initial_state: ServerState) -> Nil {
  let assert Ok(_) = process.register(process.self(), name)
  let subject = process.named_subject(name)
  server_loop(subject, initial_state)
}

fn server_loop(
  subject: process.Subject(ServerMessage),
  state: ServerState,
) -> Nil {
  let message = process.receive_forever(subject)
  let new_state = handle_server_message(state, message)
  server_loop(subject, new_state)
}

fn handle_http(
  req: request.Request(mist.Connection),
  server_name: ServerName,
) -> response.Response(mist.ResponseData) {
  case request.path_segments(req) {
    ["myapi"] ->
      case req.method {
        http.Get -> handle_get(req, server_name)
        http.Post -> handle_post(req, server_name)
        _ ->
          text_response(405, "text/plain; charset=utf-8", "method not allowed")
      }
    _ -> text_response(404, "text/plain; charset=utf-8", "not found")
  }
}

fn handle_get(
  req: request.Request(mist.Connection),
  server_name: ServerName,
) -> response.Response(mist.ResponseData) {
  let raw_query = option.unwrap(req.query, "")
  let decoded_query = result.unwrap(uri.percent_decode(raw_query), raw_query)
  let raw =
    process.call_forever(process.named_subject(server_name), HandleRpc(
      decoded_query,
      _,
    ))
  from_raw_response(raw)
}

fn handle_post(
  req: request.Request(mist.Connection),
  server_name: ServerName,
) -> response.Response(mist.ResponseData) {
  case mist.read_body(req, 10 * 1024 * 1024) {
    Error(_) ->
      text_response(
        400,
        "text/plain; charset=utf-8",
        "bad request: failed to read request body",
      )
    Ok(request.Request(body:, ..)) ->
      case bit_array.to_string(body) {
        Error(_) ->
          text_response(
            400,
            "text/plain; charset=utf-8",
            "bad request: body is not valid UTF-8",
          )
        Ok(body_str) ->
          process.call_forever(process.named_subject(server_name), HandleRpc(
            body_str,
            _,
          ))
          |> from_raw_response
      }
  }
}

fn from_raw_response(
  raw: service_.RawResponse,
) -> response.Response(mist.ResponseData) {
  response.new(raw.status_code)
  |> response.set_header("content-type", raw.content_type)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(raw.data)))
}

fn text_response(
  status: Int,
  content_type: String,
  body: String,
) -> response.Response(mist.ResponseData) {
  response.new(status)
  |> response.set_header("content-type", content_type)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}
