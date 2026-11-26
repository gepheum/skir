# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Skir
  module Spec
    module PrimitiveType
      BOOL = :BOOL
      INT32 = :INT32
      INT64 = :INT64
      HASH64 = :HASH64
      FLOAT32 = :FLOAT32
      FLOAT64 = :FLOAT64
      TIMESTAMP = :TIMESTAMP
      STRING = :STRING
      BYTES = :BYTES
    end

    class ArrayType
      extend T::Sig

      sig { returns(T.untyped) }
      attr_reader :item

      sig { returns(T::Array[String]) }
      attr_reader :key_attributes

      sig { params(item: T.untyped, key_attributes: T::Array[String]).void }
      def initialize(item, key_attributes = [])
        @item = item
        @key_attributes = T.let(key_attributes.map(&:to_s).freeze, T::Array[String])
        freeze
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when ArrayType
          @key_attributes == other.key_attributes && (@item == other.item ? true : false)
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [ArrayType, @item, @key_attributes].hash
      end
    end

    class OptionalType
      extend T::Sig

      sig { returns(T.untyped) }
      attr_reader :other

      sig { params(other: T.untyped).void }
      def initialize(other)
        @other = other
        freeze
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when OptionalType
          @other == other.other
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [OptionalType, @other].hash
      end
    end

    class RecordId
      extend T::Sig

      sig { returns(String) }
      attr_reader :record_id

      sig { returns(String) }
      attr_reader :module_path

      sig { returns(String) }
      attr_reader :name

      sig { returns(String) }
      attr_reader :qualname

      sig { returns(T::Array[String]) }
      attr_reader :name_parts

      sig do
        params(
          record_id: String,
          module_path: String,
          name: String,
          qualname: String,
          name_parts: T::Array[String]
        ).void
      end
      def initialize(record_id:, module_path:, name:, qualname:, name_parts:)
        @record_id = T.let(record_id.dup.freeze, String)
        @module_path = T.let(module_path.dup.freeze, String)
        @name = T.let(name.dup.freeze, String)
        @qualname = T.let(qualname.dup.freeze, String)
        @name_parts = T.let(name_parts.dup.freeze, T::Array[String])
        freeze
      end

      sig { params(record_id: String).returns(RecordId) }
      def self.parse(record_id)
        colon_index = record_id.rindex(":")
        raise ArgumentError, "Invalid record_id: #{record_id}" if colon_index.nil?

        module_path = record_id[0...colon_index] || ""
        qualname = record_id[(colon_index + 1)..] || ""
        name_parts = qualname.split(".")
        new(
          record_id: record_id,
          module_path: module_path,
          name: name_parts.last || "",
          qualname: qualname,
          name_parts: name_parts
        )
      end

      sig { returns(T.nilable(RecordId)) }
      def parent
        return nil if @name_parts.length <= 1

        parent_parts = @name_parts[0...-1] || []
        parent_qualname = parent_parts.join(".")
        RecordId.new(
          record_id: "#{@module_path}:#{parent_qualname}",
          module_path: @module_path,
          name: parent_parts.last || "",
          qualname: parent_qualname,
          name_parts: parent_parts
        )
      end
    end

    class Field
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(Integer) }
      attr_reader :number

      sig { returns(T.untyped) }
      attr_reader :type

      sig { returns(String) }
      attr_reader :doc

      sig { returns(T::Boolean) }
      attr_reader :has_mutable_getter

      sig { returns(String) }
      attr_reader :attribute

      sig do
        params(
          name: String,
          number: Integer,
          type: T.untyped,
          doc: String,
          has_mutable_getter: T::Boolean,
          attribute: String
        ).void
      end
      def initialize(name:, number:, type:, doc: "", has_mutable_getter: false, attribute: "")
        @name = T.let(name.dup.freeze, String)
        @number = T.let(number, Integer)
        @type = type
        @doc = T.let(doc.dup.freeze, String)
        @has_mutable_getter = T.let(has_mutable_getter, T::Boolean)
        attr_val = attribute.empty? ? name : attribute
        @attribute = T.let(attr_val.dup.freeze, String)
        freeze
      end
    end

    class Struct
      extend T::Sig

      sig { returns(String) }
      attr_reader :id

      sig { returns(String) }
      attr_reader :doc

      sig { returns(T::Array[Field]) }
      attr_reader :fields

      sig { returns(T::Array[Integer]) }
      attr_reader :removed_numbers

      sig { returns(String) }
      attr_reader :class_name

      sig { returns(String) }
      attr_reader :class_qualname

      sig do
        params(
          id: String,
          doc: String,
          fields: T::Array[Field],
          removed_numbers: T::Array[Integer],
          class_name: String,
          class_qualname: String
        ).void
      end
      def initialize(id:, doc: "", fields: [], removed_numbers: [], class_name: "", class_qualname: "")
        @id = T.let(id.dup.freeze, String)
        @doc = T.let(doc.dup.freeze, String)
        @fields = T.let(fields.dup.freeze, T::Array[Field])
        @removed_numbers = T.let(removed_numbers.dup.freeze, T::Array[Integer])
        parsed = RecordId.parse(id)
        cname = class_name.empty? ? parsed.name : class_name
        cqual = class_qualname.empty? ? parsed.qualname.gsub(".", "::") : class_qualname
        @class_name = T.let(cname.dup.freeze, String)
        @class_qualname = T.let(cqual.dup.freeze, String)
        freeze
      end
    end

    class ConstantVariant
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(Integer) }
      attr_reader :number

      sig { returns(String) }
      attr_reader :doc

      sig { returns(String) }
      attr_reader :attribute

      sig do
        params(
          name: String,
          number: Integer,
          doc: String,
          attribute: String
        ).void
      end
      def initialize(name:, number:, doc: "", attribute: "")
        @name = T.let(name.dup.freeze, String)
        @number = T.let(number, Integer)
        @doc = T.let(doc.dup.freeze, String)
        attr_val = attribute.empty? ? name : attribute
        @attribute = T.let(attr_val.dup.freeze, String)
        freeze
      end
    end

    class WrapperVariant
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(Integer) }
      attr_reader :number

      sig { returns(T.untyped) }
      attr_reader :type

      sig { returns(String) }
      attr_reader :doc

      sig do
        params(
          name: String,
          number: Integer,
          type: T.untyped,
          doc: String
        ).void
      end
      def initialize(name:, number:, type:, doc: "")
        @name = T.let(name.dup.freeze, String)
        @number = T.let(number, Integer)
        @type = type
        @doc = T.let(doc.dup.freeze, String)
        freeze
      end
    end

    class Enum
      extend T::Sig

      sig { returns(String) }
      attr_reader :id

      sig { returns(String) }
      attr_reader :doc

      sig { returns(T::Array[ConstantVariant]) }
      attr_reader :constant_variants

      sig { returns(T::Array[WrapperVariant]) }
      attr_reader :wrapper_variants

      sig { returns(T::Array[Integer]) }
      attr_reader :removed_numbers

      sig { returns(String) }
      attr_reader :class_name

      sig { returns(String) }
      attr_reader :class_qualname

      sig do
        params(
          id: String,
          doc: String,
          constant_variants: T::Array[ConstantVariant],
          wrapper_variants: T::Array[WrapperVariant],
          removed_numbers: T::Array[Integer],
          class_name: String,
          class_qualname: String
        ).void
      end
      def initialize(
        id:,
        doc: "",
        constant_variants: [],
        wrapper_variants: [],
        removed_numbers: [],
        class_name: "",
        class_qualname: ""
      )
        @id = T.let(id.dup.freeze, String)
        @doc = T.let(doc.dup.freeze, String)
        @constant_variants = T.let(constant_variants.dup.freeze, T::Array[ConstantVariant])
        @wrapper_variants = T.let(wrapper_variants.dup.freeze, T::Array[WrapperVariant])
        @removed_numbers = T.let(removed_numbers.dup.freeze, T::Array[Integer])
        parsed = RecordId.parse(id)
        cname = class_name.empty? ? parsed.name : class_name
        cqual = class_qualname.empty? ? parsed.qualname.gsub(".", "::") : class_qualname
        @class_name = T.let(cname.dup.freeze, String)
        @class_qualname = T.let(cqual.dup.freeze, String)
        freeze
      end
    end

    class Method
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(Integer) }
      attr_reader :number

      sig { returns(T.untyped) }
      attr_reader :request_type

      sig { returns(T.untyped) }
      attr_reader :response_type

      sig { returns(String) }
      attr_reader :doc

      sig { returns(String) }
      attr_reader :var_name

      sig do
        params(
          name: String,
          number: Integer,
          request_type: T.untyped,
          response_type: T.untyped,
          doc: String,
          var_name: String
        ).void
      end
      def initialize(name:, number:, request_type:, response_type:, doc: "", var_name: "")
        @name = T.let(name.dup.freeze, String)
        @number = T.let(number, Integer)
        @request_type = request_type
        @response_type = response_type
        @doc = T.let(doc.dup.freeze, String)
        vname = var_name.empty? ? name : var_name
        @var_name = T.let(vname.dup.freeze, String)
        freeze
      end
    end

    class Constant
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(T.untyped) }
      attr_reader :type

      sig { returns(String) }
      attr_reader :json_code

      sig { params(name: String, type: T.untyped, json_code: String).void }
      def initialize(name:, type:, json_code:)
        @name = T.let(name.dup.freeze, String)
        @type = type
        @json_code = T.let(json_code.dup.freeze, String)
        freeze
      end
    end
  end
end
