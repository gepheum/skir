# typed: strict
# frozen_string_literal: true

# Sends RPCs to a SkirRPC service.
# See start_service.rb for how to start one.
#
# Run with:
#   bundle exec ruby call_service.rb

require "skir"
require_relative "skirout/service_skir"
require_relative "skirout/user_skir"

ServiceSkir = Skirout::ServiceSkir
UserSkir = Skirout::UserSkir

service_client = Skir::ServiceClient.new("http://localhost:8787/myapi")

puts
puts "About to add 2 users: John Doe and Tarzan"

service_client.invoke_remote(
  ServiceSkir::AddUser,
  ServiceSkir::AddUserRequest.new(
    user: UserSkir::User.partial(user_id: 42, name: "John Doe")
  )
)

service_client.invoke_remote(
  ServiceSkir::AddUser,
  ServiceSkir::AddUserRequest.new(user: UserSkir::TARZAN),
  { "X-Foo" => "hi" }
)

puts "Done"

found_user = service_client.invoke_remote(
  ServiceSkir::GetUser,
  ServiceSkir::GetUserRequest.new(user_id: 123)
)

puts "Found user: #{found_user}"
