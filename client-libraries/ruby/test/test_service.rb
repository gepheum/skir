# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "skir"
require "socket"

class ServiceTest < Minitest::Test
  def setup
    @echo_method = Skir::Method.new(
      name: "Echo",
      number: 1001,
      request_serializer: Skir.primitive_serializer("string"),
      response_serializer: Skir.primitive_serializer("string"),
      doc: "Echoes the request string"
    )
  end

  def test_service_handle_request
    service = Skir::Service.new
    service.add_method(@echo_method) do |req, meta|
      "#{req} (meta=#{meta})"
    end

    # Colon-separated dense request
    res = service.handle_request('Echo:1001::"hello"', "my-meta")
    assert_equal 200, res.status_code
    assert_equal "application/json", res.content_type
    assert_equal '"hello (meta=my-meta)"', res.data

    # JSON object readable request
    res_json = service.handle_request('{"method": "Echo", "request": "world"}', "m2")
    assert_equal 200, res_json.status_code
    assert_equal '"world (meta=m2)"', res_json.data

    # List methods
    res_list = service.handle_request("list", nil)
    assert_equal 200, res_list.status_code
    parsed = JSON.parse(res_list.data)
    assert_equal 1, parsed["methods"].length
    assert_equal "Echo", parsed["methods"][0]["method"]

    # Studio HTML
    res_studio = service.handle_request("studio", nil)
    assert_equal 200, res_studio.status_code
    assert_includes res_studio.data, "<skir-studio-app>"
  end

  def test_service_errors
    service = Skir::Service.new
    logged_errors = []
    service.options.error_logger = ->(info) { logged_errors << info }
    service.add_method(@echo_method) do |req|
      raise Skir::ServiceError.new("403: Forbidden", "Access denied") if req == "forbidden"

      raise "Secret crash"
    end

    res_403 = service.handle_request('Echo:1001::"forbidden"', nil)
    assert_equal 403, res_403.status_code
    assert_equal "Access denied", res_403.data

    res_500 = service.handle_request('Echo:1001::"boom"', nil)
    assert_equal 500, res_500.status_code
    assert_equal "server error", res_500.data
    assert_equal 2, logged_errors.length

    service.options.can_send_unknown_error_message = true
    res_500_open = service.handle_request('Echo:1001::"boom"', nil)
    assert_equal 500, res_500_open.status_code
    assert_equal "server error: Secret crash", res_500_open.data
  end

  def test_service_client_over_http
    service = Skir::Service.new
    service.add_method(@echo_method) do |req, headers|
      "echo: #{req} [auth=#{headers['authorization']}]"
    end

    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]

    thread = Thread.new do
      sock = server.accept
      headers = {}
      content_length = 0
      while (line = sock.gets)
        line = line.chomp
        break if line.empty?

        if line.include?(":")
          k, v = line.split(":", 2)
          headers[k.strip.downcase] = v.strip
          content_length = v.strip.to_i if k.strip.casecmp("content-length").zero?
        end
      end
      body = content_length.positive? ? sock.read(content_length) : ""
      raw_res = service.handle_request(body, headers)
      sock.write("HTTP/1.1 #{raw_res.status_code} OK\r\n")
      sock.write("Content-Type: #{raw_res.content_type}\r\n")
      sock.write("Content-Length: #{raw_res.data.bytesize}\r\n")
      sock.write("Connection: close\r\n\r\n")
      sock.write(raw_res.data)
      sock.close
    end

    begin
      client = Skir::ServiceClient.new("http://127.0.0.1:#{port}/api")
      reply = client.invoke_remote(@echo_method, "ping", { "Authorization" => "Bearer token123" })
      assert_equal "echo: ping [auth=Bearer token123]", reply
    ensure
      server.close
      thread.join
    end
  end
end
