# typed: strict
# frozen_string_literal: true

require "json"
require "sorbet-runtime"

module Skir
  module Reflection
    class PrimitiveType
      extend T::Sig

      sig { returns(String) }
      attr_reader :kind

      sig { returns(String) }
      attr_reader :value

      sig { params(value: String, kind: String).void }
      def initialize(value:, kind: "primitive")
        @kind = T.let(kind.dup.freeze, String)
        @value = T.let(value.dup.freeze, String)
        freeze
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def to_h
        { "kind" => @kind, "value" => @value }
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when PrimitiveType
          @kind == other.kind && @value == other.value
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [PrimitiveType, @kind, @value].hash
      end
    end

    class OptionalType
      extend T::Sig

      sig { returns(String) }
      attr_reader :kind

      sig { returns(T.any(PrimitiveType, OptionalType, ArrayType, RecordType)) }
      attr_reader :value

      sig { params(value: T.any(PrimitiveType, OptionalType, ArrayType, RecordType), kind: String).void }
      def initialize(value:, kind: "optional")
        @kind = T.let(kind.dup.freeze, String)
        @value = T.let(value, T.any(PrimitiveType, OptionalType, ArrayType, RecordType))
        freeze
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def to_h
        { "kind" => @kind, "value" => @value.to_h }
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when OptionalType
          @kind == other.kind && @value == other.value
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [OptionalType, @kind, @value].hash
      end
    end

    class ArrayType
      extend T::Sig

      class Array
        extend T::Sig

        sig { returns(T.any(PrimitiveType, OptionalType, ArrayType, RecordType)) }
        attr_reader :item

        sig { returns(String) }
        attr_reader :key_extractor

        sig { params(item: T.any(PrimitiveType, OptionalType, ArrayType, RecordType), key_extractor: String).void }
        def initialize(item:, key_extractor: "")
          @item = T.let(item, T.any(PrimitiveType, OptionalType, ArrayType, RecordType))
          @key_extractor = T.let(key_extractor.dup.freeze, String)
          freeze
        end

        sig { returns(T::Hash[String, T.untyped]) }
        def to_h
          h = T.let({ "item" => @item.to_h }, T::Hash[String, T.untyped])
          h["key_extractor"] = @key_extractor unless @key_extractor.empty?
          h
        end

        sig { params(other: BasicObject).returns(T::Boolean) }
        def ==(other)
          case other
          when Array
            @item == other.item && @key_extractor == other.key_extractor
          else
            false
          end
        end

        alias eql? ==

        sig { returns(Integer) }
        def hash
          [Array, @item, @key_extractor].hash
        end
      end

      sig { returns(String) }
      attr_reader :kind

      sig { returns(Array) }
      attr_reader :value

      sig { params(value: Array, kind: String).void }
      def initialize(value:, kind: "array")
        @kind = T.let(kind.dup.freeze, String)
        @value = T.let(value, Array)
        freeze
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def to_h
        { "kind" => @kind, "value" => @value.to_h }
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when ArrayType
          @kind == other.kind && @value == other.value
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [ArrayType, @kind, @value].hash
      end
    end

    class RecordType
      extend T::Sig

      sig { returns(String) }
      attr_reader :kind

      sig { returns(String) }
      attr_reader :value

      sig { params(value: String, kind: String).void }
      def initialize(value:, kind: "record")
        @kind = T.let(kind.dup.freeze, String)
        @value = T.let(value.dup.freeze, String)
        freeze
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def to_h
        { "kind" => @kind, "value" => @value }
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when RecordType
          @kind == other.kind && @value == other.value
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [RecordType, @kind, @value].hash
      end
    end

    Type = T.type_alias { T.any(PrimitiveType, OptionalType, ArrayType, RecordType) }

    class Field
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(Type) }
      attr_reader :type

      sig { returns(Integer) }
      attr_reader :number

      sig { returns(String) }
      attr_reader :doc

      sig { params(name: String, type: Type, number: Integer, doc: String).void }
      def initialize(name:, type:, number:, doc: "")
        @name = T.let(name.dup.freeze, String)
        @type = T.let(type, Type)
        @number = T.let(number, Integer)
        @doc = T.let(doc.dup.freeze, String)
        freeze
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def to_h
        h = T.let(
          {
            "name" => @name,
            "number" => @number,
            "type" => @type.to_h
          },
          T::Hash[String, T.untyped]
        )
        h["doc"] = @doc unless @doc.empty?
        h
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when Field
          @name == other.name && @number == other.number && @type == other.type && @doc == other.doc
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [Field, @name, @number, @type, @doc].hash
      end
    end

    class Struct
      extend T::Sig

      sig { returns(String) }
      attr_reader :kind

      sig { returns(String) }
      attr_reader :id

      sig { returns(String) }
      attr_reader :doc

      sig { returns(T::Array[Field]) }
      attr_reader :fields

      sig { returns(T::Array[Integer]) }
      attr_reader :removed_numbers

      sig do
        params(
          id: String,
          fields: T::Array[Field],
          doc: String,
          removed_numbers: T::Array[Integer],
          kind: String
        ).void
      end
      def initialize(id:, fields:, doc: "", removed_numbers: [], kind: "struct")
        @kind = T.let(kind.dup.freeze, String)
        @id = T.let(id.dup.freeze, String)
        @doc = T.let(doc.dup.freeze, String)
        @fields = T.let(fields.dup.freeze, T::Array[Field])
        @removed_numbers = T.let(removed_numbers.dup.freeze, T::Array[Integer])
        freeze
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def to_h
        h = T.let(
          {
            "kind" => @kind,
            "id" => @id
          },
          T::Hash[String, T.untyped]
        )
        h["doc"] = @doc unless @doc.empty?
        h["fields"] = @fields.map(&:to_h)
        h["removed_numbers"] = @removed_numbers unless @removed_numbers.empty?
        h
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when Struct
          @kind == other.kind && @id == other.id && @doc == other.doc &&
            @fields == other.fields && @removed_numbers == other.removed_numbers
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [Struct, @kind, @id, @doc, @fields, @removed_numbers].hash
      end
    end

    class Variant
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(T.nilable(Type)) }
      attr_reader :type

      sig { returns(Integer) }
      attr_reader :number

      sig { returns(String) }
      attr_reader :doc

      sig { params(name: String, number: Integer, type: T.nilable(Type), doc: String).void }
      def initialize(name:, number:, type: nil, doc: "")
        @name = T.let(name.dup.freeze, String)
        @number = T.let(number, Integer)
        @type = T.let(type, T.nilable(Type))
        @doc = T.let(doc.dup.freeze, String)
        freeze
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def to_h
        h = T.let(
          {
            "name" => @name,
            "number" => @number
          },
          T::Hash[String, T.untyped]
        )
        t = @type
        h["type"] = t.to_h unless t.nil?
        h["doc"] = @doc unless @doc.empty?
        h
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when Variant
          @name == other.name && @number == other.number && @type == other.type && @doc == other.doc
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [Variant, @name, @number, @type, @doc].hash
      end
    end

    class Enum
      extend T::Sig

      sig { returns(String) }
      attr_reader :kind

      sig { returns(String) }
      attr_reader :id

      sig { returns(String) }
      attr_reader :doc

      sig { returns(T::Array[Variant]) }
      attr_reader :variants

      sig { returns(T::Array[Integer]) }
      attr_reader :removed_numbers

      sig do
        params(
          id: String,
          variants: T::Array[Variant],
          doc: String,
          removed_numbers: T::Array[Integer],
          kind: String
        ).void
      end
      def initialize(id:, variants:, doc: "", removed_numbers: [], kind: "enum")
        @kind = T.let(kind.dup.freeze, String)
        @id = T.let(id.dup.freeze, String)
        @doc = T.let(doc.dup.freeze, String)
        @variants = T.let(variants.dup.freeze, T::Array[Variant])
        @removed_numbers = T.let(removed_numbers.dup.freeze, T::Array[Integer])
        freeze
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def to_h
        h = T.let(
          {
            "kind" => @kind,
            "id" => @id
          },
          T::Hash[String, T.untyped]
        )
        h["doc"] = @doc unless @doc.empty?
        h["variants"] = @variants.map(&:to_h)
        h["removed_numbers"] = @removed_numbers unless @removed_numbers.empty?
        h
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when Enum
          @kind == other.kind && @id == other.id && @doc == other.doc &&
            @variants == other.variants && @removed_numbers == other.removed_numbers
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [Enum, @kind, @id, @doc, @variants, @removed_numbers].hash
      end
    end

    Record = T.type_alias { T.any(Struct, Enum) }

    class TypeDescriptor
      extend T::Sig

      sig { returns(Type) }
      attr_reader :type

      sig { returns(T::Array[Record]) }
      attr_reader :records

      sig { params(type: Type, records: T::Array[Record]).void }
      def initialize(type:, records:)
        @type = T.let(type, Type)
        @records = T.let(records.dup.freeze, T::Array[Record])
        freeze
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def as_json
        {
          "type" => @type.to_h,
          "records" => @records.map(&:to_h)
        }
      end

      sig { returns(String) }
      def as_json_code
        JSON.pretty_generate(as_json)
      end

      sig { params(json: T.untyped).returns(TypeDescriptor) }
      def self.from_json(json)
        raise ArgumentError, "Expected Hash for TypeDescriptor" unless json.is_a?(Hash)

        type = parse_type(json.fetch("type"))
        records_raw = json.fetch("records")
        raise ArgumentError, "Expected Array for records" unless records_raw.is_a?(Array)

        records = records_raw.map { |r| parse_record(r) }
        new(type: type, records: records)
      end

      sig { params(json_code: String).returns(TypeDescriptor) }
      def self.from_json_code(json_code)
        from_json(JSON.parse(json_code))
      end

      sig { params(other: BasicObject).returns(T::Boolean) }
      def ==(other)
        case other
        when TypeDescriptor
          @type == other.type && @records == other.records
        else
          false
        end
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        [TypeDescriptor, @type, @records].hash
      end

      VALID_PRIMITIVES = T.let(
        %w[bool int32 int64 hash64 float32 float64 timestamp string bytes].freeze,
        T::Array[String]
      )

      sig { params(json: T.untyped).returns(Type) }
      def self.parse_type(json)
        raise ArgumentError, "Expected Hash for Type" unless json.is_a?(Hash)

        kind = json.fetch("kind")
        value = json.fetch("value")
        case kind
        when "primitive"
          raise ArgumentError, "Invalid primitive: #{value}" unless value.is_a?(String) && VALID_PRIMITIVES.include?(value)

          PrimitiveType.new(value: value)
        when "optional"
          OptionalType.new(value: parse_type(value))
        when "array"
          raise ArgumentError, "Expected Hash for ArrayType.value" unless value.is_a?(Hash)

          item = parse_type(value.fetch("item"))
          key_extractor = value["key_extractor"] || ""
          raise ArgumentError, "Expected String for key_extractor" unless key_extractor.is_a?(String)

          ArrayType.new(value: ArrayType::Array.new(item: item, key_extractor: key_extractor))
        when "record"
          raise ArgumentError, "Expected String for RecordType.value" unless value.is_a?(String)

          RecordType.new(value: value)
        else
          raise ArgumentError, "Unknown Type kind: #{kind}"
        end
      end

      sig { params(json: T.untyped).returns(Record) }
      def self.parse_record(json)
        raise ArgumentError, "Expected Hash for Record" unless json.is_a?(Hash)

        kind = json.fetch("kind")
        id = json.fetch("id")
        raise ArgumentError, "Expected String for Record id" unless id.is_a?(String)

        doc = json["doc"] || ""
        raise ArgumentError, "Expected String for Record doc" unless doc.is_a?(String)

        removed_raw = json["removed_numbers"] || []
        raise ArgumentError, "Expected Array for removed_numbers" unless removed_raw.is_a?(Array)

        removed_numbers = removed_raw.map do |n|
          raise ArgumentError, "Expected Integer in removed_numbers" unless n.is_a?(Integer)

          n
        end

        case kind
        when "struct"
          fields_raw = json.fetch("fields")
          raise ArgumentError, "Expected Array for struct fields" unless fields_raw.is_a?(Array)

          fields = fields_raw.map do |f|
            raise ArgumentError, "Expected Hash for Field" unless f.is_a?(Hash)

            fname = f.fetch("name")
            fnum = f.fetch("number")
            ftype = parse_type(f.fetch("type"))
            fdoc = f["doc"] || ""
            raise ArgumentError, "Invalid Field types" unless fname.is_a?(String) && fnum.is_a?(Integer) && fdoc.is_a?(String)

            Field.new(name: fname, number: fnum, type: ftype, doc: fdoc)
          end
          Struct.new(id: id, doc: doc, fields: fields, removed_numbers: removed_numbers)
        when "enum"
          variants_raw = json.fetch("variants")
          raise ArgumentError, "Expected Array for enum variants" unless variants_raw.is_a?(Array)

          variants = variants_raw.map do |v|
            raise ArgumentError, "Expected Hash for Variant" unless v.is_a?(Hash)

            vname = v.fetch("name")
            vnum = v.fetch("number")
            vtype = v["type"] ? parse_type(v["type"]) : nil
            vdoc = v["doc"] || ""
            raise ArgumentError, "Invalid Variant types" unless vname.is_a?(String) && vnum.is_a?(Integer) && vdoc.is_a?(String)

            Variant.new(name: vname, number: vnum, type: vtype, doc: vdoc)
          end
          Enum.new(id: id, doc: doc, variants: variants, removed_numbers: removed_numbers)
        else
          raise ArgumentError, "Unknown Record kind: #{kind}"
        end
      end
    end
  end
end
