# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "type_adapter"

module Skir
  module Internal
    module Binary
      extend T::Sig

      MIN_INT32 = -2_147_483_648
      MAX_INT32 = 2_147_483_647
      MIN_INT64 = -9_223_372_036_854_775_808
      MAX_INT64 = 9_223_372_036_854_775_807
      MAX_HASH64 = T.let((1 << 64) - 1, Integer)

      sig { params(input_val: Integer, buffer: String).void }
      def self.encode_int32(input_val, buffer)
        if input_val < 0
          if input_val >= -256
            buffer << 235 << ((input_val + 256) & 0xFF)
          elsif input_val >= -65_536
            buffer << 236 << [input_val + 65_536].pack("S<")
          else
            clamped = input_val <= MIN_INT32 ? MIN_INT32 : input_val
            buffer << 237 << [clamped].pack("l<")
          end
        elsif input_val < 232
          buffer << input_val
        elsif input_val < 65_536
          buffer << 232 << [input_val].pack("S<")
        else
          clamped = input_val <= MAX_INT32 ? input_val : MAX_INT32
          buffer << 233 << [clamped].pack("L<")
        end
      end

      sig { params(value: Integer, buffer: String).void }
      def self.encode_int64(value, buffer)
        if value >= MIN_INT32 && value <= MAX_INT32
          encode_int32(value, buffer)
        else
          clamped =
            if value <= MIN_INT64
              MIN_INT64
            elsif value >= MAX_INT64
              MAX_INT64
            else
              value
            end
          buffer << 238 << [clamped].pack("q<")
        end
      end

      sig { params(value: Integer, buffer: String).void }
      def self.encode_hash64(value, buffer)
        if value < 232
          buffer << (value <= 0 ? 0 : value)
        elsif value < 65_536
          buffer << 232 << [value].pack("S<")
        elsif value < 4_294_967_296
          buffer << 233 << [value].pack("L<")
        else
          clamped = value <= MAX_HASH64 ? value : MAX_HASH64
          buffer << 234 << [clamped].pack("Q<")
        end
      end

      sig { params(value: Float, buffer: String).void }
      def self.encode_float32(value, buffer)
        if value == 0.0
          buffer << 0
        else
          buffer << 240 << [value].pack("e")
        end
      end

      sig { params(value: Float, buffer: String).void }
      def self.encode_float64(value, buffer)
        if value == 0.0
          buffer << 0
        else
          buffer << 241 << [value].pack("E")
        end
      end

      sig { params(length: Integer, buffer: String).void }
      def self.encode_length_prefix(length, buffer)
        if length < 232
          raise ArgumentError, "Length overflow: #{length}" if length < 0

          buffer << length
        elsif length < 65_536
          buffer << 232 << [length].pack("S<")
        elsif length < 4_294_967_296
          buffer << 233 << [length].pack("L<")
        else
          raise ArgumentError, "Length overflow: #{length}"
        end
      end

      sig { params(stream: ByteStream).returns(Numeric) }
      def self.decode_raw_number(stream)
        wire = stream.read_wire
        return wire if wire < 232

        case wire
        when 232
          T.cast(stream.read(2).unpack1("S<"), Integer)
        when 233
          T.cast(stream.read(4).unpack1("L<"), Integer)
        when 234
          T.cast(stream.read(8).unpack1("Q<"), Integer)
        when 235
          T.cast(stream.read(1).unpack1("C"), Integer) - 256
        when 236
          T.cast(stream.read(2).unpack1("S<"), Integer) - 65_536
        when 237
          T.cast(stream.read(4).unpack1("l<"), Integer)
        when 238, 239
          T.cast(stream.read(8).unpack1("q<"), Integer)
        when 240
          T.cast(stream.read(4).unpack1("e"), Float)
        when 241
          T.cast(stream.read(8).unpack1("E"), Float)
        else
          raise ArgumentError, "Unsupported number wire type: #{wire}"
        end
      end

      sig { params(stream: ByteStream).returns(T::Boolean) }
      def self.decode_bool(stream)
        raw = decode_raw_number(stream)
        raw != 0 && raw != 0.0
      end

      sig { params(stream: ByteStream).returns(Integer) }
      def self.decode_int32(stream)
        raw = decode_raw_number(stream).to_i
        raw.clamp(MIN_INT32, MAX_INT32)
      end

      sig { params(stream: ByteStream).returns(Integer) }
      def self.decode_int64(stream)
        raw = decode_raw_number(stream).to_i
        raw.clamp(MIN_INT64, MAX_INT64)
      end

      sig { params(stream: ByteStream).returns(Integer) }
      def self.decode_hash64(stream)
        raw = decode_raw_number(stream).to_i
        raw.clamp(0, MAX_HASH64)
      end

      sig { params(stream: ByteStream).returns(Float) }
      def self.decode_float(stream)
        decode_raw_number(stream).to_f
      end

      sig { params(stream: ByteStream).void }
      def self.decode_unused(stream)
        wire_offset = stream.read_wire - 232
        return if wire_offset < 0

        if wire_offset <= 9
          if wire_offset == 0 || wire_offset == 4
            stream.position += 2
          elsif wire_offset == 1 || wire_offset == 5 || wire_offset == 8
            stream.position += 4
          elsif wire_offset == 3
            stream.position += 1
          else
            stream.position += 8
          end
        elsif wire_offset == 11 || wire_offset == 13
          length = decode_int64(stream)
          stream.position += length
        elsif wire_offset == 15 || (wire_offset >= 19 && wire_offset <= 22)
          decode_unused(stream)
        elsif wire_offset == 16
          decode_unused(stream)
          decode_unused(stream)
        elsif wire_offset == 17
          decode_unused(stream)
          decode_unused(stream)
          decode_unused(stream)
        elsif wire_offset == 18
          length = decode_int64(stream)
          length.times { decode_unused(stream) }
        end
      end
    end
  end
end
