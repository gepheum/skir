# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "../reflection"
require_relative "type_adapter"

module Skir
  module Internal
    module Optionals
      extend T::Sig

      class OptionalAdapter < TypeAdapter
        extend T::Sig

        sig { returns(TypeAdapter) }
        attr_reader :other_adapter

        sig { params(other_adapter: TypeAdapter).void }
        def initialize(other_adapter)
          super()
          @other_adapter = T.let(other_adapter, TypeAdapter)
        end

        sig { override.returns(NilClass) }
        def default_value
          nil
        end

        sig { override.params(arg: T.untyped).returns(T.untyped) }
        def to_frozen(arg)
          arg.nil? ? nil : @other_adapter.to_frozen(arg)
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          !val.nil?
        end

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(T.untyped) }
        def to_json(val, readable)
          val.nil? ? nil : @other_adapter.to_json(val, readable)
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(T.untyped) }
        def from_json(json, keep_unrecognized)
          json.nil? ? nil : @other_adapter.from_json(json, keep_unrecognized)
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          if val.nil?
            buffer << 255
          else
            @other_adapter.encode(val, buffer)
          end
        end

        sig { override.params(stream: ByteStream).returns(T.untyped) }
        def decode(stream)
          if stream.buffer.getbyte(stream.position) == 255
            stream.position += 1
            nil
          else
            @other_adapter.decode(stream)
          end
        end

        sig { override.params(resolve_type_fn: T.proc.params(arg0: T.untyped).returns(TypeAdapter)).void }
        def finalize(resolve_type_fn)
          @other_adapter.finalize(resolve_type_fn)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::OptionalType.new(value: @other_adapter.reflection_type)
        end

        sig { override.params(registry: T::Hash[String, Reflection::Record]).void }
        def register_records(registry)
          @other_adapter.register_records(registry)
        end
      end

      CACHE = T.let({}, T::Hash[Integer, OptionalAdapter])

      sig { params(other_adapter: TypeAdapter).returns(OptionalAdapter) }
      def self.get_optional_adapter(other_adapter)
        CACHE[other_adapter.object_id] ||= OptionalAdapter.new(other_adapter)
      end
    end
  end
end
