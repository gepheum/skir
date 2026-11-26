# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "../keep"
require_relative "../reflection"
require_relative "../spec"
require_relative "binary"
require_relative "repr"
require_relative "type_adapter"

module Skir
  module Internal
    module Structs
      extend T::Sig

      class UnrecognizedFields
        extend T::Sig

        sig { returns(T.nilable(T::Array[T.untyped])) }
        attr_reader :json

        sig { returns(T.nilable(String)) }
        attr_reader :raw_bytes

        sig { returns(T.nilable(Integer)) }
        attr_reader :adjusted_json_array_len

        sig { returns(T.nilable(Integer)) }
        attr_reader :adjusted_bytes_array_len

        sig do
          params(
            json: T.nilable(T::Array[T.untyped]),
            raw_bytes: T.nilable(String),
            adjusted_json_array_len: T.nilable(Integer),
            adjusted_bytes_array_len: T.nilable(Integer)
          ).void
        end
        def initialize(json:, raw_bytes:, adjusted_json_array_len:, adjusted_bytes_array_len:)
          @json = T.let(json, T.nilable(T::Array[T.untyped]))
          @raw_bytes = T.let(raw_bytes, T.nilable(String))
          @adjusted_json_array_len = T.let(adjusted_json_array_len, T.nilable(Integer))
          @adjusted_bytes_array_len = T.let(adjusted_bytes_array_len, T.nilable(Integer))
          freeze
        end

        sig { params(json: T::Array[T.untyped], adjusted_json_array_len: Integer).returns(UnrecognizedFields) }
        def self.from_json(json:, adjusted_json_array_len:)
          new(
            json: deep_copy(json),
            raw_bytes: nil,
            adjusted_json_array_len: adjusted_json_array_len,
            adjusted_bytes_array_len: nil
          )
        end

        sig { params(raw_bytes: String, adjusted_bytes_array_len: Integer).returns(UnrecognizedFields) }
        def self.from_bytes(raw_bytes:, adjusted_bytes_array_len:)
          new(
            json: nil,
            raw_bytes: raw_bytes.b.freeze,
            adjusted_json_array_len: nil,
            adjusted_bytes_array_len: adjusted_bytes_array_len
          )
        end

        sig { params(val: T.untyped).returns(T.untyped) }
        def self.deep_copy(val)
          case val
          when Array
            val.map { |e| deep_copy(e) }.freeze
          when Hash
            h = {}
            val.each { |k, v| h[deep_copy(k)] = deep_copy(v) }
            h.freeze
          when String
            val.frozen? ? val : val.dup.freeze
          else
            val
          end
        end
      end

      class ResolvedField
        extend T::Sig

        sig { returns(Spec::Field) }
        attr_reader :field

        sig { returns(TypeAdapter) }
        attr_reader :type

        sig { returns(Symbol) }
        attr_reader :attr_sym

        sig { returns(Symbol) }
        attr_reader :ivar_sym

        sig { params(field: Spec::Field, type: TypeAdapter).void }
        def initialize(field, type)
          @field = T.let(field, Spec::Field)
          @type = T.let(type, TypeAdapter)
          @attr_sym = T.let(field.attribute.to_sym, Symbol)
          @ivar_sym = T.let(:"@#{field.attribute}", Symbol)
          freeze
        end
      end

      sig { params(klass: T.untyped, name: Symbol).void }
      def self.safe_remove_method(klass, name)
        old_verbose = $VERBOSE
        $VERBOSE = nil
        klass.send(:remove_method, name) if klass.method_defined?(name, false) || klass.private_method_defined?(name, false)
      rescue NameError
        nil
      ensure
        $VERBOSE = old_verbose
      end

      sig { params(klass: T.untyped, name: Symbol).void }
      def self.safe_remove_singleton_method(klass, name)
        old_verbose = $VERBOSE
        $VERBOSE = nil
        sclass = klass.singleton_class
        sclass.send(:remove_method, name) if sclass.method_defined?(name, false) || sclass.private_method_defined?(name, false)
      rescue NameError
        nil
      ensure
        $VERBOSE = old_verbose
      end

      sig { params(mod: T.untyped, name: T.any(String, Symbol), val: T.untyped).void }
      def self.safe_const_set(mod, name, val)
        sym = name.to_sym
        mod.send(:remove_const, sym) if mod.const_defined?(sym, false)
        mod.const_set(sym, val)
      end

      class StructAdapter < TypeAdapter
        extend T::Sig

        sig { returns(Spec::Struct) }
        attr_reader :spec

        sig { returns(T.untyped) }
        attr_reader :gen_class

        sig { returns(T.untyped) }
        attr_reader :mutable_class

        sig { returns(T::Array[ResolvedField]) }
        attr_reader :fields

        sig { params(spec: Spec::Struct, existing_class: T.untyped).void }
        def initialize(spec, existing_class = nil)
          super()
          @spec = T.let(spec, Spec::Struct)
          @finalization_state = T.let(0, Integer)
          @record_hash = T.let(spec.id.hash, Integer)
          @fields = T.let([], T::Array[ResolvedField])
          @num_slots_incl_removed = T.let(0, Integer)
          @num_slots_excl_removed = T.let(0, Integer)
          @adjust_table = T.let([], T::Array[Integer])

          frozen_class = existing_class || Class.new
          @gen_class = T.let(frozen_class, T.untyped)

          mut_class =
            if frozen_class.const_defined?(:Mutable, false)
              frozen_class.const_get(:Mutable, false)
            else
              c = Class.new
              frozen_class.const_set(:Mutable, c)
              c
            end
          @mutable_class = T.let(mut_class, T.untyped)

          default_inst = frozen_class.allocate
          Structs.safe_const_set(frozen_class, :DEFAULT, default_inst)
        end

        sig { override.params(resolve_type_fn: T.proc.params(arg0: T.untyped).returns(TypeAdapter)).void }
        def finalize(resolve_type_fn)
          return if @finalization_state != 0

          @finalization_state = 1

          sorted_fields = @spec.fields.map do |f|
            ResolvedField.new(f, resolve_type_fn.call(f.type))
          end.sort_by { |rf| rf.field.number }
          @fields = sorted_fields.freeze

          max_field_plus_one = @fields.empty? ? 0 : (T.must(@fields.last).field.number + 1)
          max_removed_plus_one = @spec.removed_numbers.empty? ? 0 : (T.must(@spec.removed_numbers.max) + 1)
          @num_slots_incl_removed = [max_field_plus_one, max_removed_plus_one, 0].max
          @num_slots_excl_removed = max_field_plus_one

          removed_set = @spec.removed_numbers.to_h { |n| [n, true] }
          table = [0]
          last_len = 0
          (0...(@num_slots_excl_removed - 1)).each do |i|
            if removed_set.key?(i)
              table << last_len
            else
              last_len = i + 1
              table << last_len
            end
          end
          @adjust_table = table.freeze

          @fields.each { |rf| rf.type.finalize(resolve_type_fn) }

          setup_classes
          init_default_instance

          @finalization_state = 2
        end

        sig { override.returns(T.untyped) }
        def default_value
          @gen_class.const_get(:DEFAULT, false)
        end

        sig { override.params(arg: T.untyped).returns(T.untyped) }
        def to_frozen(arg)
          return arg if arg.instance_of?(@gen_class)
          return arg.to_frozen if arg.instance_of?(@mutable_class)

          raise TypeError, "expected: #{@spec.class_qualname} or #{@spec.class_qualname}::Mutable; found: #{arg.class}"
        end

        sig { override.params(val: T.untyped).returns(T::Boolean) }
        def not_default?(val)
          !val.instance_variable_get(:@_unrecognized).nil? || val.instance_variable_get(:@_array_len) > 0
        end

        sig { override.params(val: T.untyped, readable: T::Boolean).returns(T.untyped) }
        def to_json(val, readable)
          readable ? struct_to_readable_json(val) : struct_to_dense_json(val)
        end

        sig { override.params(json: T.untyped, keep_unrecognized: T::Boolean).returns(T.untyped) }
        def from_json(json, keep_unrecognized)
          struct_from_json(json, keep_unrecognized)
        end

        sig { override.params(val: T.untyped, buffer: String).void }
        def encode(val, buffer)
          struct_encode(val, buffer)
        end

        sig { override.params(stream: ByteStream).returns(T.untyped) }
        def decode(stream)
          struct_decode(stream)
        end

        sig { override.returns(Reflection::Type) }
        def reflection_type
          Reflection::RecordType.new(value: @spec.id)
        end

        sig { override.params(registry: T::Hash[String, Reflection::Record]).void }
        def register_records(registry)
          record_id = @spec.id
          return if registry.key?(record_id)

          registry[record_id] = Reflection::Struct.new(
            id: record_id,
            doc: @spec.doc,
            fields: @fields.map do |rf|
              Reflection::Field.new(
                name: rf.field.name,
                number: rf.field.number,
                type: rf.type.reflection_type,
                doc: rf.field.doc
              )
            end,
            removed_numbers: @spec.removed_numbers
          )
          @fields.each { |rf| rf.type.register_records(registry) }
        end

        sig { override.returns(T.nilable(T::Class[T.anything])) }
        def frozen_class_of_struct
          @gen_class
        end

        sig { params(array_len: Integer).returns(Integer) }
        def adjust_array_len(array_len)
          if array_len < @num_slots_excl_removed
            @adjust_table[array_len] || 0
          else
            @num_slots_excl_removed
          end
        end

        sig { params(val: T.untyped).returns(Integer) }
        def compute_array_len(val)
          @fields.reverse_each do |rf|
            fval = val.instance_variable_get(rf.ivar_sym)
            return rf.field.number + 1 if rf.type.not_default?(fval)
          end
          0
        end

        sig { params(val: T.untyped).returns(T::Array[T.untyped]) }
        def struct_to_dense_json(val)
          unrec = val.instance_variable_get(:@_unrecognized)
          len = (unrec&.adjusted_json_array_len) || val.instance_variable_get(:@_array_len)
          ret = Array.new(len, 0)
          @fields.each do |rf|
            num = rf.field.number
            return ret if len <= num

            ret[num] = rf.type.to_json(val.instance_variable_get(rf.ivar_sym), false)
          end
          if @num_slots_incl_removed < len && unrec && unrec.json
            unrec.json.each_with_index do |elem, idx|
              ret[@num_slots_incl_removed + idx] = elem
            end
          end
          ret
        end

        sig { params(val: T.untyped).returns(T::Hash[String, T.untyped]) }
        def struct_to_readable_json(val)
          ret = T.let({}, T::Hash[String, T.untyped])
          @fields.each do |rf|
            fval = val.instance_variable_get(rf.ivar_sym)
            if rf.type.not_default?(fval)
              ret[rf.field.name] = rf.type.to_json(fval, true)
            end
          end
          ret
        end

        sig { params(val: T.untyped, buffer: String).void }
        def struct_encode(val, buffer)
          unrec = val.instance_variable_get(:@_unrecognized)
          len = (unrec&.adjusted_bytes_array_len) || val.instance_variable_get(:@_array_len)
          if len < 4
            buffer << (246 + len)
          else
            buffer << 250
            Binary.encode_length_prefix(len, buffer)
          end
          last_number = -1
          @fields.each do |rf|
            num = rf.field.number
            return if len <= num

            missing_slots = num - last_number - 1
            buffer << ("\x00".b * missing_slots) if missing_slots >= 1
            rf.type.encode(val.instance_variable_get(rf.ivar_sym), buffer)
            last_number = num
          end
          return if len <= @num_slots_incl_removed

          if @num_slots_excl_removed < @num_slots_incl_removed
            missing_slots = @num_slots_incl_removed - @num_slots_excl_removed
            buffer << ("\x00".b * missing_slots)
          end
          buffer << unrec.raw_bytes if unrec && unrec.raw_bytes
        end

        sig { params(json: T.untyped, keep_unrecognized: T::Boolean).returns(T.untyped) }
        def struct_from_json(json, keep_unrecognized)
          default_inst = default_value
          return default_inst if json.nil? || json == 0 || (json.is_a?(Array) && json.empty?) || (json.is_a?(Hash) && json.empty?)

          ret = @gen_class.allocate
          if json.is_a?(Array)
            array_len = json.length
            @fields.each do |rf|
              num = rf.field.number
              fval =
                if array_len <= num
                  rf.type.default_value
                else
                  rf.type.from_json(json[num], keep_unrecognized)
                end
              ret.instance_variable_set(rf.ivar_sym, fval)
            end
            if array_len <= @num_slots_incl_removed || !keep_unrecognized
              ret.instance_variable_set(:@_unrecognized, nil)
            else
              tail = json[@num_slots_incl_removed..] || []
              ret.instance_variable_set(
                :@_unrecognized,
                UnrecognizedFields.from_json(json: tail, adjusted_json_array_len: array_len)
              )
            end
            ret.instance_variable_set(:@_array_len, adjust_array_len(array_len))
          elsif json.is_a?(Hash)
            array_len = 0
            @fields.each do |rf|
              fname = rf.field.name
              if json.key?(fname)
                array_len = rf.field.number + 1
                ret.instance_variable_set(rf.ivar_sym, rf.type.from_json(json[fname], keep_unrecognized))
              else
                ret.instance_variable_set(rf.ivar_sym, rf.type.default_value)
              end
            end
            ret.instance_variable_set(:@_unrecognized, nil)
            ret.instance_variable_set(:@_array_len, array_len)
          else
            raise TypeError, "Expected Array or Hash for struct JSON, got #{json.class}"
          end
          ret.freeze
        end

        sig { params(stream: ByteStream).returns(T.untyped) }
        def struct_decode(stream)
          wire = stream.read_wire
          return default_value if wire == 0 || wire == 246

          array_len = wire == 250 ? Binary.decode_int64(stream) : (wire - 246)
          return default_value if array_len <= 0

          ret = @gen_class.allocate
          last_number = -1
          @fields.each do |rf|
            num = rf.field.number
            ((last_number + 1)...num).each do |removed_num|
              Binary.decode_unused(stream) if removed_num < array_len
            end
            fval =
              if array_len <= num
                rf.type.default_value
              else
                rf.type.decode(stream)
              end
            ret.instance_variable_set(rf.ivar_sym, fval)
            last_number = num
          end

          if array_len > @num_slots_excl_removed
            if array_len > @num_slots_incl_removed && stream.keep_unrecognized_values
              (@num_slots_incl_removed - @num_slots_excl_removed).times do
                Binary.decode_unused(stream)
              end
              start_offset = stream.position
              (array_len - @num_slots_incl_removed).times do
                Binary.decode_unused(stream)
              end
              end_offset = stream.position
              raw = stream.buffer.byteslice(start_offset, end_offset - start_offset) || "".b
              ret.instance_variable_set(
                :@_unrecognized,
                UnrecognizedFields.from_bytes(raw_bytes: raw, adjusted_bytes_array_len: array_len)
              )
            else
              (array_len - @num_slots_excl_removed).times do
                Binary.decode_unused(stream)
              end
              ret.instance_variable_set(:@_unrecognized, nil)
            end
          else
            ret.instance_variable_set(:@_unrecognized, nil)
          end

          ret.instance_variable_set(:@_array_len, adjust_array_len(array_len))
          ret.freeze
        end

        private

        sig { void }
        def init_default_instance
          default_inst = @gen_class.const_get(:DEFAULT, false)
          @fields.each do |rf|
            default_inst.instance_variable_set(rf.ivar_sym, rf.type.default_value)
          end
          default_inst.instance_variable_set(:@_unrecognized, nil)
          default_inst.instance_variable_set(:@_array_len, 0)
          default_inst.freeze
        end

        sig { void }
        def setup_classes
          adapter = self
          fields = @fields
          frozen_class = @gen_class
          mutable_class = @mutable_class
          qualname = @spec.class_qualname
          record_hash = @record_hash

          required_keys = fields.map(&:attr_sym).freeze
          field_map = fields.to_h { |rf| [rf.attr_sym, rf] }.freeze

          # Define attr_readers on frozen_class and attr_accessors on mutable_class
          fields.each do |rf|
            Structs.safe_remove_method(frozen_class, rf.attr_sym)
            frozen_class.send(:attr_reader, rf.attr_sym)

            Structs.safe_remove_method(mutable_class, rf.attr_sym)
            Structs.safe_remove_method(mutable_class, :"#{rf.attr_sym}=")
            mutable_class.send(:attr_accessor, rf.attr_sym)
          end

          Structs.safe_remove_method(frozen_class, :_unrecognized)
          Structs.safe_remove_method(frozen_class, :_array_len)
          frozen_class.send(:attr_reader, :_unrecognized, :_array_len)

          Structs.safe_remove_method(mutable_class, :_unrecognized)
          mutable_class.send(:attr_reader, :_unrecognized)

          # Frozen initialize
          Structs.safe_remove_method(frozen_class, :initialize)
          frozen_class.define_method(:initialize) do |**kwargs|
            missing = required_keys - kwargs.keys
            raise ArgumentError, "missing keyword#{missing.length > 1 ? 's' : ''}: #{missing.map(&:inspect).join(', ')}" unless missing.empty?

            unknown = kwargs.keys - required_keys
            raise ArgumentError, "unknown keyword#{unknown.length > 1 ? 's' : ''}: #{unknown.map(&:inspect).join(', ')}" unless unknown.empty?

            fields.each do |rf|
              val = rf.type.to_frozen(kwargs[rf.attr_sym])
              instance_variable_set(rf.ivar_sym, val)
            end
            instance_variable_set(:@_unrecognized, nil)
            instance_variable_set(:@_array_len, adapter.compute_array_len(self))
            freeze
          end

          # Frozen partial
          Structs.safe_remove_singleton_method(frozen_class, :partial)
          frozen_class.define_singleton_method(:partial) do |**kwargs|
            unknown = kwargs.keys - required_keys
            raise ArgumentError, "unknown keyword#{unknown.length > 1 ? 's' : ''}: #{unknown.map(&:inspect).join(', ')}" unless unknown.empty?

            full_kwargs = {}
            fields.each do |rf|
              full_kwargs[rf.attr_sym] = kwargs.key?(rf.attr_sym) ? kwargs[rf.attr_sym] : rf.type.default_value
            end
            frozen_class.new(**full_kwargs)
          end

          # Frozen replace
          Structs.safe_remove_method(frozen_class, :replace)
          frozen_class.define_method(:replace) do |**kwargs|
            unknown = kwargs.keys - required_keys
            raise ArgumentError, "unknown keyword#{unknown.length > 1 ? 's' : ''}: #{unknown.map(&:inspect).join(', ')}" unless unknown.empty?

            full_kwargs = {}
            fields.each do |rf|
              arg = kwargs.fetch(rf.attr_sym, Skir::KEEP)
              full_kwargs[rf.attr_sym] = arg.equal?(Skir::KEEP) ? instance_variable_get(rf.ivar_sym) : arg
            end
            frozen_class.new(**full_kwargs)
          end

          # Frozen to_frozen
          Structs.safe_remove_method(frozen_class, :to_frozen)
          frozen_class.define_method(:to_frozen) { self }

          # Frozen to_mutable
          Structs.safe_remove_method(frozen_class, :to_mutable)
          frozen_class.define_method(:to_mutable) do
            ret = mutable_class.allocate
            fields.each do |rf|
              ret.instance_variable_set(rf.ivar_sym, instance_variable_get(rf.ivar_sym))
            end
            ret.instance_variable_set(:@_unrecognized, instance_variable_get(:@_unrecognized))
            ret
          end

          # Mutable initialize
          Structs.safe_remove_method(mutable_class, :initialize)
          mutable_class.define_method(:initialize) do |**kwargs|
            unknown = kwargs.keys - required_keys
            raise ArgumentError, "unknown keyword#{unknown.length > 1 ? 's' : ''}: #{unknown.map(&:inspect).join(', ')}" unless unknown.empty?

            fields.each do |rf|
              val = kwargs.key?(rf.attr_sym) ? kwargs[rf.attr_sym] : rf.type.default_value
              instance_variable_set(rf.ivar_sym, val)
            end
            instance_variable_set(:@_unrecognized, nil)
          end

          # Mutable to_frozen
          Structs.safe_remove_method(mutable_class, :to_frozen)
          mutable_class.define_method(:to_frozen) do
            ret = frozen_class.allocate
            fields.each do |rf|
              val = rf.type.to_frozen(instance_variable_get(rf.ivar_sym))
              ret.instance_variable_set(rf.ivar_sym, val)
            end
            ret.instance_variable_set(:@_unrecognized, instance_variable_get(:@_unrecognized))
            ret.instance_variable_set(:@_array_len, adapter.compute_array_len(ret))
            ret.freeze
          end

          # Mutable getters
          fields.each do |rf|
            next unless rf.field.has_mutable_getter

            getter_name = :"mutable_#{rf.field.name}"
            Structs.safe_remove_method(mutable_class, getter_name)
            ivar = rf.ivar_sym
            field_type = rf.type
            if field_type.is_a?(StructAdapter)
              f_frozen = field_type.gen_class
              f_mutable = field_type.mutable_class
              f_qual = field_type.spec.class_qualname
              mutable_class.define_method(getter_name) do
                cur = instance_variable_get(ivar)
                return cur if cur.instance_of?(f_mutable)

                if cur.instance_of?(f_frozen)
                  mut = cur.to_mutable
                  instance_variable_set(ivar, mut)
                  return mut
                end
                raise TypeError, "expected: #{f_qual} or #{f_qual}::Mutable; found: #{cur.class}"
              end
            else
              mutable_class.define_method(getter_name) do
                cur = instance_variable_get(ivar)
                if cur.is_a?(Array) && !cur.frozen?
                  cur
                else
                  mut = cur.to_a.dup
                  instance_variable_set(ivar, mut)
                  mut
                end
              end
            end
          end

          # Equality & Hash on frozen_class
          Structs.safe_remove_method(frozen_class, :==)
          frozen_class.define_method(:==) do |other|
            return true if equal?(other)
            return false unless other.instance_of?(frozen_class)

            fields.all? do |rf|
              instance_variable_get(rf.ivar_sym) == other.instance_variable_get(rf.ivar_sym)
            end
          end

          Structs.safe_remove_method(frozen_class, :eql?)
          frozen_class.define_method(:eql?) { |other| self == other }

          Structs.safe_remove_method(frozen_class, :hash)
          frozen_class.define_method(:hash) do
            arr = [record_hash]
            fields.each { |rf| arr << instance_variable_get(rf.ivar_sym) }
            arr.hash
          end

          # inspect & to_s on both frozen_class and mutable_class
          repr_proc = lambda do |obj, is_mutable|
            if !is_mutable && obj.equal?(frozen_class.const_get(:DEFAULT, false))
              return "#{qualname}::DEFAULT"
            end

            assignments = []
            any_complex = T.let(false, T::Boolean)
            fields.each do |rf|
              r = Repr.repr_impl(obj.instance_variable_get(rf.ivar_sym))
              assignments << "#{rf.field.attribute}: #{r.indented}"
              any_complex = true if r.complex
            end
            body =
              if assignments.length <= 1 && !any_complex
                assignments.join
              else
                "\n" + assignments.map { |a| "  #{a},\n" }.join
              end
            prefix = is_mutable ? "#{qualname}::Mutable.new" : "#{qualname}.new"
            "#{prefix}(#{body})"
          end

          Structs.safe_remove_method(frozen_class, :inspect)
          Structs.safe_remove_method(frozen_class, :to_s)
          frozen_class.define_method(:inspect) { repr_proc.call(self, false) }
          frozen_class.define_method(:to_s) { inspect }

          Structs.safe_remove_method(mutable_class, :inspect)
          Structs.safe_remove_method(mutable_class, :to_s)
          mutable_class.define_method(:inspect) { repr_proc.call(self, true) }
          mutable_class.define_method(:to_s) { inspect }

          _ = field_map
        end
      end
    end
  end
end
