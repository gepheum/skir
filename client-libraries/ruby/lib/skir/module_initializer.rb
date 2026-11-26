# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "internal/arrays"
require_relative "internal/enums"
require_relative "internal/optionals"
require_relative "internal/primitives"
require_relative "internal/structs"
require_relative "method"
require_relative "serializer"
require_relative "spec"

module Skir
  module Internal
    extend T::Sig

    RecordAdapter = T.type_alias { T.any(Structs::StructAdapter, Enums::EnumAdapter) }

    RECORD_ID_TO_ADAPTER = T.let({}, T::Hash[String, RecordAdapter])

    sig do
      params(
        records: T::Array[T.any(Spec::Struct, Spec::Enum)],
        methods: T::Array[Spec::Method],
        constants: T::Array[Spec::Constant],
        target: T.untyped,
        record_id_to_adapter: T::Hash[String, RecordAdapter]
      ).void
    end
    def self.init_module(
      records:,
      methods:,
      constants:,
      target:,
      record_id_to_adapter: RECORD_ID_TO_ADAPTER
    )
      resolve_type = T.let(nil, T.nilable(T.proc.params(arg0: T.untyped).returns(TypeAdapter)))
      resolve_type = lambda do |type|
        case type
        when Symbol
          case type
          when Spec::PrimitiveType::BOOL then Primitives::BOOL_ADAPTER
          when Spec::PrimitiveType::BYTES then Primitives::BYTES_ADAPTER
          when Spec::PrimitiveType::FLOAT32 then Primitives::FLOAT32_ADAPTER
          when Spec::PrimitiveType::FLOAT64 then Primitives::FLOAT64_ADAPTER
          when Spec::PrimitiveType::INT32 then Primitives::INT32_ADAPTER
          when Spec::PrimitiveType::INT64 then Primitives::INT64_ADAPTER
          when Spec::PrimitiveType::HASH64 then Primitives::HASH64_ADAPTER
          when Spec::PrimitiveType::STRING then Primitives::STRING_ADAPTER
          when Spec::PrimitiveType::TIMESTAMP then Primitives::TIMESTAMP_ADAPTER
          else
            raise ArgumentError, "Unknown primitive symbol: #{type}"
          end
        when Spec::ArrayType
          Arrays.get_array_adapter(T.must(resolve_type).call(type.item), type.key_attributes)
        when Spec::OptionalType
          Optionals.get_optional_adapter(T.must(resolve_type).call(type.other))
        when String
          record_id_to_adapter.fetch(type)
        else
          raise ArgumentError, "Unsupported type spec: #{type.inspect}"
        end
      end

      is_hash_target = target.is_a?(Hash)

      resolve_existing_class = lambda do |record|
        return nil if is_hash_target

        record_id = Spec::RecordId.parse(record.id)
        cur = target
        record_id.name_parts.each_with_index do |part, idx|
          cname = idx == record_id.name_parts.length - 1 ? record.class_name : part
          return nil unless cur.const_defined?(cname.to_sym, false)

          cur = cur.const_get(cname.to_sym, false)
        end
        cur
      end

      module_adapters = T.let([], T::Array[RecordAdapter])
      records.each do |record|
        raise ArgumentError, "Duplicate record id: #{record.id}" if record_id_to_adapter.key?(record.id)

        existing_class = resolve_existing_class.call(record)

        adapter =
          case record
          when Spec::Struct
            Structs::StructAdapter.new(record, existing_class)
          when Spec::Enum
            Enums::EnumAdapter.new(record, existing_class)
          end
        module_adapters << adapter
        record_id_to_adapter[record.id] = adapter
      end

      module_adapters.each do |adapter|
        adapter.finalize(resolve_type)
        gen_class = adapter.gen_class
        record_id = Spec::RecordId.parse(adapter.spec.id)
        parent_id = record_id.parent
        class_name = adapter.spec.class_name
        if parent_id
          parent_adapter = record_id_to_adapter.fetch(parent_id.record_id)
          unless parent_adapter.gen_class.const_defined?(class_name.to_sym, false) &&
                 parent_adapter.gen_class.const_get(class_name.to_sym, false).equal?(gen_class)
            Structs.safe_const_set(parent_adapter.gen_class, class_name.to_sym, gen_class)
          end
        elsif is_hash_target
          target[class_name] = gen_class
        else
          unless target.const_defined?(class_name.to_sym, false) &&
                 target.const_get(class_name.to_sym, false).equal?(gen_class)
            Structs.safe_const_set(target, class_name.to_sym, gen_class)
          end
        end

        ser = Internal.make_serializer(adapter)
        Structs.safe_remove_singleton_method(gen_class, :serializer)
        gen_class.define_singleton_method(:serializer) { ser }
      end

      methods.each do |method_spec|
        var_name = method_spec.var_name
        req_ser = Internal.make_serializer(resolve_type.call(method_spec.request_type))
        res_ser = Internal.make_serializer(resolve_type.call(method_spec.response_type))
        m = Method.new(
          name: method_spec.name,
          number: method_spec.number,
          request_serializer: req_ser,
          response_serializer: res_ser,
          doc: method_spec.doc
        )
        if is_hash_target
          target[var_name] = m
        else
          Structs.safe_const_set(target, var_name.to_sym, m)
        end
      end

      constants.each do |constant_spec|
        ser = Internal.make_serializer(resolve_type.call(constant_spec.type))
        val = ser.from_json_code(constant_spec.json_code)
        if is_hash_target
          target[constant_spec.name] = val
        else
          Structs.safe_const_set(target, constant_spec.name.to_sym, val)
        end
      end
    end
  end
end
