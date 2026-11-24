// Run with: gleam run -m call_service
// Prerequisite: start the server first in another terminal with
// `gleam run -m start_service` (listening on http://localhost:8787/myapi).

import gleam/httpc
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import skir_client
import skir_client/service_client
import skirout/service
import skirout/user

pub fn main() {
  let assert Ok(client) =
    service_client.new("http://localhost:8787/myapi", httpc.send)

  let users_to_add = [
    user.user_new(
      name: "John Doe",
      pets: [],
      quote: "Coffee is just a socially acceptable form of rage.",
      subscription_status: user.SubscriptionStatusFree,
      user_id: 42,
    ),
    user.tarzan_const,
  ]

  users_to_add
  |> list.each(fn(u) {
    let assert Ok(_add_resp) =
      service_client.invoke_remote(
        client,
        service.add_user_method(),
        service.add_user_request_new(user: u),
      )
    io.println(
      "Added user \"" <> u.name <> "\" (id=" <> int.to_string(u.user_id) <> ")",
    )
  })

  let tarzan = user.tarzan_const
  let assert Ok(get_resp) =
    service_client.invoke_remote(
      client,
      service.get_user_method(),
      service.get_user_request_new(user_id: tarzan.user_id),
    )

  case get_resp.user {
    option.Some(found_user) ->
      io.println(
        "Got user: "
        <> skir_client.to_readable_json_code(user.user_serializer(), found_user),
      )
    option.None -> io.println("User not found")
  }
}
