# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Skir
  # An immutable array-like collection of items with lazy O(1) key lookup.
  #
  # When duplicate keys exist, `find` and `find_or_default` return the last
  # item matching the key.
  class KeyedItems
    extend T::Sig
    extend T::Generic

    Elem = type_member(:out)
    Key = type_member

    include Enumerable

    sig { returns(T.untyped) }
    attr_reader :_key_fn

    sig { params(items: T::Array[Elem], key_fn: T.proc.params(arg0: Elem).returns(Key), default_item: T.nilable(Elem)).void }
    def initialize(items, key_fn, default_item = nil)
      @items = T.let(items.frozen? ? items : items.dup.freeze, T::Array[Elem])
      @key_fn = T.let(key_fn, T.proc.params(arg0: Elem).returns(Key))
      @_key_fn = T.let(key_fn, T.proc.params(arg0: Elem).returns(Key))
      @default_item = T.let(default_item, T.nilable(Elem))
      @map = T.let(nil, T.nilable(T::Hash[Key, Elem]))
    end

    sig do
      type_parameters(:E, :K)
        .params(
          items: T::Enumerable[T.type_parameter(:E)],
          key_fn: T.proc.params(arg0: T.type_parameter(:E)).returns(T.type_parameter(:K)),
          default_item: T.nilable(T.type_parameter(:E))
        )
        .returns(KeyedItems[T.type_parameter(:E), T.type_parameter(:K)])
    end
    def self.create(items, key_fn, default_item = nil)
      KeyedItems[T.type_parameter(:E), T.type_parameter(:K)].new(items.to_a, key_fn, default_item)
    end

    sig { override.params(blk: T.proc.params(arg0: Elem).returns(BasicObject)).void }
    def each(&blk)
      @items.each(&blk)
    end

    sig { returns(Integer) }
    def length
      @items.length
    end

    alias size length
    alias count length

    sig { returns(T::Boolean) }
    def empty?
      @items.empty?
    end

    sig { params(index: Integer).returns(T.nilable(Elem)) }
    def [](index)
      @items[index]
    end

    sig { returns(T.nilable(Elem)) }
    def first
      @items.first
    end

    sig { returns(T.nilable(Elem)) }
    def last
      @items.last
    end

    sig { returns(T::Array[Elem]) }
    def to_a
      @items
    end

    alias to_ary to_a

    sig { params(key: Key).returns(T.nilable(Elem)) }
    def find(key)
      ensure_map[key]
    end

    sig { params(key: Key).returns(Elem) }
    def find_or_default(key)
      found = find(key)
      case found
      when nil
        default_val = @default_item
        case default_val
        when nil
          raise KeyError, "No default item available for KeyedItems"
        else
          default_val
        end
      else
        found
      end
    end

    sig { params(other: BasicObject).returns(T::Boolean) }
    def ==(other)
      case other
      when KeyedItems
        @items == other.to_a
      when Array
        @items == other
      else
        false
      end
    end

    sig { params(other: BasicObject).returns(T::Boolean) }
    def eql?(other)
      self == other
    end

    sig { returns(Integer) }
    def hash
      @items.hash
    end

    sig { returns(String) }
    def to_s
      @items.to_s
    end

    sig { returns(String) }
    def inspect
      @items.inspect
    end

    private

    sig { returns(T::Hash[Key, Elem]) }
    def ensure_map
      m = @map
      return m unless m.nil?

      built = T.let({}, T::Hash[Key, Elem])
      @items.each do |item|
        built[@key_fn.call(item)] = item
      end
      built.freeze
      @map = built
      built
    end
  end
end
