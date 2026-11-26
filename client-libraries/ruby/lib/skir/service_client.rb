# typed: strict
# frozen_string_literal: true

require "net/http"
require "sorbet-runtime"
require "uri"
require_relative "method"

module Skir
  class ServiceClient
    extend T::Sig

    sig { params(url: String).void }
    def initialize(url)
      parsed = URI.parse(url)
      query = parsed.query
      raise ArgumentError, "Service URL must not contain a query string" unless query.nil? || query.empty?

      scheme = parsed.scheme
      raise ArgumentError, "Service URL must start with http:// or https://" unless scheme == "http" || scheme == "https"

      host = parsed.host
      raise ArgumentError, "Service URL must specify a host" if host.nil? || host.empty?

      @uri = T.let(parsed, URI::Generic)
      @host = T.let(host, String)
      @port = T.let(parsed.port || (scheme == "https" ? 443 : 80), Integer)
      @use_ssl = T.let(scheme == "https", T::Boolean)
      path = parsed.path
      @path = T.let(path.nil? || path.empty? ? "/" : path, String)
      freeze
    end

    sig do
      type_parameters(:Req, :Res)
        .params(
          method: Method[T.type_parameter(:Req), T.type_parameter(:Res)],
          request: T.type_parameter(:Req),
          headers: T::Hash[String, String],
          timeout_secs: T.nilable(Numeric)
        )
        .returns(T.type_parameter(:Res))
    end
    def invoke_remote(method, request, headers = {}, timeout_secs: nil)
      request_json = method.request_serializer.to_json_code(request)
      body = "#{method.name}:#{method.number}::#{request_json}"

      http = Net::HTTP.new(@host, @port)
      http.use_ssl = @use_ssl
      if timeout_secs
        http.open_timeout = timeout_secs
        http.read_timeout = timeout_secs
      end

      req = Net::HTTP::Post.new(@path)
      headers.each { |k, v| req[k] = v }
      req["Content-Type"] = "text/plain; charset=utf-8"
      req["Content-Length"] = body.bytesize.to_s
      req.body = body

      response = http.request(req)
      status_code = response.code.to_i
      content_type = response["Content-Type"] || ""
      response_data = (response.body || "").dup.force_encoding(Encoding::UTF_8).scrub("")

      if status_code >= 200 && status_code < 300
        method.response_serializer.from_json_code(response_data)
      else
        message = "HTTP status #{status_code}"
        message = "#{message}: #{response_data}" if content_type.match?(/\Atext\/plain\b/)
        raise RuntimeError, message
      end
    end
  end
end
