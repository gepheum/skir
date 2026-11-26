# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "../reflection"
require_relative "../spec"
require_relative "binary"
require_relative "repr"
require_relative "structs"
require_relative "type_adapter"

module Skir
  module Internal
    module Enums
      extend T::Sig

      class ResolvedWrapperVariant
        extend T::Sig

        sig { returns(Spec::WrapperVariant) }
        attr_reader :spec

        sig { returns(TypeAdapter) }
        attr_reader :value_type

        sig { returns(T.untyped) }
        attr_reader :variant_class

        sig { returns(String) }
        attr_reader :bytes_prefix

        sig { params(spec: Spec::WrapperVariant, value_type: TypeAdapter, variant_class: T.untyped).void }
        def initialize(spec, value_type, variant_class)
          @spec = T.let(spec, Spec::WrapperVariant)
          @value_type = T.let(value_type, TypeAdapter)
          @variant_class = T.let(variant_class, T.untyped)
          prefix = +"".b
          num = spec.number
          if num >= 1 && num <= 4
            prefix << (250 + num)
          else
            prefix << 248
            Binary.encode_int64(num, prefix)
          end
          @bytes_prefix = T.let(prefix.freeze, String)
          freeze
        end
      end

      class EnumAdapter < TypeAdapter
        extend T::Sig

        sig { returns(Spec::Enum) }
        attr_reader :spec

        sig { returns(T.untyped) }
        attr_reader :gen_class

        sig { returns(T::Array[ResolvedWrapperVariant]) }
        attr_reader :wrapper_variants

        sig { params(spec: Spec::Enum, existing_class: T.untyped).void }
        def initialize(spec, existing_class = nil)
          super()
          @spec = T.let(spec, Spec::Enum)
          @finalization_state = T.let(0, Integer)
          @record_hash = T.let(spec.id.hash, Integer)
          @wrapper_variants = T.let([], T::Array[ResolvedWrapperVariant])
          @key_to_constant = T.let({}, T::Hash[T.any(Integer, String), T.untyped])
          @number_to_constant = T.let({}, T::Hash[Integer, T.untyped])
          @number_to_wrapper = T.let({}, T::Hash[Integer, ResolvedWrapperVariant])
          @name_to_wrapper = T.let({}, T::Hash[String, ResolvedWrapperVariant])
          @removed_set = T.let(spec.removed_numbers.to_h { |n| [n, true] }.freeze, T::Hash[Integer, T::Boolean])

          base_class = existing_class || Class.new
          @gen_class = T.let(base_class, T.untyped)

          setup_base_class
          setup_constants
        end

        sig { returns(T::Array[Spec::ConstantVariant]) }
        def all_constant_variants
          unknown_variant = Spec::ConstantVariant.new(
            name: "UNKNOWN",
            number: 0,
            attribute: "UNKNOWN"
          )
          @spec.constant_variants + [unknown_variant]
        end

        sig { override.params(resolve_type_fn: T.proc.params(arg0: T.untyped).returns(TypeAdapter)).void }
        def finalize(resolve_type_fn)
          return if @finalization_state != 0

          @finalization_state = 1
          base_class = @gen_class

          resolved_wrappers = @spec.wrapper_variants.map do |wv|
            v_type = resolve_type_fn.call(wv.type)
            v_class = ensure_wrapper_variant_class(base_class, wv, v_type)
            ResolvedWrapperVariant.new(wv, v_type, v_class)
          end
          @wrapper_variants = resolved_wrappers.freeze

          @wrapper_variants.each do |rwv|
            @number_to_wrapper[rwv.spec.number] = rwv
            @name_to_wrapper[rwv.spec.name] = rwv
            rwv.value_type.finalize(resolve_type_fn)
          end
          @number_to_wrapper.freeze
          @name_to_wrapper.freeze

          setup_wrapper_factories(resolve_type_fn)

          @finalization_state = 2
        end

        sig { override.returns(T.untyped) }
        def default_value
          @number_to_constant.fetch(0)
        end

        sig { override.params(arg: T.untyped).returns(T.untyped) }
        def to_frozen(arg)
          return arg if arg.is_a?(@gen_class)

          raise TypeError, "expected: #{@spec.class_qualname}; found: #{arg.class}"
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          val.instance_variable_get(:@_number) != 0
        end

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(T.untyped) }
        def to_json(val, readable)
          readable ? val._rj : val._dj
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(T.untyped) }
        def from_json(json, keep_unrecognized)
          enum_from_json(json, keep_unrecognized)
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          b = val.instance_variable_get(:@_bytes)
          if b
            buffer << b
          else
            val._enc(buffer)
          end
        end

        sig { override.params(stream: ByteStream).returns(T.untyped) }
        def decode(stream)
          enum_decode(stream)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::RecordType.new(value: @spec.id)
        end

        sig { override.params(registry: T::Hash[String, Reflection::Record]).void }
        def register_records(registry)
          record_id = @spec.id
          return if registry.key?(record_id)

          const_vars = all_constant_variants.filter_map do |cv|
            next if cv.number == 0

            Reflection::Variant.new(
              name: cv.name.downcase,
              number: cv.number,
              type: nil,
              doc: cv.doc
            )
          end
          wrap_vars = @wrapper_variants.map do |rwv|
            Reflection::Variant.new(
              name: rwv.spec.name,
              number: rwv.spec.number,
              type: rwv.value_type.reflection_type,
              doc: rwv.spec.doc
            )
          end

          registry[record_id] = Reflection::Enum.new(
            id: record_id,
            doc: @spec.doc,
            variants: const_vars + wrap_vars,
            removed_numbers: @spec.removed_numbers
          )
          @wrapper_variants.each { |rwv| rwv.value_type.register_records(registry) }
        end

        sig { params(json: T.untyped, keep_unrecognized: T::Boolean).returns(T.untyped) }
        def enum_from_json(json, keep_unrecognized)
          unknown = @number_to_constant.fetch(0)
          case json
          when Integer
            const_val = @key_to_constant[json]
            return const_val unless const_val.nil?

            # Constant -> wrapper evolution compatibility
            rwv = @number_to_wrapper[json]
            if rwv
              dval = rwv.value_type.to_frozen(rwv.value_type.default_value)
              return instantiate_wrapper(rwv, dval)
            end

            return unknown if @removed_set.key?(json) || !keep_unrecognized

            instantiate_unrecognized(Structs::UnrecognizedFields.deep_copy(json), "\x00".b)
          when Array
            number = json[0]
            raise TypeError, "Expected Integer as first element of enum array JSON" unless number.is_a?(Integer)

            rwv = @number_to_wrapper[number]
            if rwv
              val = rwv.value_type.from_json(json[1], keep_unrecognized)
              return instantiate_wrapper(rwv, val)
            end

            # Wrapper -> constant evolution compatibility
            const_val = @key_to_constant[number]
            return const_val unless const_val.nil?

            return unknown if @removed_set.key?(number) || !keep_unrecognized

            instantiate_unrecognized(Structs::UnrecognizedFields.deep_copy(json), "\x00".b)
          when String
            @key_to_constant[json] || unknown
          when Hash
            kind = json["kind"]
            return unknown unless kind.is_a?(String)

            rwv = @name_to_wrapper[kind]
            return unknown if rwv.nil?

            val = rwv.value_type.from_json(json["value"], keep_unrecognized)
            instantiate_wrapper(rwv, val)
          else
            raise TypeError, "Cannot parse Enum from #{json.class}"
          end
        end

        sig { params(stream: ByteStream).returns(T.untyped) }
        def enum_decode(stream)
          unknown = @number_to_constant.fetch(0)
          start_offset = stream.position
          wire = stream.buffer.getbyte(start_offset)
          raise EOFError, "Unexpected end of stream decoding enum" if wire.nil?

          if wire <= 238
            if wire < 232
              stream.position += 1
              number = wire
            else
              number = Binary.decode_int64(stream)
            end
            const_val = @number_to_constant[number]
            return const_val unless const_val.nil?

            # Constant -> wrapper evolution compatibility
            rwv = @number_to_wrapper[number]
            if rwv
              dval = rwv.value_type.to_frozen(rwv.value_type.default_value)
              return instantiate_wrapper(rwv, dval)
            end

            return unknown if @removed_set.key?(number) || !stream.keep_unrecognized_values

            raw_bytes = stream.buffer.byteslice(start_offset, stream.position - start_offset) || "\x00".b
            return instantiate_unrecognized(0, raw_bytes.b.freeze)
          end

          stream.position += 1
          number = wire == 248 ? Binary.decode_int64(stream) : (wire - 250)
          rwv = @number_to_wrapper[number]
          if rwv
            val = rwv.value_type.decode(stream)
            return instantiate_wrapper(rwv, val)
          end

          Binary.decode_unused(stream)
          # Wrapper -> constant evolution compatibility
          const_val = @number_to_constant[number]
          return const_val unless const_val.nil?

          return unknown if @removed_set.key?(number) || !stream.keep_unrecognized_values

          raw_bytes = stream.buffer.byteslice(start_offset, stream.position - start_offset) || "\x00".b
          instantiate_unrecognized(0, raw_bytes.b.freeze)
        end

        private

        sig { params(rwv: ResolvedWrapperVariant, frozen_val: T.untyped).returns(T.untyped) }
        def instantiate_wrapper(rwv, frozen_val)
          inst = rwv.variant_class.allocate
          inst.instance_variable_set(:@kind, rwv.spec.name)
          inst.instance_variable_set(:@value, frozen_val)
          inst.instance_variable_set(:@_number, rwv.spec.number)
          inst.instance_variable_set(:@_bytes, nil)
          inst.freeze
        end

        sig { params(dj: T.untyped, raw_bytes: String).returns(T.untyped) }
        def instantiate_unrecognized(dj, raw_bytes)
          unknown_v_class = @gen_class.const_get(:V_UNKNOWN, false)
          inst = unknown_v_class.allocate
          inst.instance_variable_set(:@kind, "UNKNOWN")
          inst.instance_variable_set(:@value, nil)
          inst.instance_variable_set(:@_number, 0)
          inst.instance_variable_set(:@_dj, dj)
          inst.instance_variable_set(:@_rj, "unknown")
          inst.instance_variable_set(:@_bytes, raw_bytes.b.freeze)
          inst.freeze
        end

        sig { void }
        def setup_base_class
          base_class = @gen_class
          record_hash = @record_hash

          Structs.safe_remove_method(base_class, :kind)
          Structs.safe_remove_method(base_class, :value)
          base_class.send(:attr_reader, :kind, :value)

          Structs.safe_remove_method(base_class, :initialize)
          base_class.define_method(:initialize) do |*_args|
            raise TypeError, "Cannot call the constructor of a skir enum"
          end

          Structs.safe_remove_method(base_class, :union)
          base_class.define_method(:union) { self }

          Structs.safe_remove_method(base_class, :unknown?)
          base_class.define_method(:unknown?) { instance_variable_get(:@kind) == "UNKNOWN" }

          Structs.safe_remove_method(base_class, :present?)
          base_class.define_method(:present?) { instance_variable_get(:@kind) != "UNKNOWN" }

          Structs.safe_remove_method(base_class, :==)
          base_class.define_method(:==) do |other|
            return true if equal?(other)
            return false unless other.is_a?(base_class)

            instance_variable_get(:@kind) == other.kind && instance_variable_get(:@value) == other.value
          end

          Structs.safe_remove_method(base_class, :eql?)
          base_class.define_method(:eql?) { |other| self == other }

          Structs.safe_remove_method(base_class, :hash)
          base_class.define_method(:hash) { [record_hash, instance_variable_get(:@kind), instance_variable_get(:@value)].hash }

          Structs.safe_const_set(base_class, :Kind, String) unless base_class.const_defined?(:Kind, false)
        end

        sig { void }
        def setup_constants
          base_class = @gen_class
          qualname = @spec.class_qualname

          all_constant_variants.each do |cv|
            v_class_name = :"V_#{cv.name}"
            v_class =
              if base_class.const_defined?(v_class_name, false)
                base_class.const_get(v_class_name, false)
              else
                c = Class.new(base_class)
                base_class.const_set(v_class_name, c)
                c
              end

            encoded_bytes = +"".b
            Binary.encode_int64(cv.number, encoded_bytes)
            encoded_bytes.freeze
            rj_name = cv.name.downcase.freeze
            dj_num = cv.number
            attr_name = cv.attribute

            Structs.safe_remove_method(v_class, :kind)
            Structs.safe_remove_method(v_class, :value)
            Structs.safe_remove_method(v_class, :_dj)
            Structs.safe_remove_method(v_class, :_rj)
            Structs.safe_remove_method(v_class, :inspect)
            Structs.safe_remove_method(v_class, :to_s)
            v_class.define_method(:_dj) do
              instance_variable_defined?(:@_dj) ? instance_variable_get(:@_dj) : dj_num
            end
            v_class.define_method(:_rj) { rj_name }
            v_class.define_method(:inspect) { "#{qualname}::#{attr_name}" }
            v_class.define_method(:to_s) { inspect }

            inst = v_class.allocate
            inst.instance_variable_set(:@kind, cv.name)
            inst.instance_variable_set(:@value, nil)
            inst.instance_variable_set(:@_number, cv.number)
            inst.instance_variable_set(:@_bytes, encoded_bytes)
            inst.freeze

            # Ensure const_set works even if attribute starts with lowercase (e.g. in dynamic tests)
            const_sym = attr_name[0]&.match?(/[A-Z]/) ? attr_name.to_sym : nil
            Structs.safe_const_set(base_class, const_sym, inst) if const_sym
            Structs.safe_remove_singleton_method(base_class, attr_name.to_sym)
            base_class.define_singleton_method(attr_name.to_sym) { inst } unless const_sym

            @number_to_constant[cv.number] = inst
            @key_to_constant[cv.number] = inst
            @key_to_constant[cv.name] = inst
            @key_to_constant[cv.name.upcase] = inst
            @key_to_constant[cv.name.downcase] = inst
          end
          @number_to_constant.freeze
          @key_to_constant.freeze
        end

        sig { params(base_class: T.untyped, wv: Spec::WrapperVariant, v_type: TypeAdapter).returns(T.untyped) }
        def ensure_wrapper_variant_class(base_class, wv, v_type)
          qualname = @spec.class_qualname
          v_class_name = :"V_#{wv.name}"
          v_class =
            if base_class.const_defined?(v_class_name, false)
              base_class.const_get(v_class_name, false)
            else
              c = Class.new(base_class)
              base_class.const_set(v_class_name, c)
              c
            end

          num = wv.number
          vname = wv.name
          prefix = +"".b
          if num >= 1 && num <= 4
            prefix << (250 + num)
          else
            prefix << 248
            Binary.encode_int64(num, prefix)
          end
          prefix.freeze

          Structs.safe_remove_method(v_class, :kind)
          Structs.safe_remove_method(v_class, :value)
          Structs.safe_remove_method(v_class, :_dj)
          Structs.safe_remove_method(v_class, :_rj)
          Structs.safe_remove_method(v_class, :_enc)
          Structs.safe_remove_method(v_class, :inspect)
          Structs.safe_remove_method(v_class, :to_s)

          v_class.define_method(:_dj) { [num, v_type.to_json(instance_variable_get(:@value), false)] }
          v_class.define_method(:_rj) { { "kind" => vname, "value" => v_type.to_json(instance_variable_get(:@value), true) } }
          v_class.define_method(:_enc) do |buffer|
            buffer << prefix
            v_type.encode(instance_variable_get(:@value), buffer)
          end
          v_class.define_method(:inspect) do
            val_repr = Repr.repr_impl(instance_variable_get(:@value))
            body = val_repr.complex ? "\n  #{val_repr.indented}\n" : val_repr.repr
            "#{qualname}.wrap_#{vname}(#{body})"
          end
          v_class.define_method(:to_s) { inspect }
          v_class
        end

        sig { params(resolve_type_fn: T.proc.params(arg0: T.untyped).returns(TypeAdapter)).void }
        def setup_wrapper_factories(resolve_type_fn)
          base_class = @gen_class
          adapter = self
          @wrapper_variants.each do |rwv|
            wrap_name = :"wrap_#{rwv.spec.name}"
            Structs.safe_remove_singleton_method(base_class, wrap_name)
            base_class.define_singleton_method(wrap_name) do |value|
              frozen_val = rwv.value_type.to_frozen(value)
              adapter.send(:instantiate_wrapper, rwv, frozen_val)
            end

            value_type = resolve_type_fn.call(rwv.spec.type)
            struct_frozen_class = value_type.frozen_class_of_struct
            next unless struct_frozen_class

            create_name = :"create_#{rwv.spec.name}"
            Structs.safe_remove_singleton_method(base_class, create_name)
            base_class.define_singleton_method(create_name) do |**kwargs|
              struct_inst = struct_frozen_class.new(**kwargs)
              adapter.send(:instantiate_wrapper, rwv, struct_inst)
            end
          end
        end
      end
    end
  end
end
