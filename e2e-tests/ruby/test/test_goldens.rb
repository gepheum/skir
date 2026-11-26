# typed: false
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "skir"
require_relative "../skirout/external/gepheum/skir_golden_tests/goldens_skir"

class GoldensTest < Minitest::Test
  Goldens = Skirout::External::Gepheum::SkirGoldenTests::GoldensSkir
  Assertion = Goldens::Assertion
  BytesExpression = Goldens::BytesExpression
  Color = Goldens::Color
  EnumA = Goldens::EnumA
  EnumB = Goldens::EnumB
  KeyedArrays = Goldens::KeyedArrays
  MyEnum = Goldens::MyEnum
  Point = Goldens::Point
  RecEnum = Goldens::RecEnum
  RecStruct = Goldens::RecStruct
  StringExpression = Goldens::StringExpression
  TypedValue = Goldens::TypedValue
  UNIT_TESTS = Goldens::UNIT_TESTS

  class GoldenAssertionError < StandardError
    attr_reader :actual, :expected

    def initialize(actual: nil, expected: nil, message: nil)
      @actual = actual
      @expected = expected
      @msg = message || "Actual: #{actual}, Expected: #{expected}"
      super(@msg)
    end

    def add_context(context)
      @msg = @msg && !@msg.empty? ? "#{@msg}\n#{context}" : context
    end

    def message
      @msg
    end
  end

  TypedValueType = Struct.new(:value, :serializer, keyword_init: true)

  def test_goldens
    assert_equal 101, UNIT_TESTS.length
    UNIT_TESTS.each do |unit_test|
      verify_assertion(unit_test.assertion)
    rescue GoldenAssertionError => e
      e.add_context("While evaluating test ##{unit_test.test_number}")
      raise e
    end
  end

  def verify_assertion(assertion)
    u = assertion.union
    case u.kind
    when "bytes_equal"
      actual = evaluate_bytes(u.value.actual).unpack1("H*")
      expected = evaluate_bytes(u.value.expected).unpack1("H*")
      if actual != expected
        raise GoldenAssertionError.new(actual: "hex:#{actual}", expected: "hex:#{expected}")
      end
    when "bytes_in"
      actual = evaluate_bytes(u.value.actual)
      actual_hex = actual.unpack1("H*")
      found = u.value.expected.any? { |b| b.unpack1("H*") == actual_hex }
      unless found
        raise GoldenAssertionError.new(
          actual: "hex:#{actual_hex}",
          expected: u.value.expected.map { |b| "hex:#{b.unpack1('H*')}" }.join(" or ")
        )
      end
    when "string_equal"
      actual = evaluate_string(u.value.actual)
      expected = evaluate_string(u.value.expected)
      if actual != expected
        raise GoldenAssertionError.new(
          actual: actual,
          expected: expected,
          message: "Actual: #{JSON.generate(actual)}, Expected: #{JSON.generate(expected)}"
        )
      end
    when "string_in"
      actual = evaluate_string(u.value.actual)
      unless u.value.expected.include?(actual)
        raise GoldenAssertionError.new(
          actual: actual,
          expected: u.value.expected.join(" or ")
        )
      end
    when "reserialize_value"
      reserialize_value_and_verify(u.value)
    when "reserialize_large_string"
      reserialize_large_string_and_verify(u.value)
    when "reserialize_large_array"
      reserialize_large_array_and_verify(u.value)
    when "enum_a_from_json_is_constant"
      json_code = evaluate_string(u.value.actual)
      val =
        if u.value.keep_unrecognized
          from_json_keep_unrecognized(EnumA.serializer, json_code)
        else
          from_json_drop_unrecognized(EnumA.serializer, json_code)
        end
      if val.union.kind != "A"
        raise GoldenAssertionError.new(
          actual: val.union.kind,
          expected: "A",
          message: "Expected EnumA from JSON to be constant A, but got kind=#{val.union.kind}"
        )
      end
    when "enum_a_from_bytes_is_constant"
      data = evaluate_bytes(u.value.actual)
      val =
        if u.value.keep_unrecognized
          from_bytes_keep_unrecognized(EnumA.serializer, data)
        else
          from_bytes_drop_unrecognized(EnumA.serializer, data)
        end
      if val.union.kind != "A"
        raise GoldenAssertionError.new(
          actual: val.union.kind,
          expected: "A",
          message: "Expected EnumA from bytes to be constant A, but got kind=#{val.union.kind}"
        )
      end
    when "enum_b_from_json_is_wrapper_b"
      json_code = evaluate_string(u.value.actual)
      val =
        if u.value.keep_unrecognized
          from_json_keep_unrecognized(EnumB.serializer, json_code)
        else
          from_json_drop_unrecognized(EnumB.serializer, json_code)
        end
      if val.union.kind != "b"
        raise GoldenAssertionError.new(
          actual: val.union.kind,
          expected: "b",
          message: "Expected EnumB from JSON to be wrapper b, but got kind=#{val.union.kind}"
        )
      end
      if val.union.value != u.value.expected
        raise GoldenAssertionError.new(
          actual: val.union.value,
          expected: u.value.expected,
          message: "Expected EnumB.b from JSON to wrap #{u.value.expected.inspect}, but got #{val.union.value.inspect}"
        )
      end
    when "enum_b_from_bytes_is_wrapper_b"
      data = evaluate_bytes(u.value.actual)
      val =
        if u.value.keep_unrecognized
          from_bytes_keep_unrecognized(EnumB.serializer, data)
        else
          from_bytes_drop_unrecognized(EnumB.serializer, data)
        end
      if val.union.kind != "b"
        raise GoldenAssertionError.new(
          actual: val.union.kind,
          expected: "b",
          message: "Expected EnumB from bytes to be wrapper b, but got kind=#{val.union.kind}"
        )
      end
      if val.union.value != u.value.expected
        raise GoldenAssertionError.new(
          actual: val.union.value,
          expected: u.value.expected,
          message: "Expected EnumB.b from bytes to wrap #{u.value.expected.inspect}, but got #{val.union.value.inspect}"
        )
      end
    else
      raise "Unhandled assertion kind: #{u.kind}"
    end
  end

  def reserialize_value_and_verify(input_value)
    typed_values = [
      input_value.value,
      TypedValue.wrap_round_trip_dense_json(input_value.value),
      TypedValue.wrap_round_trip_readable_json(input_value.value),
      TypedValue.wrap_round_trip_bytes(input_value.value)
    ]
    typed_values.each do |typed_value_input|
      verify_assertion(
        Assertion.create_bytes_in(
          actual: BytesExpression.wrap_to_bytes(typed_value_input),
          expected: input_value.expected_bytes
        )
      )
      verify_assertion(
        Assertion.create_string_in(
          actual: StringExpression.wrap_to_dense_json(typed_value_input),
          expected: input_value.expected_dense_json
        )
      )
      verify_assertion(
        Assertion.create_string_in(
          actual: StringExpression.wrap_to_readable_json(typed_value_input),
          expected: input_value.expected_readable_json
        )
      )
    rescue GoldenAssertionError => e
      e.add_context("input value: #{typed_value_input}")
      raise e
    end

    # Make sure the encoded value can be skipped.
    input_value.expected_bytes.each do |expected_bytes|
      prefix = "skir".b
      payload = expected_bytes.byteslice(prefix.bytesize..) || "".b
      buf = +"skir".b
      buf << 248
      buf << payload
      buf << 1
      point = Point.serializer.from_bytes(buf)
      if point.x != 1
        raise GoldenAssertionError.new(
          message: "Failed to skip value: got point.x=#{point.x}, expected 1; input: #{input_value}"
        )
      end
    end

    typed_value = evaluate_typed_value(input_value.value)
    input_value.alternative_jsons.each do |alt_json|
      round_trip_json = to_dense_json(
        typed_value.serializer,
        from_json_keep_unrecognized(typed_value.serializer, evaluate_string(alt_json))
      )
      verify_assertion(
        Assertion.create_string_in(
          actual: StringExpression.wrap_literal(round_trip_json),
          expected: input_value.expected_dense_json
        )
      )
    rescue GoldenAssertionError => e
      e.add_context("while processing alternative JSON: #{evaluate_string(alt_json)}")
      raise e
    end

    (input_value.expected_dense_json + input_value.expected_readable_json).each do |alt_json|
      round_trip_json = to_dense_json(
        typed_value.serializer,
        from_json_keep_unrecognized(typed_value.serializer, alt_json)
      )
      verify_assertion(
        Assertion.create_string_in(
          actual: StringExpression.wrap_literal(round_trip_json),
          expected: input_value.expected_dense_json
        )
      )
    rescue GoldenAssertionError => e
      e.add_context("while processing alternative JSON: #{alt_json}")
      raise e
    end

    input_value.alternative_bytes.each do |alt_bytes|
      round_trip_bytes = to_bytes(
        typed_value.serializer,
        from_bytes_drop_unrecognized(typed_value.serializer, evaluate_bytes(alt_bytes))
      )
      verify_assertion(
        Assertion.create_bytes_in(
          actual: BytesExpression.wrap_literal(round_trip_bytes),
          expected: input_value.expected_bytes
        )
      )
    rescue GoldenAssertionError => e
      e.add_context("while processing alternative bytes: #{evaluate_bytes(alt_bytes).unpack1('H*')}")
      raise e
    end

    input_value.expected_bytes.each do |alt_bytes|
      round_trip_bytes = to_bytes(
        typed_value.serializer,
        from_bytes_drop_unrecognized(typed_value.serializer, alt_bytes)
      )
      verify_assertion(
        Assertion.create_bytes_in(
          actual: BytesExpression.wrap_literal(round_trip_bytes),
          expected: input_value.expected_bytes
        )
      )
    rescue GoldenAssertionError => e
      e.add_context("while processing alternative bytes: #{alt_bytes.unpack1('H*')}")
      raise e
    end

    if input_value.expected_type_descriptor
      actual = typed_value.serializer.type_descriptor.as_json_code
      verify_assertion(
        Assertion.create_string_equal(
          actual: StringExpression.wrap_literal(actual),
          expected: StringExpression.wrap_literal(input_value.expected_type_descriptor)
        )
      )
      verify_assertion(
        Assertion.create_string_equal(
          actual: StringExpression.wrap_literal(
            Skir::Reflection::TypeDescriptor.from_json_code(actual).as_json_code
          ),
          expected: StringExpression.wrap_literal(actual)
        )
      )
    end
  end

  def reserialize_large_string_and_verify(input_value)
    str = "a" * input_value.num_chars
    str_ser = Skir.primitive_serializer("string")

    json_dense = to_dense_json(str_ser, str)
    round_trip = from_json_drop_unrecognized(str_ser, json_dense)
    raise GoldenAssertionError.new(actual: round_trip, expected: str) if round_trip != str

    json_readable = to_readable_json(str_ser, str)
    round_trip = from_json_drop_unrecognized(str_ser, json_readable)
    raise GoldenAssertionError.new(actual: round_trip, expected: str) if round_trip != str

    byte_data = to_bytes(str_ser, str)
    prefix_hex = input_value.expected_byte_prefix.unpack1("H*")
    unless byte_data.unpack1("H*").start_with?(prefix_hex)
      raise GoldenAssertionError.new(
        actual: "hex:#{byte_data.unpack1('H*')}",
        expected: "hex:#{prefix_hex}..."
      )
    end
    round_trip = from_bytes_drop_unrecognized(str_ser, byte_data)
    raise GoldenAssertionError.new(actual: round_trip, expected: str) if round_trip != str
  end

  def reserialize_large_array_and_verify(input_value)
    arr = Array.new(input_value.num_items, 1)
    ser = Skir.array_serializer(Skir.primitive_serializer("int32"))

    json_dense = to_dense_json(ser, arr)
    round_trip = from_json_drop_unrecognized(ser, json_dense)
    unless round_trip.length == input_value.num_items && round_trip.all? { |v| v == 1 }
      raise GoldenAssertionError.new(actual: round_trip, expected: arr)
    end

    json_readable = to_readable_json(ser, arr)
    round_trip = from_json_drop_unrecognized(ser, json_readable)
    unless round_trip.length == input_value.num_items && round_trip.all? { |v| v == 1 }
      raise GoldenAssertionError.new(actual: round_trip, expected: arr)
    end

    byte_data = to_bytes(ser, arr)
    prefix_hex = input_value.expected_byte_prefix.unpack1("H*")
    unless byte_data.unpack1("H*").start_with?(prefix_hex)
      raise GoldenAssertionError.new(
        actual: "hex:#{byte_data.unpack1('H*')}",
        expected: "hex:#{prefix_hex}..."
      )
    end
    round_trip = from_bytes_drop_unrecognized(ser, byte_data)
    unless round_trip.length == input_value.num_items && round_trip.all? { |v| v == 1 }
      raise GoldenAssertionError.new(actual: round_trip, expected: arr)
    end
  end

  def evaluate_bytes(expr)
    u = expr.union
    case u.kind
    when "literal"
      u.value
    when "to_bytes"
      lit = evaluate_typed_value(u.value)
      to_bytes(lit.serializer, lit.value)
    else
      raise "Unexpected BytesExpression kind: #{u.kind}"
    end
  end

  def evaluate_string(expr)
    u = expr.union
    case u.kind
    when "literal"
      u.value
    when "to_dense_json"
      lit = evaluate_typed_value(u.value)
      to_dense_json(lit.serializer, lit.value)
    when "to_readable_json"
      lit = evaluate_typed_value(u.value)
      to_readable_json(lit.serializer, lit.value)
    else
      raise "Unexpected StringExpression kind: #{u.kind}"
    end
  end

  def evaluate_typed_value(literal)
    u = literal.union
    case u.kind
    when "bool"
      TypedValueType.new(value: u.value, serializer: Skir.primitive_serializer("bool"))
    when "int32"
      TypedValueType.new(value: u.value, serializer: Skir.primitive_serializer("int32"))
    when "int64"
      TypedValueType.new(value: u.value, serializer: Skir.primitive_serializer("int64"))
    when "hash64"
      TypedValueType.new(value: u.value, serializer: Skir.primitive_serializer("hash64"))
    when "float32"
      TypedValueType.new(value: u.value, serializer: Skir.primitive_serializer("float32"))
    when "float64"
      TypedValueType.new(value: u.value, serializer: Skir.primitive_serializer("float64"))
    when "timestamp"
      TypedValueType.new(value: u.value, serializer: Skir.primitive_serializer("timestamp"))
    when "string"
      TypedValueType.new(value: u.value, serializer: Skir.primitive_serializer("string"))
    when "bytes"
      TypedValueType.new(value: u.value, serializer: Skir.primitive_serializer("bytes"))
    when "bool_optional"
      TypedValueType.new(value: u.value, serializer: Skir.optional_serializer(Skir.primitive_serializer("bool")))
    when "ints"
      TypedValueType.new(value: u.value, serializer: Skir.array_serializer(Skir.primitive_serializer("int32")))
    when "point"
      TypedValueType.new(value: u.value, serializer: Point.serializer)
    when "color"
      TypedValueType.new(value: u.value, serializer: Color.serializer)
    when "my_enum"
      TypedValueType.new(value: u.value, serializer: MyEnum.serializer)
    when "keyed_arrays"
      TypedValueType.new(value: u.value, serializer: KeyedArrays.serializer)
    when "rec_struct"
      TypedValueType.new(value: u.value, serializer: RecStruct.serializer)
    when "rec_enum"
      TypedValueType.new(value: u.value, serializer: RecEnum.serializer)
    when "round_trip_dense_json"
      other = evaluate_typed_value(u.value)
      TypedValueType.new(
        value: from_json_drop_unrecognized(other.serializer, to_dense_json(other.serializer, other.value)),
        serializer: other.serializer
      )
    when "round_trip_readable_json"
      other = evaluate_typed_value(u.value)
      TypedValueType.new(
        value: from_json_drop_unrecognized(other.serializer, to_readable_json(other.serializer, other.value)),
        serializer: other.serializer
      )
    when "round_trip_bytes"
      other = evaluate_typed_value(u.value)
      TypedValueType.new(
        value: from_bytes_drop_unrecognized(other.serializer, to_bytes(other.serializer, other.value)),
        serializer: other.serializer
      )
    when "point_from_json_keep_unrecognized"
      TypedValueType.new(
        value: from_json_keep_unrecognized(Point.serializer, evaluate_string(u.value)),
        serializer: Point.serializer
      )
    when "point_from_json_drop_unrecognized"
      TypedValueType.new(
        value: from_json_drop_unrecognized(Point.serializer, evaluate_string(u.value)),
        serializer: Point.serializer
      )
    when "point_from_bytes_keep_unrecognized"
      TypedValueType.new(
        value: from_bytes_keep_unrecognized(Point.serializer, evaluate_bytes(u.value)),
        serializer: Point.serializer
      )
    when "point_from_bytes_drop_unrecognized"
      TypedValueType.new(
        value: from_bytes_drop_unrecognized(Point.serializer, evaluate_bytes(u.value)),
        serializer: Point.serializer
      )
    when "color_from_json_keep_unrecognized"
      TypedValueType.new(
        value: from_json_keep_unrecognized(Color.serializer, evaluate_string(u.value)),
        serializer: Color.serializer
      )
    when "color_from_json_drop_unrecognized"
      TypedValueType.new(
        value: from_json_drop_unrecognized(Color.serializer, evaluate_string(u.value)),
        serializer: Color.serializer
      )
    when "color_from_bytes_keep_unrecognized"
      TypedValueType.new(
        value: from_bytes_keep_unrecognized(Color.serializer, evaluate_bytes(u.value)),
        serializer: Color.serializer
      )
    when "color_from_bytes_drop_unrecognized"
      TypedValueType.new(
        value: from_bytes_drop_unrecognized(Color.serializer, evaluate_bytes(u.value)),
        serializer: Color.serializer
      )
    when "my_enum_from_json_keep_unrecognized"
      TypedValueType.new(
        value: from_json_keep_unrecognized(MyEnum.serializer, evaluate_string(u.value)),
        serializer: MyEnum.serializer
      )
    when "my_enum_from_json_drop_unrecognized"
      TypedValueType.new(
        value: from_json_drop_unrecognized(MyEnum.serializer, evaluate_string(u.value)),
        serializer: MyEnum.serializer
      )
    when "my_enum_from_bytes_keep_unrecognized"
      TypedValueType.new(
        value: from_bytes_keep_unrecognized(MyEnum.serializer, evaluate_bytes(u.value)),
        serializer: MyEnum.serializer
      )
    when "my_enum_from_bytes_drop_unrecognized"
      TypedValueType.new(
        value: from_bytes_drop_unrecognized(MyEnum.serializer, evaluate_bytes(u.value)),
        serializer: MyEnum.serializer
      )
    when "enum_a"
      TypedValueType.new(value: u.value, serializer: EnumA.serializer)
    when "enum_b"
      TypedValueType.new(value: u.value, serializer: EnumB.serializer)
    when "enum_a_from_json_keep_unrecognized"
      TypedValueType.new(
        value: from_json_keep_unrecognized(EnumA.serializer, evaluate_string(u.value)),
        serializer: EnumA.serializer
      )
    when "enum_a_from_json_drop_unrecognized"
      TypedValueType.new(
        value: from_json_drop_unrecognized(EnumA.serializer, evaluate_string(u.value)),
        serializer: EnumA.serializer
      )
    when "enum_a_from_bytes_keep_unrecognized"
      TypedValueType.new(
        value: from_bytes_keep_unrecognized(EnumA.serializer, evaluate_bytes(u.value)),
        serializer: EnumA.serializer
      )
    when "enum_a_from_bytes_drop_unrecognized"
      TypedValueType.new(
        value: from_bytes_drop_unrecognized(EnumA.serializer, evaluate_bytes(u.value)),
        serializer: EnumA.serializer
      )
    when "enum_b_from_json_keep_unrecognized"
      TypedValueType.new(
        value: from_json_keep_unrecognized(EnumB.serializer, evaluate_string(u.value)),
        serializer: EnumB.serializer
      )
    when "enum_b_from_json_drop_unrecognized"
      TypedValueType.new(
        value: from_json_drop_unrecognized(EnumB.serializer, evaluate_string(u.value)),
        serializer: EnumB.serializer
      )
    when "enum_b_from_bytes_keep_unrecognized"
      TypedValueType.new(
        value: from_bytes_keep_unrecognized(EnumB.serializer, evaluate_bytes(u.value)),
        serializer: EnumB.serializer
      )
    when "enum_b_from_bytes_drop_unrecognized"
      TypedValueType.new(
        value: from_bytes_drop_unrecognized(EnumB.serializer, evaluate_bytes(u.value)),
        serializer: EnumB.serializer
      )
    else
      raise "Unexpected TypedValue kind: #{u.kind}"
    end
  end

  def to_dense_json(serializer, input)
    serializer.to_json_code(input)
  rescue StandardError => e
    raise GoldenAssertionError.new(message: "Failed to serialize #{input} to dense JSON: #{e}")
  end

  def to_readable_json(serializer, input)
    serializer.to_json_code(input, readable: true)
  rescue StandardError => e
    raise GoldenAssertionError.new(message: "Failed to serialize #{input} to readable JSON: #{e}")
  end

  def to_bytes(serializer, input)
    serializer.to_bytes(input)
  rescue StandardError => e
    raise GoldenAssertionError.new(message: "Failed to serialize #{input} to bytes: #{e}")
  end

  def from_json_keep_unrecognized(serializer, json_code)
    serializer.from_json_code(json_code, keep_unrecognized_values: true)
  rescue StandardError => e
    raise GoldenAssertionError.new(message: "Failed to deserialize #{json_code}: #{e}")
  end

  def from_json_drop_unrecognized(serializer, json_code)
    serializer.from_json_code(json_code)
  rescue StandardError => e
    raise GoldenAssertionError.new(message: "Failed to deserialize #{json_code}: #{e}")
  end

  def from_bytes_drop_unrecognized(serializer, data)
    serializer.from_bytes(data)
  rescue StandardError => e
    raise GoldenAssertionError.new(message: "Failed to deserialize #{data.unpack1('H*')}: #{e}")
  end

  def from_bytes_keep_unrecognized(serializer, data)
    serializer.from_bytes(data, keep_unrecognized_values: true)
  rescue StandardError => e
    raise GoldenAssertionError.new(message: "Failed to deserialize #{data.unpack1('H*')}: #{e}")
  end
end
