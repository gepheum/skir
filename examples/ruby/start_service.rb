# typed: strict
# frozen_string_literal: true

# Starts a SkirRPC service on http://localhost:8787/myapi
#
# Run with:
#   bundle exec ruby start_service.rb
#
# Run call_service.rb to call this service from another process.

require "sorbet-runtime"
require "uri"
require "webrick"
require "skir"
require_relative "skirout/service_skir"
require_relative "skirout/user_skir"

ServiceSkir = Skirout::ServiceSkir
UserSkir = Skirout::UserSkir

class ServiceImpl
  extend T::Sig

  sig { void }
  def initialize
    @id_to_user = T.let({}, T::Hash[Integer, UserSkir::User])
  end

  sig { params(request: ServiceSkir::GetUserRequest, _req_meta: T.untyped).returns(ServiceSkir::GetUserResponse) }
  def get_user(request, _req_meta)
    user = @id_to_user[request.user_id]
    ServiceSkir::GetUserResponse.new(user: user)
  end

  sig { params(request: ServiceSkir::AddUserRequest, _req_meta: T.untyped).returns(ServiceSkir::AddUserResponse) }
  def add_user(request, _req_meta)
    user = request.user
    raise ArgumentError, "invalid user id" if user.user_id.zero?

    puts "Adding user: #{user}"
    @id_to_user[user.user_id] = user
    ServiceSkir::AddUserResponse.new
  end
end

service_impl = ServiceImpl.new

skir_service = Skir::Service.new
skir_service.add_method(ServiceSkir::AddUser) { |req, meta| service_impl.add_user(req, meta) }
skir_service.add_method(ServiceSkir::GetUser) { |req, meta| service_impl.get_user(req, meta) }

server = WEBrick::HTTPServer.new({ Port: 8787 })

server.mount_proc "/" do |_req, res|
  res.status = 200
  res["Content-Type"] = "text/plain; charset=utf-8"
  res.body = "Hello, World!"
end

server.mount_proc "/myapi" do |req, res|
  req_body =
    if req.request_method == "POST"
      req.body || ""
    else
      URI.decode_www_form_component(req.query_string || "")
    end
  raw_response = skir_service.handle_request(req_body, req.header)
  res.status = raw_response.status_code
  res["Content-Type"] = raw_response.content_type
  res.body = raw_response.data
end

trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }

puts "Serving at http://localhost:8787"
puts "API endpoint: http://localhost:8787/myapi"
server.start
