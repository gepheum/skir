// Sends RPCs to a SkirRPC service.
//
// Run with:
//   ./build/service_client
//
// Assumes you are already running in another process:
//   ./build/service_start

#include <iostream>
#include <memory>

#include "absl/status/statusor.h"
#include "absl/types/optional.h"
#include "httplib.h"
#include "skir.h"
#include "skirout/service.h"
#include "skirout/user.h"

int main() {
  constexpr int kPort = 8787;

  std::unique_ptr<skir::service::Client> client =
      skir::service::MakeHttplibClient(
          std::make_unique<httplib::Client>("localhost", kPort), "/myapi");

  const std::vector<skirout_user::User> users = {
      {.name = "Jane", .user_id = 41},
      {.name = "John", .user_id = 42},
      {.name = "Dora", .user_id = 43},
  };

  for (const skirout_user::User& user : users) {
    // Add user to the server.
    skirout_service::AddUserRequest add_user_request;
    add_user_request.user = user;

    std::cout << "About to add user " << user.name << "\n";
    absl::StatusOr<skirout_service::AddUserResponse> add_user_response =
        InvokeRemote(*client, skirout_service::AddUser(), add_user_request);
    std::cout << "  status: " << add_user_response.status() << "\n";
  }

  skirout_service::GetUserRequest get_user_request;
  get_user_request.user_id = 43;

  std::cout << "About to get user with id " << get_user_request.user_id << "\n";
  absl::StatusOr<skirout_service::GetUserResponse> get_user_response =
      InvokeRemote(*client, skirout_service::GetUser(), get_user_request);
  std::cout << "  status: " << get_user_response.status() << "\n";
  if (get_user_response.ok()) {
    const absl::optional<skirout_user::User>& user = get_user_response->user;
    if (user.has_value()) {
      std::cout << "Found user: " << *user << "\n";
    } else {
      std::cout << "Not found\n";
    }
  }
}
