// Starts a SkirRPC service on http://localhost:8787/?myapi
//
// Run with:
//   ./build/service_start
//
// Send RPCs to the service with:
//   ./build/service_client

#include <cstdint>
#include <iostream>
#include <memory>
#include <utility>

#include "absl/container/flat_hash_map.h"
#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include "httplib.h"
#include "skir.h"
#include "skirout/service.h"
#include "skirout/user.h"

class ServiceImpl {
 public:
  using methods =
      std::tuple<skirout_service::GetUser, skirout_service::AddUser>;

  absl::StatusOr<skirout_service::GetUserResponse> operator()(
      skirout_service::GetUser, skirout_service::GetUserRequest request,
      const skir::service::HttpHeaders& request_headers) {
    const int64_t user_id = request.user_id;
    if (user_id == 0) {
      return absl::UnknownError("invalid user id: 0");
    }
    skirout_service::GetUserResponse response;
    const auto it = id_to_user_.find(request.user_id);
    if (it != id_to_user_.cend()) {
      response.user = it->second;
    }
    return response;
  }

  absl::StatusOr<skirout_service::AddUserResponse> operator()(
      skirout_service::AddUser, skirout_service::AddUserRequest request,
      const skir::service::HttpHeaders& request_headers) {
    skirout_user::User& user = request.user;
    const int64_t user_id = user.user_id;
    id_to_user_[user_id] = std::move(user);
    return skirout_service::AddUserResponse{};
  }

 private:
  absl::flat_hash_map<int64_t, skirout_user::User> id_to_user_;
};

int main() {
  constexpr int kPort = 8787;

  httplib::Server server;

  auto service_impl = std::make_shared<ServiceImpl>();
  skir::service::InstallServiceOnHttplibServer(server, "/myapi", service_impl);

  server.Get("/stop", [&](const httplib::Request& req, httplib::Response& res) {
    server.stop();
  });

  std::cout << "Starting server on http://localhost:" << kPort
            << "\nGo to http://localhost:" << kPort
            << "/myapi?list to see all methods\n";

  server.listen("localhost", kPort);
}
