# typed: strict
# frozen_string_literal: true

require "base64"
require "sorbet-runtime"
require "time"
require_relative "../reflection"
require_relative "binary"
require_relative "type_adapter"

module Skir
  module Internal
    module Primitives
      extend T::Sig

      MIN_SAFE_JS_INT = -9_007_199_254_740_991
      MAX_SAFE_JS_INT = 9_007_199_254_740_991

      class BoolAdapter < TypeAdapter
        extend T::Sig

        sig { override.returns(T::Boolean) }
        def default_value
          false
        end

        sig { override.params(arg: T.untyped).returns(T::Boolean) }
        def to_frozen(arg)
          arg ? true : false
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          val ? true : false
        end

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(T.untyped) }
        def to_json(val, readable)
          b = val ? true : false
          readable ? b : (b ? 1 : 0)
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(T::Boolean) }
        def from_json(json, keep_unrecognized)
          _ = keep_unrecognized
          if json == false || json == 0 || json == 0.0 || json == "0" || json.nil?
            false
          else
            true
          end
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          buffer << (to_frozen(val) ? 1 : 0)
        end

        sig { override.params(stream: ByteStream).returns(T::Boolean) }
        def decode(stream)
          Binary.decode_bool(stream)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::PrimitiveType.new(value: "bool")
        end
      end

      class AbstractIntAdapter < TypeAdapter
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { override.returns(Integer) }
        def default_value
          0
        end

        sig { override.params(arg: T.untyped).returns(Integer) }
        def to_frozen(arg)
          if arg.is_a?(Integer)
            arg
          elsif arg.is_a?(Float)
            arg.to_i
          else
            raise TypeError, "Expected Integer or Float, got #{arg.class}"
          end
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          val != 0
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(Integer) }
        def from_json(json, keep_unrecognized)
          _ = keep_unrecognized
          case json
          when Integer
            json
          when Float
            json.to_i
          when String
            Integer(json)
          else
            raise TypeError, "Cannot parse Integer from #{json.class}"
          end
        end
      end

      class Int32Adapter < AbstractIntAdapter
        extend T::Sig

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(Integer) }
        def to_json(val, readable)
          _ = readable
          i = to_frozen(val)
          i.clamp(Binary::MIN_INT32, Binary::MAX_INT32)
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          Binary.encode_int32(to_frozen(val), buffer)
        end

        sig { override.params(stream: ByteStream).returns(Integer) }
        def decode(stream)
          Binary.decode_int32(stream)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::PrimitiveType.new(value: "int32")
        end
      end

      class Int64Adapter < AbstractIntAdapter
        extend T::Sig

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(T.any(Integer, String)) }
        def to_json(val, readable)
          _ = readable
          i = to_frozen(val)
          if i < MIN_SAFE_JS_INT
            i <= Binary::MIN_INT64 ? "-9223372036854775808" : i.to_s
          elsif i <= MAX_SAFE_JS_INT
            i
          elsif i < Binary::MAX_INT64
            i.to_s
          else
            "9223372036854775807"
          end
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          Binary.encode_int64(to_frozen(val), buffer)
        end

        sig { override.params(stream: ByteStream).returns(Integer) }
        def decode(stream)
          Binary.decode_int64(stream)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::PrimitiveType.new(value: "int64")
        end
      end

      class Hash64Adapter < AbstractIntAdapter
        extend T::Sig

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(T.any(Integer, String)) }
        def to_json(val, readable)
          _ = readable
          i = to_frozen(val)
          if i <= 0
            0
          elsif i <= MAX_SAFE_JS_INT
            i
          elsif i < Binary::MAX_HASH64
            i.to_s
          else
            "18446744073709551615"
          end
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          Binary.encode_hash64(to_frozen(val), buffer)
        end

        sig { override.params(stream: ByteStream).returns(Integer) }
        def decode(stream)
          Binary.decode_hash64(stream)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::PrimitiveType.new(value: "hash64")
        end
      end

      class AbstractFloatAdapter < TypeAdapter
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { override.returns(Float) }
        def default_value
          0.0
        end

        sig { override.params(arg: T.untyped).returns(Float) }
        def to_frozen(arg)
          if arg.is_a?(Float)
            arg
          elsif arg.is_a?(Numeric)
            arg.to_f
          else
            raise TypeError, "Expected Numeric, got #{arg.class}"
          end
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          val != 0.0
        end

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(T.any(Float, String)) }
        def to_json(val, readable)
          _ = readable
          f = to_frozen(val)
          if f.finite?
            f
          elsif f.nan?
            "NaN"
          elsif f.infinite? == 1
            "Infinity"
          else
            "-Infinity"
          end
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(Float) }
        def from_json(json, keep_unrecognized)
          _ = keep_unrecognized
          case json
          when "NaN"
            Float::NAN
          when "Infinity"
            Float::INFINITY
          when "-Infinity"
            -Float::INFINITY
          when Numeric
            json.to_f
          else
            raise TypeError, "Cannot parse Float from #{json.class}"
          end
        end

        sig { override.params(stream: ByteStream).returns(Float) }
        def decode(stream)
          Binary.decode_float(stream)
        end
      end

      class Float32Adapter < AbstractFloatAdapter
        extend T::Sig

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          Binary.encode_float32(to_frozen(val), buffer)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::PrimitiveType.new(value: "float32")
        end
      end

      class Float64Adapter < AbstractFloatAdapter
        extend T::Sig

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          Binary.encode_float64(to_frozen(val), buffer)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::PrimitiveType.new(value: "float64")
        end
      end

      class TimestampAdapter < TypeAdapter
        extend T::Sig

        MIN_UNIX_MILLIS = -8_640_000_000_000_000
        MAX_UNIX_MILLIS = 8_640_000_000_000_000
        EPOCH = T.let(Time.at(0).utc.freeze, Time)

        sig { params(time: Time).returns(Integer) }
        def self.time_to_unix_millis(time)
          ((time.to_r * 1000).round.to_i).clamp(MIN_UNIX_MILLIS, MAX_UNIX_MILLIS)
        end

        sig { params(unix_millis: T.any(Integer, Float)).returns(Time) }
        def self.unix_millis_to_time(unix_millis)
          clamped = unix_millis.round.to_i.clamp(MIN_UNIX_MILLIS, MAX_UNIX_MILLIS)
          return EPOCH if clamped.zero?

          Time.at(Rational(clamped, 1000)).utc.freeze
        end

        sig { override.returns(Time) }
        def default_value
          EPOCH
        end

        sig { override.params(arg: T.untyped).returns(Time) }
        def to_frozen(arg)
          raise TypeError, "Expected Time, got #{arg.class}" unless arg.is_a?(Time)

          arg.frozen? ? arg : arg.dup.freeze
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          TimestampAdapter.time_to_unix_millis(to_frozen(val)) != 0
        end

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(T.untyped) }
        def to_json(val, readable)
          ms = TimestampAdapter.time_to_unix_millis(to_frozen(val))
          if readable
            t = TimestampAdapter.unix_millis_to_time(ms)
            {
              "unix_millis" => ms,
              "formatted" => t.iso8601(3)
            }
          else
            ms
          end
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(Time) }
        def from_json(json, keep_unrecognized)
          _ = keep_unrecognized
          case json
          when Integer
            TimestampAdapter.unix_millis_to_time(json)
          when Float, String
            TimestampAdapter.unix_millis_to_time(json.to_i)
          when Hash
            TimestampAdapter.unix_millis_to_time(json.fetch("unix_millis"))
          else
            raise TypeError, "Cannot parse Time from #{json.class}"
          end
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          ms = TimestampAdapter.time_to_unix_millis(to_frozen(val))
          if ms.zero?
            buffer << 0
          else
            buffer << 239 << [ms].pack("q<")
          end
        end

        sig { override.params(stream: ByteStream).returns(Time) }
        def decode(stream)
          ms = Binary.decode_int64(stream)
          TimestampAdapter.unix_millis_to_time(ms)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::PrimitiveType.new(value: "timestamp")
        end
      end

      class StringAdapter < TypeAdapter
        extend T::Sig

        sig { override.returns(String) }
        def default_value
          ""
        end

        sig { override.params(arg: T.untyped).returns(String) }
        def to_frozen(arg)
          raise TypeError, "Expected String, got #{arg.class}" unless arg.is_a?(String)
          return arg if arg.frozen? && arg.encoding == Encoding::UTF_8

          arg.encode(Encoding::UTF_8).freeze
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          !val.empty?
        end

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(String) }
        def to_json(val, readable)
          _ = readable
          to_frozen(val)
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(String) }
        def from_json(json, keep_unrecognized)
          _ = keep_unrecognized
          return "" if json == 0 || json.nil?
          raise TypeError, "Expected String, got #{json.class}" unless json.is_a?(String)

          json.frozen? ? json : json.dup.freeze
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          raise TypeError, "Expected String, got #{val.class}" unless val.is_a?(String)

          if val.empty?
            buffer << 242
          else
            buffer << 243
            utf8 =
              if val.encoding == Encoding::UTF_8 && val.valid_encoding?
                val
              else
                val.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
              end
            bytes_data = utf8.b
            Binary.encode_length_prefix(bytes_data.bytesize, buffer)
            buffer << bytes_data
          end
        end

        sig { override.params(stream: ByteStream).returns(String) }
        def decode(stream)
          wire = stream.read_wire
          return "" if wire == 0 || wire == 242

          length = Binary.decode_int64(stream)
          raw = stream.read(length)
          raw.force_encoding(Encoding::UTF_8).scrub("\uFFFD").freeze
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::PrimitiveType.new(value: "string")
        end
      end

      class BytesAdapter < TypeAdapter
        extend T::Sig

        EMPTY_BYTES = T.let("".b.freeze, String)

        sig { override.returns(String) }
        def default_value
          EMPTY_BYTES
        end

        sig { override.params(arg: T.untyped).returns(String) }
        def to_frozen(arg)
          raise TypeError, "Expected binary String, got #{arg.class}" unless arg.is_a?(String)
          return EMPTY_BYTES if arg.empty?
          return arg if arg.frozen? && arg.encoding == Encoding::ASCII_8BIT

          arg.b.freeze
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          !val.empty?
        end

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(String) }
        def to_json(val, readable)
          b = to_frozen(val)
          if readable
            "hex:#{b.unpack1('H*')}"
          else
            Base64.strict_encode64(b)
          end
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(String) }
        def from_json(json, keep_unrecognized)
          _ = keep_unrecognized
          return EMPTY_BYTES if json == 0 || json.nil? || json == ""
          raise TypeError, "Expected String for bytes JSON, got #{json.class}" unless json.is_a?(String)

          if json.start_with?("hex:")
            [json[4..] || ""].pack("H*").b.freeze
          else
            Base64.decode64(json).b.freeze
          end
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          b = to_frozen(val)
          if b.empty?
            buffer << 244
          else
            buffer << 245
            Binary.encode_length_prefix(b.bytesize, buffer)
            buffer << b
          end
        end

        sig { override.params(stream: ByteStream).returns(String) }
        def decode(stream)
          wire = stream.read_wire
          return EMPTY_BYTES if wire == 0 || wire == 244

          length = Binary.decode_int64(stream)
          stream.read(length).b.freeze
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::PrimitiveType.new(value: "bytes")
        end
      end

      BOOL_ADAPTER = T.let(BoolAdapter.new, BoolAdapter)
      INT32_ADAPTER = T.let(Int32Adapter.new, Int32Adapter)
      INT64_ADAPTER = T.let(Int64Adapter.new, Int64Adapter)
      HASH64_ADAPTER = T.let(Hash64Adapter.new, Hash64Adapter)
      FLOAT32_ADAPTER = T.let(Float32Adapter.new, Float32Adapter)
      FLOAT64_ADAPTER = T.let(Float64Adapter.new, Float64Adapter)
      TIMESTAMP_ADAPTER = T.let(TimestampAdapter.new, TimestampAdapter)
      STRING_ADAPTER = T.let(StringAdapter.new, StringAdapter)
      BYTES_ADAPTER = T.let(BytesAdapter.new, BytesAdapter)
    end
  end
end
