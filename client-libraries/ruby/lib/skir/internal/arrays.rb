# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "../keyed_items"
require_relative "../reflection"
require_relative "binary"
require_relative "type_adapter"

module Skir
  module Internal
    module Arrays
      extend T::Sig

      class ArrayAdapter < TypeAdapter
        extend T::Sig

        EMPTY_FROZEN_ARRAY = T.let([].freeze, T::Array[T.untyped])

        sig { returns(TypeAdapter) }
        attr_reader :item_adapter

        sig { returns(T::Array[String]) }
        attr_reader :key_attributes

        sig { params(item_adapter: TypeAdapter, key_attributes: T::Array[String]).void }
        def initialize(item_adapter, key_attributes)
          super()
          @item_adapter = T.let(item_adapter, TypeAdapter)
          @key_attributes = T.let(key_attributes.map(&:to_s).freeze, T::Array[String])
          @key_fn = T.let(
            if @key_attributes.empty?
              nil
            else
              attrs = @key_attributes.map(&:to_sym)
              lambda do |item|
                cur = item
                attrs.each { |a| cur = cur.public_send(a) }
                cur
              end
            end,
            T.nilable(T.proc.params(arg0: T.untyped).returns(T.untyped))
          )
          @empty_instance = T.let(nil, T.untyped)
        end

        sig { returns(T.untyped) }
        def empty_instance
          inst = @empty_instance
          return inst unless inst.nil?

          built =
            if @key_fn.nil?
              [].freeze
            else
              KeyedItems.new(EMPTY_FROZEN_ARRAY, @key_fn, @item_adapter.default_value)
            end
          @empty_instance = built
          built
        end

        sig { override.returns(T.untyped) }
        def default_value
          empty_instance
        end

        sig { override.params(arg: T.untyped).returns(T.untyped) }
        def to_frozen(arg)
          if @key_fn.nil?
            return arg if arg.is_a?(Array) && arg.equal?(empty_instance)

            unless arg.is_a?(Enumerable)
              raise TypeError, "Expected Enumerable for array field, got #{arg.class}"
            end

            mapped = arg.map { |e| @item_adapter.to_frozen(e) }
            return empty_instance if mapped.empty?

            mapped.freeze
          else
            if arg.is_a?(KeyedItems)
              return arg if arg._key_fn.equal?(@key_fn)

              arr = arg.to_a
              return empty_instance if arr.empty?

              return KeyedItems.new(arr, @key_fn, @item_adapter.default_value)
            end

            unless arg.is_a?(Enumerable)
              raise TypeError, "Expected Enumerable for keyed array field, got #{arg.class}"
            end

            mapped = arg.map { |e| @item_adapter.to_frozen(e) }
            return empty_instance if mapped.empty?

            KeyedItems.new(mapped, @key_fn, @item_adapter.default_value)
          end
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          !val.empty?
        end

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(T::Array[T.untyped]) }
        def to_json(val, readable)
          arr = val.is_a?(KeyedItems) ? val.to_a : val
          arr.map { |e| @item_adapter.to_json(e, readable) }
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(T.untyped) }
        def from_json(json, keep_unrecognized)
          return empty_instance if json.nil? || json == 0 || (json.is_a?(Array) && json.empty?)
          raise TypeError, "Expected Array for array JSON, got #{json.class}" unless json.is_a?(Array)

          mapped = json.map { |e| @item_adapter.from_json(e, keep_unrecognized) }
          if @key_fn.nil?
            mapped.freeze
          else
            KeyedItems.new(mapped, @key_fn, @item_adapter.default_value)
          end
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          arr = val.is_a?(KeyedItems) ? val.to_a : val
          if arr.nil? || arr.empty?
            buffer << 246
            return
          end
          len = arr.length
          if len <= 3
            buffer << (246 + len)
          else
            buffer << 250
            Binary.encode_length_prefix(len, buffer)
          end
          arr.each { |e| @item_adapter.encode(e, buffer) }
        end

        sig { override.params(stream: ByteStream).returns(T.untyped) }
        def decode(stream)
          wire = stream.read_wire
          return empty_instance if wire == 0 || wire == 246

          len = wire == 250 ? Binary.decode_int64(stream) : (wire - 246)
          return empty_instance if len <= 0

          mapped = Array.new(len) { @item_adapter.decode(stream) }
          if @key_fn.nil?
            mapped.freeze
          else
            KeyedItems.new(mapped, @key_fn, @item_adapter.default_value)
          end
        end

        sig { override.params(resolve_type_fn: T.proc.params(arg0: T.untyped).returns(TypeAdapter)).void }
        def finalize(resolve_type_fn)
          @item_adapter.finalize(resolve_type_fn)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          key_extractor = @key_attributes.map { |a| a.sub(/_+\z/, "") }.join(".")
          Reflection::ArrayType.new(
            value: Reflection::ArrayType::Array.new(
              item: @item_adapter.reflection_type,
              key_extractor: key_extractor
            )
          )
        end

        sig { override.params(registry: T::Hash[String, Reflection::Record]).void }
        def register_records(registry)
          @item_adapter.register_records(registry)
        end
      end

      CACHE = T.let({}, T::Hash[T::Array[T.untyped], ArrayAdapter])

      sig { params(item_adapter: TypeAdapter, key_attributes: T::Array[String]).returns(ArrayAdapter) }
      def self.get_array_adapter(item_adapter, key_attributes = [])
        key = [item_adapter.object_id, key_attributes]
        CACHE[key] ||= ArrayAdapter.new(item_adapter, key_attributes)
      end
    end
  end
end
