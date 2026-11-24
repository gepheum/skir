#include <gtest/gtest.h>

#include <memory>
#include <string>
#include <thread>
#include <tuple>
#include <utility>
#include <vector>

#include "absl/container/flat_hash_map.h"
#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include "absl/strings/str_cat.h"
#include "httplib.h"
#include "skir.h"
#include "skirout/methods.h"
#include "skirout/methods.testing.h"
#include "gmock/gmock.h"

namespace {
using ::skir::service::Error;
using ::skir::service::ErrorOr;
using ::skir::service::HttpErrorCode;
using ::skir::service::HttpHeaders;
using ::skir::service::InstallServiceOnHttplibServer;
using ::skir::service::InvokeRemote;
using ::skir::service::MakeHttplibClient;
using ::skirout_methods::ListUsers;
using ::skirout_methods::ListUsersRequest;
using ::skirout_methods::ListUsersResponse;
using ::skirout_methods::User;
using ::testing::Contains;
using ::testing::ElementsAre;
using ::testing::IsTrue;
using ::testing::Pair;
using ::testing::skirout::StructIs;

class ServiceImpl {
public:
  using methods = std::tuple<skirout_methods::ListUsers>;

  absl::StatusOr<ListUsersResponse>
  operator()(ListUsers, ListUsersRequest request,
             const skir::service::HttpHeaders &request_headers) const {
    if (request.country.empty()) {
      return absl::UnknownError("no country specified");
    }
    ListUsersResponse response;
    auto it = country_to_users.find(request.country);
    if (it != country_to_users.end()) {
      for (const User &user : it->second) {
        response.users.push_back(user);
      }
    }
    return response;
  }

  void AddUser(User user) {
    country_to_users[user.country].push_back(std::move(user));
  }

private:
  absl::flat_hash_map<std::string, std::vector<User>> country_to_users;
};

class ServiceImplNoMethod {
public:
  using methods = std::tuple<>;
};

TEST(SkirServiceTest, TestServerAndClient) {
  constexpr int kPort = 8787;

  httplib::Server server;

  auto service_impl = std::make_shared<ServiceImpl>();
  InstallServiceOnHttplibServer(server, "/myapi", service_impl);

  service_impl->AddUser({
      .country = "AU",
      .first_name = "Jane",
      .id = 102,
      .last_name = "Doe",
  });

  std::thread server_thread([&server]() { server.listen("localhost", kPort); });

  server.wait_until_ready();

  httplib::Client client("localhost", kPort);
  std::unique_ptr<skir::service::Client> skir_client =
      MakeHttplibClient(&client, "/myapi");

  HttpHeaders request_headers;
  request_headers.Insert("foo", "bar");
  absl::StatusOr<ListUsersResponse> response =
      InvokeRemote(*skir_client, ListUsers(), ListUsersRequest{.country = "AU"},
                   request_headers);

  ASSERT_THAT(response.ok(), IsTrue());
  EXPECT_THAT(*response,
              StructIs<ListUsersResponse>{.users = ElementsAre(StructIs<User>{
                                              .first_name = "Jane",
                                          })});

  EXPECT_THAT(
      InvokeRemote(*skir_client, ListUsers(), ListUsersRequest{},
                   request_headers)
          .status(),
      absl::UnknownError(
          "HTTP response status 500: server error: no country specified"));

  EXPECT_THAT(
      InvokeRemote(*skir_client, skirout_methods::True(), "", {}).status(),
      absl::UnknownError("HTTP response status 400: bad request: method not "
                         "found: True; number: 2192885963"));

  // Send GET requests.

  {
    auto result = client.Get(
        absl::StrCat("/myapi?foo:", ListUsers::kNumber, "%3Areadable:{%7d"));
    EXPECT_TRUE(result);
    EXPECT_EQ(result->status, 500);
    EXPECT_EQ(result->body, "server error: no country specified");
  }

  {
    auto result = client.Get(absl::StrCat("/myapi?foo:", ListUsers::kNumber,
                                          "%3Areadable:[\"AU\"]"));
    EXPECT_TRUE(result);
    EXPECT_EQ(result->status, 200);
    EXPECT_EQ(result->body,
              "{\n  \"users\": [\n    {\n      \"id\": 102,\n      "
              "\"first_name\": \"Jane\",\n      \"last_name\": \"Doe\",\n      "
              "\"country\": \"AU\"\n    }\n  ]\n}");
  }

  {
    auto result = client.Get("/myapi?list");
    EXPECT_TRUE(result);
    EXPECT_EQ(result->status, 200);
    EXPECT_EQ(
        result->body,
        "{\n  \"methods\": [\n    {\n      \"method\": \"ListUsers\",\n      "
        "\"number\": 487705325,\n      \"request\": {\n        \"type\": {\n   "
        "       \"kind\": \"record\",\n          \"value\": "
        "\"methods.skir:ListUsersRequest\"\n        },\n        \"records\": "
        "[\n          {\n            \"kind\": \"struct\",\n            "
        "\"id\": \"methods.skir:ListUsersRequest\",\n            \"fields\": "
        "[\n              {\n                \"name\": \"country\",\n          "
        "      \"number\": 0,\n                \"type\": {\n                  "
        "\"kind\": \"primitive\",\n                  \"value\": \"string\"\n   "
        "             }\n              }\n            ]\n          }\n        "
        "]\n      },\n      \"response\": {\n        \"type\": {\n          "
        "\"kind\": \"record\",\n          \"value\": "
        "\"methods.skir:ListUsersResponse\"\n        },\n        \"records\": "
        "[\n          {\n            \"kind\": \"struct\",\n            "
        "\"id\": \"methods.skir:ListUsersResponse\",\n            \"fields\": "
        "[\n              {\n                \"name\": \"users\",\n            "
        "    \"number\": 0,\n                \"type\": {\n                  "
        "\"kind\": \"array\",\n                  \"value\": {\n                "
        "    \"item\": {\n                      \"kind\": \"record\",\n        "
        "              \"value\": \"methods.skir:User\"\n                    "
        "},\n                    \"key_extractor\": \"id\"\n                  "
        "}\n                }\n              }\n            ]\n          },\n  "
        "        {\n            \"kind\": \"struct\",\n            \"id\": "
        "\"methods.skir:User\",\n            \"fields\": [\n              {\n  "
        "              \"name\": \"id\",\n                \"number\": 0,\n     "
        "           \"type\": {\n                  \"kind\": \"primitive\",\n  "
        "                \"value\": \"hash64\"\n                }\n            "
        "  },\n              {\n                \"name\": \"first_name\",\n    "
        "            \"number\": 1,\n                \"type\": {\n             "
        "     \"kind\": \"primitive\",\n                  \"value\": "
        "\"string\"\n                }\n              },\n              {\n    "
        "            \"name\": \"last_name\",\n                \"number\": "
        "2,\n                \"type\": {\n                  \"kind\": "
        "\"primitive\",\n                  \"value\": \"string\"\n             "
        "   }\n              },\n              {\n                \"name\": "
        "\"country\",\n                \"number\": 3,\n                "
        "\"type\": {\n                  \"kind\": \"primitive\",\n             "
        "     \"value\": \"string\"\n                }\n              }\n      "
        "      ]\n          }\n        ]\n      }\n    }\n  ]\n}");
  }

  server.stop();
  server_thread.join();
}

TEST(SkirServiceTest, NoMethod) {
  constexpr int kPort = 8787;

  httplib::Server server;

  auto service_impl = std::make_shared<ServiceImplNoMethod>();
  InstallServiceOnHttplibServer(server, "/myapi", service_impl);

  std::thread server_thread([&server]() { server.listen("localhost", kPort); });

  server.wait_until_ready();

  httplib::Client client("localhost", kPort);

  auto result = client.Get("/myapi?list");
  EXPECT_TRUE(result);
  EXPECT_EQ(result->status, 200);
  EXPECT_EQ(result->body, "{\n  \"methods\": []\n}");

  server.stop();
  server_thread.join();
}

class ServiceImplWithErrorOr {
public:
  using methods = std::tuple<skirout_methods::ListUsers>;

  ErrorOr<ListUsersResponse>
  operator()(ListUsers, ListUsersRequest request,
             const skir::service::HttpHeaders &request_headers) const {
    if (request.country.empty()) {
      return Error{HttpErrorCode::k400_BadRequest, "country is required"};
    }
    if (request.country == "FORBIDDEN") {
      return Error{HttpErrorCode::k403_Forbidden, "access denied"};
    }
    if (request.country == "NOTFOUND") {
      return Error{HttpErrorCode::k404_NotFound, "country not found"};
    }
    ListUsersResponse response;
    auto it = country_to_users.find(request.country);
    if (it != country_to_users.end()) {
      for (const User &user : it->second) {
        response.users.push_back(user);
      }
    }
    return response;
  }

  void AddUser(User user) {
    country_to_users[user.country].push_back(std::move(user));
  }

private:
  absl::flat_hash_map<std::string, std::vector<User>> country_to_users;
};

TEST(SkirServiceTest, ErrorOrReturnType) {
  constexpr int kPort = 8788;

  httplib::Server server;

  auto service_impl = std::make_shared<ServiceImplWithErrorOr>();
  InstallServiceOnHttplibServer(server, "/myapi", service_impl);

  service_impl->AddUser({
      .country = "US",
      .first_name = "John",
      .id = 103,
      .last_name = "Smith",
  });

  std::thread server_thread([&server]() { server.listen("localhost", kPort); });

  server.wait_until_ready();

  httplib::Client client("localhost", kPort);
  std::unique_ptr<skir::service::Client> skir_client =
      MakeHttplibClient(&client, "/myapi");

  // Test successful response
  {
    absl::StatusOr<ListUsersResponse> response = InvokeRemote(
        *skir_client, ListUsers(), ListUsersRequest{.country = "US"}, {});
    ASSERT_THAT(response.ok(), IsTrue());
    EXPECT_THAT(*response,
                StructIs<ListUsersResponse>{.users = ElementsAre(StructIs<User>{
                                                .first_name = "John",
                                            })});
  }

  // Test 400 Bad Request error
  {
    absl::StatusOr<ListUsersResponse> response =
        InvokeRemote(*skir_client, ListUsers(), ListUsersRequest{}, {});
    EXPECT_THAT(
        response.status(),
        absl::UnknownError("HTTP response status 400: country is required"));
  }

  // Test 403 Forbidden error
  {
    absl::StatusOr<ListUsersResponse> response =
        InvokeRemote(*skir_client, ListUsers(),
                     ListUsersRequest{.country = "FORBIDDEN"}, {});
    EXPECT_THAT(response.status(),
                absl::UnknownError("HTTP response status 403: access denied"));
  }

  // Test 404 Not Found error
  {
    absl::StatusOr<ListUsersResponse> response = InvokeRemote(
        *skir_client, ListUsers(), ListUsersRequest{.country = "NOTFOUND"}, {});
    EXPECT_THAT(
        response.status(),
        absl::UnknownError("HTTP response status 404: country not found"));
  }

  server.stop();
  server_thread.join();
}

} // namespace
