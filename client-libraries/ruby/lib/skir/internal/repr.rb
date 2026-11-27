# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "time"
require_relative "../keyed_items"

module Skir
  module Internal
    module Repr
      extend T::Sig

      class ReprResult
        extend T::Sig

        sig { returns(String) }
        attr_reader :repr

        sig { returns(T::Boolean) }
        attr_reader :complex

        sig { params(repr: String, complex: T::Boolean).void }
        def initialize(repr, complex:)
          @repr = T.let(repr, String)
          @complex = T.let(complex, T::Boolean)
        end

        sig { returns(String) }
        def indented
          @complex ? @repr.gsub("\n", "\n  ") : @repr
        end
      end

      sig { params(input: T.untyped).returns(ReprResult) }
      def self.repr_impl(input)
        if input.is_a?(Array) || input.is_a?(KeyedItems)
          arr = input.is_a?(KeyedItems) ? input.to_a : input
          if arr.empty?
            ReprResult.new("[]", complex: false)
          elsif arr.length == 1
            only_item_repr = repr_impl(arr[0])
            if only_item_repr.complex
              ReprResult.new("[\n  #{only_item_repr.indented},\n]", complex: true)
            else
              ReprResult.new("[#{only_item_repr.repr}]", complex: true)
            end
          else
            body = arr.map { |item| "  #{repr_impl(item).indented},\n" }.join
            ReprResult.new("[\n#{body}]", complex: true)
          end
        elsif input.is_a?(String)
          if input.include?("\n") && input.encoding != Encoding::ASCII_8BIT
            lines = input.split("\n", -1)
            body = lines.map { |line| "  #{line.inspect},\n" }.join
            ReprResult.new("[\n#{body}].join(\"\\n\")", complex: true)
          else
            ReprResult.new(input.inspect, complex: false)
          end
        elsif input.is_a?(Time)
          utc_time = input.utc
          iso = utc_time.subsec.zero? ? utc_time.iso8601 : utc_time.iso8601(3)
          ReprResult.new("Time.iso8601(#{iso.inspect})", complex: false)
        else
          r = input.inspect
          ReprResult.new(r, complex: !r.match(/[\[\(\n]/).nil?)
        end
      end
    end
  end
end
