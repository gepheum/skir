# typed: strict
# frozen_string_literal: true

require "cgi"
require "json"
require "logger"
require "sorbet-runtime"
require_relative "method"

module Skir
  class RawServiceResponse
    extend T::Sig

    sig { returns(String) }
    attr_reader :data

    sig { returns(Integer) }
    attr_reader :status_code

    sig { returns(String) }
    attr_reader :content_type

    sig { params(data: String, status_code: Integer, content_type: String).void }
    def initialize(data:, status_code:, content_type:)
      @data = T.let(data.dup.freeze, String)
      @status_code = T.let(status_code, Integer)
      @content_type = T.let(content_type.dup.freeze, String)
      freeze
    end

    sig { params(other: BasicObject).returns(T::Boolean) }
    def ==(other)
      case other
      when RawServiceResponse
        @data == other.data && @status_code == other.status_code && @content_type == other.content_type
      else
        false
      end
    end

    alias eql? ==

    sig { returns(Integer) }
    def hash
      [RawServiceResponse, @data, @status_code, @content_type].hash
    end
  end

  class ServiceError < StandardError
    extend T::Sig

    sig { returns(Integer) }
    attr_reader :status_code

    sig { returns(String) }
    attr_reader :error_message

    sig { params(status_code: String, message: T.nilable(String)).void }
    def initialize(status_code, message = nil)
      parts = status_code.split(": ", 2)
      raise ArgumentError, "Invalid status code format: #{status_code}" if parts.length != 2

      @status_code = T.let(Integer(T.must(parts[0])), Integer)
      @error_message = T.let((message || T.must(parts[1])).dup.freeze, String)
      super(@error_message)
    end

    sig { returns(RawServiceResponse) }
    def to_raw_response
      RawServiceResponse.new(
        data: @error_message,
        status_code: @status_code,
        content_type: "text/plain; charset=utf-8"
      )
    end
  end

  class MethodErrorInfo
    extend T::Sig
    extend T::Generic

    RequestMeta = type_member

    sig { returns(StandardError) }
    attr_reader :error

    sig { returns(Method[T.untyped, T.untyped]) }
    attr_reader :method

    sig { returns(T.untyped) }
    attr_reader :request

    sig { returns(RequestMeta) }
    attr_reader :request_meta

    sig do
      params(
        error: StandardError,
        method: Method[T.untyped, T.untyped],
        request: T.untyped,
        request_meta: RequestMeta
      ).void
    end
    def initialize(error:, method:, request:, request_meta:)
      @error = T.let(error, StandardError)
      @method = T.let(method, Method[T.untyped, T.untyped])
      @request = request
      @request_meta = T.let(request_meta, RequestMeta)
      freeze
    end
  end

  class ServiceOptions
    extend T::Sig
    extend T::Generic

    RequestMeta = type_member

    sig { returns(T::Boolean) }
    attr_accessor :keep_unrecognized_values

    sig { returns(T.any(T::Boolean, T.proc.params(arg0: MethodErrorInfo[RequestMeta]).returns(T::Boolean))) }
    attr_accessor :can_send_unknown_error_message

    sig { returns(T.proc.params(arg0: MethodErrorInfo[RequestMeta]).void) }
    attr_accessor :error_logger

    sig { returns(String) }
    attr_accessor :studio_app_js_url

    sig { void }
    def initialize
      @keep_unrecognized_values = T.let(false, T::Boolean)
      @can_send_unknown_error_message = T.let(
        false,
        T.any(T::Boolean, T.proc.params(arg0: MethodErrorInfo[RequestMeta]).returns(T::Boolean))
      )
      logger = Logger.new($stderr)
      @error_logger = T.let(
        lambda do |error_context|
          logger.error("Error in method #{error_context.method.name}: #{error_context.error}")
        end,
        T.proc.params(arg0: MethodErrorInfo[RequestMeta]).void
      )
      @studio_app_js_url = T.let(
        "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js",
        String
      )
    end

    sig { params(error_info: MethodErrorInfo[RequestMeta]).returns(T::Boolean) }
    def resolve_can_send_unknown_error_message(error_info)
      pred = @can_send_unknown_error_message
      case pred
      when true, false
        pred
      else
        pred.call(error_info)
      end
    end
  end

  class Service
    extend T::Sig
    extend T::Generic

    RequestMeta = type_member { { upper: T.anything } }

    sig { returns(ServiceOptions[RequestMeta]) }
    attr_reader :options

    class MethodEntry
      extend T::Sig

      sig { returns(Method[T.untyped, T.untyped]) }
      attr_reader :method

      sig { returns(T.proc.params(arg0: T.untyped, arg1: T.untyped).returns(T.untyped)) }
      attr_reader :impl

      sig do
        params(
          method: Method[T.untyped, T.untyped],
          impl: T.proc.params(arg0: T.untyped, arg1: T.untyped).returns(T.untyped)
        ).void
      end
      def initialize(method:, impl:)
        @method = T.let(method, Method[T.untyped, T.untyped])
        @impl = T.let(impl, T.proc.params(arg0: T.untyped, arg1: T.untyped).returns(T.untyped))
        freeze
      end
    end

    sig { void }
    def initialize
      @options = T.let(ServiceOptions[RequestMeta].new, ServiceOptions[RequestMeta])
      @number_to_method_impl = T.let({}, T::Hash[Integer, MethodEntry])
    end

    sig do
      type_parameters(:Req, :Res)
        .params(
          method: Method[T.type_parameter(:Req), T.type_parameter(:Res)],
          impl: T.nilable(T.proc.params(arg0: T.untyped, arg1: T.untyped).returns(T.type_parameter(:Res))),
          blk: T.nilable(T.proc.params(arg0: T.untyped, arg1: T.untyped).returns(T.type_parameter(:Res)))
        )
        .returns(Service[RequestMeta])
    end
    def add_method(method, impl = nil, &blk)
      callable = impl || blk
      raise ArgumentError, "Method implementation proc or block is required" if callable.nil?

      arity = callable.arity
      if arity != 1 && arity != 2 && arity != -2
        raise ArgumentError, "Method implementation must accept 1 or 2 positional parameters (got arity #{arity})"
      end

      number = method.number
      if @number_to_method_impl.key?(number)
        raise ArgumentError, "Method with the same number already registered (#{number})"
      end

      resolved_impl = lambda do |req, req_meta|
        if arity == 1
          T.unsafe(callable).call(req)
        else
          T.unsafe(callable).call(req, req_meta)
        end
      end

      @number_to_method_impl[number] = MethodEntry.new(method: method, impl: resolved_impl)
      self
    end

    sig { params(req_body: String, req_meta: RequestMeta).returns(RawServiceResponse) }
    def handle_request(req_body, req_meta = T.unsafe(nil))
      if req_body == "list"
        return handle_list
      elsif req_body == "" || req_body == "studio"
        return handle_studio
      end

      parsed = parse_request(req_body)
      return parsed if parsed.is_a?(RawServiceResponse)

      req, entry, format = parsed
      begin
        res = entry.impl.call(req, req_meta)
      rescue StandardError => e
        error_info = MethodErrorInfo[RequestMeta].new(
          error: e,
          method: entry.method,
          request: req,
          request_meta: req_meta
        )
        @options.error_logger.call(error_info)
        if e.is_a?(ServiceError)
          return e.to_raw_response
        else
          msg =
            if @options.resolve_can_send_unknown_error_message(error_info)
              "server error: #{e.message}"
            else
              "server error"
            end
          return make_server_error_response(msg)
        end
      end

      begin
        res_json = entry.method.response_serializer.to_json_code(res, readable: format == "readable")
      rescue StandardError => e
        return make_server_error_response("server error: can't serialize response to JSON: #{e.message}")
      end

      make_ok_json_response(res_json)
    end

    private

    sig { params(req_body: String).returns(T.any([T.untyped, MethodEntry, String], RawServiceResponse)) }
    def parse_request(req_body)
      first_char = req_body[0] || ""
      method_name = T.let("", String)
      method_number = T.let(nil, T.nilable(Integer))
      format = T.let("", String)
      is_json_obj = T.let(false, T::Boolean)
      raw_payload = T.let(nil, T.untyped)

      if first_char.match?(/\A\s\z/) || first_char == "{"
        begin
          req_body_json = JSON.parse(req_body)
        rescue JSON::ParserError
          return make_bad_request_response("bad request: invalid JSON")
        end
        return make_bad_request_response("bad request: invalid JSON") unless req_body_json.is_a?(Hash)

        unless req_body_json.key?("method")
          return make_bad_request_response("bad request: missing 'method' field in JSON")
        end

        method_field = req_body_json["method"]
        if method_field.is_a?(String)
          method_name = method_field
          method_number = nil
        elsif method_field.is_a?(Integer)
          method_name = "?"
          method_number = method_field
        else
          return make_bad_request_response("bad request: 'method' field must be a string or an integer")
        end
        format = "readable"
        unless req_body_json.key?("request")
          return make_bad_request_response("bad request: missing 'request' field in JSON")
        end

        is_json_obj = true
        raw_payload = req_body_json["request"]
      else
        parts = req_body.split(":", 4)
        return make_bad_request_response("bad request: invalid request format") if parts.length != 4

        method_name = T.must(parts[0])
        method_number_str = T.must(parts[1])
        format = T.must(parts[2])
        raw_payload = T.must(parts[3])
        unless method_number_str.empty?
          begin
            method_number = Integer(method_number_str)
          rescue ArgumentError
            return make_bad_request_response("bad request: can't parse method number")
          end
        end
      end

      if method_number.nil?
        matches = @number_to_method_impl.values.select { |m| m.method.name == method_name }
        if matches.empty?
          return make_bad_request_response("bad request: method not found: #{method_name}")
        elsif matches.length > 1
          return make_bad_request_response("bad request: method name '#{method_name}' is ambiguous; use method number instead")
        end
        method_number = T.must(matches[0]).method.number
      end

      entry = @number_to_method_impl[method_number]
      if entry.nil?
        return make_bad_request_response("bad request: method not found: #{method_name}; number: #{method_number}")
      end

      begin
        req_ser = entry.method.request_serializer
        req =
          if is_json_obj
            req_ser.from_json(raw_payload, keep_unrecognized_values: @options.keep_unrecognized_values)
          else
            req_ser.from_json_code(raw_payload, keep_unrecognized_values: @options.keep_unrecognized_values)
          end
      rescue StandardError => e
        return make_bad_request_response("bad request: can't parse JSON: #{e.message}")
      end

      [req, entry, format]
    end

    sig { returns(RawServiceResponse) }
    def handle_list
      methods_list = @number_to_method_impl.values.map do |entry|
        m = entry.method
        {
          "method" => m.name,
          "number" => m.number,
          "request" => m.request_serializer.type_descriptor.as_json,
          "response" => m.response_serializer.type_descriptor.as_json,
          "docs" => m.doc
        }
      end
      json_code = JSON.pretty_generate({ "methods" => methods_list })
      make_ok_json_response(json_code)
    end

    sig { returns(RawServiceResponse) }
    def handle_studio
      escaped_url = CGI.escapeHTML(@options.studio_app_js_url)
      html = <<~HTML
        <!DOCTYPE html>

        <html>
          <head>
            <meta charset="utf-8" />
            <title>RPC Studio</title>
            <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🐙</text></svg>">
            <script src="#{escaped_url}"></script>
          </head>
          <body style="margin: 0; padding: 0;">
            <skir-studio-app></skir-studio-app>
          </body>
        </html>
      HTML
      RawServiceResponse.new(
        data: html,
        status_code: 200,
        content_type: "text/html; charset=utf-8"
      )
    end

    sig { params(data: String).returns(RawServiceResponse) }
    def make_ok_json_response(data)
      RawServiceResponse.new(
        data: data,
        status_code: 200,
        content_type: "application/json"
      )
    end

    sig { params(data: String).returns(RawServiceResponse) }
    def make_bad_request_response(data)
      RawServiceResponse.new(
        data: data,
        status_code: 400,
        content_type: "text/plain; charset=utf-8"
      )
    end

    sig { params(data: String, status_code: Integer).returns(RawServiceResponse) }
    def make_server_error_response(data, status_code = 500)
      RawServiceResponse.new(
        data: data,
        status_code: status_code,
        content_type: "text/plain; charset=utf-8"
      )
    end
  end
end
