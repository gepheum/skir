# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "../reflection"

module Skir
  module Internal
    class ByteStream
      extend T::Sig

      sig { returns(String) }
      attr_reader :buffer

      sig { returns(Integer) }
      attr_accessor :position

      sig { returns(T::Boolean) }
      attr_reader :keep_unrecognized_values

      sig { params(buffer: String, position: Integer, keep_unrecognized_values: T::Boolean).void }
      def initialize(buffer, position: 0, keep_unrecognized_values: false)
        @buffer = T.let(buffer.b, String)
        @position = T.let(position, Integer)
        @keep_unrecognized_values = T.let(keep_unrecognized_values, T::Boolean)
      end

      sig { returns(Integer) }
      def read_wire
        b = @buffer.getbyte(@position)
        raise EOFError, "Unexpected end of Skir byte stream at #{@position}" if b.nil?

        @position += 1
        b
      end

      sig { params(length: Integer).returns(String) }
      def read(length)
        data = @buffer.byteslice(@position, length)
        if data.nil? || data.bytesize < length
          raise EOFError, "Unexpected end of Skir byte stream reading #{length} bytes at #{@position}"
        end

        @position += length
        data
      end
    end

    class TypeAdapter
      extend T::Sig
      extend T::Helpers
      abstract!

      sig { abstract.returns(T.untyped) }
      def default_value; end

      sig { abstract.params(arg: T.untyped).returns(T.untyped) }
      def to_frozen(arg); end

      sig { abstract.params(val: T.untyped).returns(T::Boolean) }
      def not_default?(val); end

      sig { abstract.params(val: T.untyped, readable: T::Boolean).returns(T.untyped) }
      def to_json(val, readable); end

      sig { abstract.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(T.untyped) }
      def from_json(json, keep_unrecognized); end

      sig { abstract.params(val: T.untyped, buffer: String).void }
      def encode(val, buffer); end

      sig { abstract.params(stream: ByteStream).returns(T.untyped) }
      def decode(stream); end

      sig { params(resolve_type_fn: T.proc.params(arg0: T.untyped).returns(TypeAdapter)).void }
      def finalize(resolve_type_fn); end

      sig { abstract.returns(Reflection::Type) }
      def reflection_type; end

      sig { params(registry: T::Hash[String, Reflection::Record]).void }
      def register_records(registry); end

      sig { returns(T.nilable(T::Class[T.anything])) }
      def frozen_class_of_struct
        nil
      end
    end
  end
end
