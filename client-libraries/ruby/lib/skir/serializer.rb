# typed: strict
# frozen_string_literal: true

require "json"
require "sorbet-runtime"
require_relative "method"
require_relative "reflection"
require_relative "internal/type_adapter"

module Skir
  class Serializer
    sig { returns(Internal::TypeAdapter) }
    attr_reader :_adapter

    sig { params(adapter: Internal::TypeAdapter).void }
    def initialize(adapter)
      @_adapter = T.let(adapter, Internal::TypeAdapter)
      @type_descriptor = T.let(nil, T.nilable(Reflection::TypeDescriptor))
    end

    sig { params(input: Elem, readable: T::Boolean).returns(T.untyped) }
    def to_json(input, readable: false)
      frozen_val = @_adapter.to_frozen(input)
      @_adapter.to_json(frozen_val, readable)
    end

    sig { params(input: Elem, readable: T::Boolean).returns(String) }
    def to_json_code(input, readable: false)
      json_val = to_json(input, readable: readable)
      if readable
        JSON.pretty_generate(json_val)
      else
        JSON.generate(json_val)
      end
    end

    sig { params(json: T.untyped, keep_unrecognized_values: T::Boolean).returns(Elem) }
    def from_json(json, keep_unrecognized_values: false)
      @_adapter.from_json(json, keep_unrecognized_values)
    end

    sig { params(json_code: String, keep_unrecognized_values: T::Boolean).returns(Elem) }
    def from_json_code(json_code, keep_unrecognized_values: false)
      parsed = JSON.parse(json_code)
      from_json(parsed, keep_unrecognized_values: keep_unrecognized_values)
    end

    sig { params(input: Elem).returns(String) }
    def to_bytes(input)
      frozen_val = @_adapter.to_frozen(input)
      buffer = +"skir".b
      @_adapter.encode(frozen_val, buffer)
      buffer.freeze
    end

    sig { params(bytes: String, keep_unrecognized_values: T::Boolean).returns(Elem) }
    def from_bytes(bytes, keep_unrecognized_values: false)
      b = bytes.b
      if b.start_with?("skir".b)
        stream = Internal::ByteStream.new(b, position: 4, keep_unrecognized_values: keep_unrecognized_values)
        @_adapter.decode(stream)
      else
        from_json_code(bytes.dup.force_encoding(Encoding::UTF_8), keep_unrecognized_values: keep_unrecognized_values)
      end
    end

    sig { returns(Reflection::TypeDescriptor) }
    def type_descriptor
      td = @type_descriptor
      return td unless td.nil?

      records = T.let({}, T::Hash[String, Reflection::Record])
      @_adapter.register_records(records)
      built = Reflection::TypeDescriptor.new(
        type: @_adapter.reflection_type,
        records: records.values
      )
      @type_descriptor = built
      built
    end
  end

  module Internal
    extend T::Sig

    SERIALIZER_CACHE = T.let({}, T::Hash[Integer, Serializer[T.untyped]])

    sig { params(adapter: TypeAdapter).returns(Serializer[T.untyped]) }
    def self.make_serializer(adapter)
      SERIALIZER_CACHE[adapter.object_id] ||= Serializer.new(adapter)
    end
  end
end
