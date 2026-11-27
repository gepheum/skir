# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "skir"

class SerializersTest < Minitest::Test
  def test_primitive_serializers
    bool_ser = Skir.primitive_serializer("bool")
    assert_equal "1", bool_ser.to_json_code(true)
    assert_equal "true", bool_ser.to_json_code(true, readable: true)
    assert_equal true, bool_ser.from_json_code("true")
    assert_equal false, bool_ser.from_json_code("false")
    assert_equal false, bool_ser.from_json_code("0")
    assert_equal false, bool_ser.from_json_code('"0"')
    assert_equal true, bool_ser.from_json_code("1")
    assert_equal true, bool_ser.from_json_code('"1"')

    i32_ser = Skir.primitive_serializer("int32")
    assert_equal "7", i32_ser.to_json_code(7)
    assert_equal "7", i32_ser.to_json_code(7, readable: true)
    assert_equal "2147483647", i32_ser.to_json_code(2_147_483_648)
    assert_equal "-2147483648", i32_ser.to_json_code(-2_147_483_649)
    assert_equal 0, i32_ser.from_json_code("0")
    assert_equal 7, i32_ser.from_json_code('"7"')
    assert_equal 3, i32_ser.from_json_code("3.14")
    assert_equal 3, i32_ser.from_json_code('"3.14"')
    assert_equal(-3, i32_ser.from_json_code("-3.14"))
    assert_equal 2_147_483_647, i32_ser.from_json_code("2147483648")
    assert_equal(-2_147_483_648, i32_ser.from_json_code("-2147483649"))

    i64_ser = Skir.primitive_serializer("int64")
    assert_equal "2147483648", i64_ser.to_json_code(2_147_483_648)
    assert_equal "9007199254740991", i64_ser.to_json_code(9_007_199_254_740_991)
    assert_equal '"9007199254740992"', i64_ser.to_json_code(9_007_199_254_740_992)
    assert_equal '"9223372036854775807"', i64_ser.to_json_code(9_223_372_036_854_775_808)
    assert_equal "-9007199254740991", i64_ser.to_json_code(-9_007_199_254_740_991)
    assert_equal '"-9007199254740992"', i64_ser.to_json_code(-9_007_199_254_740_992)
    assert_equal '"-9223372036854775808"', i64_ser.to_json_code(-9_223_372_036_854_775_809)
    assert_equal 0, i64_ser.from_json_code("0")
    assert_equal 7, i64_ser.from_json_code('"7"')
    assert_equal 3, i64_ser.from_json_code("3.14")
    assert_equal(-3, i64_ser.from_json_code("-3.14"))
    assert_equal 9_223_372_036_854_775_807, i64_ser.from_json_code('"9223372036854775808"')
    assert_equal(-9_223_372_036_854_775_808, i64_ser.from_json_code('"-9223372036854775809"'))

    h64_ser = Skir.primitive_serializer("hash64")
    assert_equal "2147483648", h64_ser.to_json_code(2_147_483_648)
    assert_equal "0", h64_ser.to_json_code(-1)
    assert_equal "9007199254740991", h64_ser.to_json_code(9_007_199_254_740_991)
    assert_equal '"9007199254740992"', h64_ser.to_json_code(9_007_199_254_740_992)
    assert_equal 0, h64_ser.from_json_code("0")
    assert_equal 7, h64_ser.from_json_code('"7"')
    assert_equal 3, h64_ser.from_json_code("3.14")
    assert_equal 0, h64_ser.from_json_code("-3.14")
    assert_equal 18_446_744_073_709_551_615, h64_ser.from_json_code('"18446744073709551616"')

    f32_ser = Skir.primitive_serializer("float32")
    assert_equal "3.14", f32_ser.to_json_code(3.14)
    assert_equal '"Infinity"', f32_ser.to_json_code(Float::INFINITY)
    assert_equal '"-Infinity"', f32_ser.to_json_code(-Float::INFINITY)
    assert_equal '"NaN"', f32_ser.to_json_code(Float::NAN)
    assert_equal 3.14, f32_ser.from_json_code("3.14")
    assert_equal 3.14, f32_ser.from_json_code('"3.14"')
    assert_equal Float::INFINITY, f32_ser.from_json_code('"Infinity"')
    assert_equal(-Float::INFINITY, f32_ser.from_json_code('"-Infinity"'))
    assert_predicate f32_ser.from_json_code('"NaN"'), :nan?

    f64_ser = Skir.primitive_serializer("float64")
    assert_equal "3.14", f64_ser.to_json_code(3.14)
    assert_equal "3.14", f64_ser.to_json_code(3.14, readable: true)

    ts_ser = Skir.primitive_serializer("timestamp")
    t_3ms = Time.at(Rational(3, 1000)).utc
    assert_equal "3", ts_ser.to_json_code(t_3ms)
    assert_equal(
      "{\n  \"unix_millis\": 3,\n  \"formatted\": \"1970-01-01T00:00:00.003Z\"\n}",
      ts_ser.to_json_code(t_3ms, readable: true)
    )
    deserialized_from_int = ts_ser.from_json_code("3")
    assert_equal t_3ms, deserialized_from_int
    assert_predicate deserialized_from_int, :utc?
    assert_predicate deserialized_from_int, :frozen?

    deserialized_from_obj = ts_ser.from_json_code('{"unix_millis": 3, "formatted": "FOO", "bar": true}')
    assert_equal t_3ms, deserialized_from_obj
    assert_predicate deserialized_from_obj, :utc?
    assert_predicate deserialized_from_obj, :frozen?

    # Non-UTC Time serializes as the exact same instant and deserializes in UTC
    non_utc = Time.new(2025, 1, 2, 12, 0, 0, "+02:00")
    roundtripped = ts_ser.from_json(ts_ser.to_json(non_utc))
    assert_equal non_utc, roundtripped
    assert_predicate roundtripped, :utc?
    assert_predicate roundtripped, :frozen?
  end

  def test_array_serializer
    arr_ser = Skir.array_serializer(Skir.primitive_serializer("bool"))
    assert_equal "[1,0]", arr_ser.to_json_code([true, false])
    assert_equal "[\n  true,\n  false\n]", arr_ser.to_json_code([true, false], readable: true)
    assert_equal [true, false], arr_ser.from_json_code("[ true, false ]")
    assert_equal [], arr_ser.from_json_code("0")
  end

  def test_optional_serializer
    opt_ser = Skir.optional_serializer(Skir.primitive_serializer("bool"))
    assert_equal "1", opt_ser.to_json_code(true)
    assert_equal "true", opt_ser.to_json_code(true, readable: true)
    assert_equal "null", opt_ser.to_json_code(nil)
    assert_nil opt_ser.from_json_code("null")
  end

  def test_bool_binary_serialization
    bool_ser = Skir.primitive_serializer("bool")
    true_bytes = bool_ser.to_bytes(true)
    assert_equal "736b697201", true_bytes.unpack1("H*")
    assert_equal true, bool_ser.from_bytes(true_bytes)

    false_bytes = bool_ser.to_bytes(false)
    assert_equal "736b697200", false_bytes.unpack1("H*")
    assert_equal false, bool_ser.from_bytes(false_bytes)
  end

  def test_int32_binary_encoding_specifics
    i32_ser = Skir.primitive_serializer("int32")
    test_cases = {
      0 => "736b697200",
      1 => "736b697201",
      231 => "736b6972e7",
      232 => "736b6972e8e800",
      257 => "736b6972e80101",
      65_535 => "736b6972e8ffff",
      65_536 => "736b6972e900000100",
      -1 => "736b6972ebff",
      -256 => "736b6972eb00",
      -257 => "736b6972ecfffe"
    }
    test_cases.each do |val, expected_hex|
      bytes = i32_ser.to_bytes(val)
      assert_equal expected_hex, bytes.unpack1("H*")
      assert_equal val, i32_ser.from_bytes(bytes)
    end
  end

  def test_int64_and_hash64_binary
    i64_ser = Skir.primitive_serializer("int64")
    [0, 1, -1, 42, -42, 9_223_372_036_854_775_807, -9_223_372_036_854_775_808].each do |val|
      assert_equal val, i64_ser.from_bytes(i64_ser.to_bytes(val))
    end

    h64_ser = Skir.primitive_serializer("hash64")
    [0, 1, 42, 18_446_744_073_709_551_615].each do |val|
      assert_equal val, h64_ser.from_bytes(h64_ser.to_bytes(val))
    end
  end

  def test_floats_binary
    f32_ser = Skir.primitive_serializer("float32")
    [0.0, 1.0, -1.0, 3.14].each do |val|
      assert_in_delta val, f32_ser.from_bytes(f32_ser.to_bytes(val)), 1e-5
    end
    assert_equal Float::INFINITY, f32_ser.from_bytes(f32_ser.to_bytes(Float::INFINITY))
    assert_equal(-Float::INFINITY, f32_ser.from_bytes(f32_ser.to_bytes(-Float::INFINITY)))
    assert_predicate f32_ser.from_bytes(f32_ser.to_bytes(Float::NAN)), :nan?

    f64_ser = Skir.primitive_serializer("float64")
    [0.0, 1.0, -1.0, 3.14159265359].each do |val|
      assert_in_delta val, f64_ser.from_bytes(f64_ser.to_bytes(val)), 1e-10
    end
    assert_equal Float::INFINITY, f64_ser.from_bytes(f64_ser.to_bytes(Float::INFINITY))
    assert_equal(-Float::INFINITY, f64_ser.from_bytes(f64_ser.to_bytes(-Float::INFINITY)))
    assert_predicate f64_ser.from_bytes(f64_ser.to_bytes(Float::NAN)), :nan?
  end

  def test_string_binary
    str_ser = Skir.primitive_serializer("string")
    test_cases = {
      "" => "736b6972f2",
      "0" => "736b6972f30130",
      "A" => "736b6972f30141",
      "🚀" => "736b6972f304f09f9a80",
      "\u0000" => "736b6972f30100",
      "Hello\nWorld" => "736b6972f30b48656c6c6f0a576f726c64"
    }
    test_cases.each do |val, expected_hex|
      bytes = str_ser.to_bytes(val)
      assert_equal expected_hex, bytes.unpack1("H*")
      assert_equal val, str_ser.from_bytes(bytes)
    end

    invalid_bytes = ["736b6972f302ff7a"].pack("H*")
    assert_equal "\uFFFDz", str_ser.from_bytes(invalid_bytes)
  end

  def test_bytes_and_timestamp_binary
    bytes_ser = Skir.primitive_serializer("bytes")
    ["".b, "hello".b, "Hello, 世界!".b].each do |val|
      assert_equal val, bytes_ser.from_bytes(bytes_ser.to_bytes(val))
    end

    ts_ser = Skir.primitive_serializer("timestamp")
    test_cases = {
      Time.at(0).utc => "736b697200",
      Time.at(1).utc => "736b6972efe803000000000000",
      Time.at(-1).utc => "736b6972ef18fcffffffffffff"
    }
    test_cases.each do |instant, expected_hex|
      bytes = ts_ser.to_bytes(instant)
      assert_equal expected_hex, bytes.unpack1("H*")
      decoded = ts_ser.from_bytes(bytes)
      assert_equal instant, decoded
      assert_predicate decoded, :utc?
      assert_predicate decoded, :frozen?
    end
  end

  def test_optional_and_list_binary
    int_opt = Skir.optional_serializer(Skir.primitive_serializer("int32"))
    {
      nil => "736b6972ff",
      0 => "736b697200",
      42 => "736b69722a",
      -1 => "736b6972ebff"
    }.each do |val, expected_hex|
      bytes = int_opt.to_bytes(val)
      assert_equal expected_hex, bytes.unpack1("H*")
      if val.nil?
        assert_nil int_opt.from_bytes(bytes)
      else
        assert_equal val, int_opt.from_bytes(bytes)
      end
    end

    int_arr = Skir.array_serializer(Skir.primitive_serializer("int32"))
    {
      [] => "736b6972f6",
      [1] => "736b6972f701",
      [1, 2] => "736b6972f80102",
      [1, 2, 3] => "736b6972f9010203"
    }.each do |arr, expected_hex|
      bytes = int_arr.to_bytes(arr)
      assert_equal expected_hex, bytes.unpack1("H*")
      assert_equal arr, int_arr.from_bytes(bytes)
    end

    large_arr = (1..100).to_a
    large_bytes = int_arr.to_bytes(large_arr)
    assert_operator large_bytes.unpack1("H*"), :start_with?, "736b6972fa"
    assert_equal large_arr, int_arr.from_bytes(large_bytes)
  end

  private

  def binary(*bytes)
    ("skir".b + bytes.pack("C*")).freeze
  end

  def assert_reserialize(serializer, input, dense_json:, bytes_hex:, readable_json: nil, dense_json_from_reserialized: nil)
    readable_json = dense_json if readable_json.nil?
    dense_json_from_reserialized = dense_json if dense_json_from_reserialized.nil?

    [false, true].each do |readable|
      expected_json = readable ? readable_json : dense_json
      actual_json = serializer.to_json(input, readable: readable)
      if expected_json.is_a?(Float) && expected_json.nan?
        assert_predicate actual_json, :nan?
      else
        assert_equal expected_json, actual_json
      end

      reserialized = serializer.from_json(actual_json, keep_unrecognized_values: true)
      assert_equal expected_json, serializer.to_json(reserialized, readable: readable)

      json_code = serializer.to_json_code(input, readable: readable)
      reserialized_from_code = serializer.from_json_code(json_code, keep_unrecognized_values: true)
      assert_equal expected_json, serializer.to_json(reserialized_from_code, readable: readable)
    end

    actual_bytes = serializer.to_bytes(input)
    assert_equal "736b6972#{bytes_hex}", actual_bytes.unpack1("H*")

    reserialized_from_bytes = serializer.from_bytes(actual_bytes, keep_unrecognized_values: true)
    assert_equal "736b6972#{bytes_hex}", serializer.to_bytes(reserialized_from_bytes).unpack1("H*")
    assert_equal dense_json_from_reserialized, serializer.to_json(reserialized_from_bytes, readable: false)
  end

  def define_test_struct(fields_map)
    mod = Module.new
    fields = fields_map.each_with_index.map do |(name, type), idx|
      Skir::Spec::Field.new(name: name.to_s, number: idx, type: type)
    end
    struct_spec = Skir::Spec::Struct.new(
      id: "test.skir:TestRecord#{fields_map.object_id}",
      class_name: "TestRecord",
      class_qualname: "TestRecord",
      fields: fields
    )
    Skir::Internal.init_module(records: [struct_spec], methods: [], constants: [], target: mod)
    mod.const_get(:TestRecord)
  end

  public

  def test_primitive_type_descriptors
    %w[bool int32 int64 hash64 float32 float64 timestamp string bytes].each do |primitive|
      ser = Skir.primitive_serializer(primitive)
      td = ser.type_descriptor
      assert_equal(
        {
          "type" => { "kind" => "primitive", "value" => primitive },
          "records" => []
        },
        td.as_json
      )
      reparsed = Skir::Reflection::TypeDescriptor.from_json(td.as_json)
      assert_equal td.as_json, reparsed.as_json
      assert_equal td, reparsed
    end
  end

  def test_bool_serializer_parity
    ser = Skir.primitive_serializer("bool")
    assert_equal true, ser.from_json_code("888888")
    assert_equal false, ser.from_json_code('"0"')
    assert_equal true, ser.from_bytes(Skir.primitive_serializer("int32").to_bytes(888_888))

    assert_reserialize(ser, true, dense_json: 1, readable_json: true, bytes_hex: "01")
    assert_reserialize(ser, false, dense_json: 0, readable_json: false, bytes_hex: "00")
    assert_equal false, ser.from_json(0)
    assert_equal false, ser.from_bytes(binary(0))
  end

  def test_int32_serializer_parity
    ser = Skir.primitive_serializer("int32")
    assert_raises(StandardError) { ser.from_bytes([0, 0, 0, 0, 1].pack("C*")) }
    assert_raises(StandardError) { ser.from_bytes(binary(1, 2)) }

    assert_reserialize(ser, 2, dense_json: 2, bytes_hex: "02")
    assert_reserialize(ser, 0, dense_json: 0, bytes_hex: "00")
    assert_reserialize(ser, -1, dense_json: -1, bytes_hex: "ebff")
    assert_reserialize(ser, 2.8, dense_json: 2, bytes_hex: "02")
    assert_reserialize(ser, -3.8, dense_json: -3, bytes_hex: "ebfd")
    assert_reserialize(ser, 231, dense_json: 231, bytes_hex: "e7")
    assert_reserialize(ser, 232, dense_json: 232, bytes_hex: "e8e800")
    assert_reserialize(ser, 65_535, dense_json: 65_535, bytes_hex: "e8ffff")
    assert_reserialize(ser, 65_536, dense_json: 65_536, bytes_hex: "e900000100")
    assert_reserialize(ser, 2_147_483_647, dense_json: 2_147_483_647, bytes_hex: "e9ffffff7f")
    assert_reserialize(ser, -255, dense_json: -255, bytes_hex: "eb01")
    assert_reserialize(ser, -256, dense_json: -256, bytes_hex: "eb00")
    assert_reserialize(ser, -257, dense_json: -257, bytes_hex: "ecfffe")
    assert_reserialize(ser, -65_536, dense_json: -65_536, bytes_hex: "ec0000")
    assert_reserialize(ser, -65_537, dense_json: -65_537, bytes_hex: "edfffffeff")
    assert_reserialize(ser, -2_147_483_648, dense_json: -2_147_483_648, bytes_hex: "ed00000080")

    assert_equal 0, ser.from_json("0")
    assert_equal 2, ser.from_json("2.3")
    assert_equal 0, ser.from_json("NaN")
    assert_equal 0, ser.from_json("Infinity")
    assert_equal 0, ser.from_json("-Infinity")
    assert_equal 0, ser.from_json(false)
    assert_equal 1, ser.from_json(true)
    assert_equal 2_147_483_647, ser.from_json(2_147_483_648)
    assert_equal(-2_147_483_648, ser.from_json(-2_147_483_649))
    assert_equal 2_147_483_647, ser.from_bytes(Skir.primitive_serializer("int64").to_bytes(2_147_483_648))
  end

  def test_int64_serializer_parity
    ser = Skir.primitive_serializer("int64")
    assert_equal 3, ser.from_json(3.14)
    assert_reserialize(ser, 888_888_888_888, dense_json: 888_888_888_888, bytes_hex: "ee380ee8f5ce000000")
    assert_reserialize(ser, 9_223_372_036_854_775_808, dense_json: "9223372036854775807", bytes_hex: "eeffffffffffffff7f")
    assert_reserialize(ser, -9_223_372_036_854_775_809, dense_json: "-9223372036854775808", bytes_hex: "ee0000000000000080")
    assert_reserialize(ser, 0, dense_json: 0, bytes_hex: "00")
    assert_equal 0, ser.from_json(0)
    assert_equal 0, ser.from_bytes(binary(0))
    assert_equal 123, ser.from_json(123)
    assert_equal(-9_223_372_036_854_775_808, ser.from_json("-99999999999999999999999999"))
  end

  def test_hash64_serializer_parity
    ser = Skir.primitive_serializer("hash64")
    assert_equal 3, ser.from_json(3.14)
    assert_reserialize(ser, 888_888_888_888, dense_json: 888_888_888_888, bytes_hex: "ea380ee8f5ce000000")
    assert_reserialize(ser, 4_294_967_295, dense_json: 4_294_967_295, bytes_hex: "e9ffffffff")
    assert_reserialize(ser, 18_446_744_073_709_551_616, dense_json: "18446744073709551615", bytes_hex: "eaffffffffffffffff")
    assert_reserialize(ser, -1, dense_json: 0, bytes_hex: "00")
    assert_reserialize(ser, 0, dense_json: 0, bytes_hex: "00")
    assert_equal 0, ser.from_json(0)
    assert_equal 0, ser.from_bytes(binary(0))
    assert_equal 123, ser.from_json(123)
    assert_equal 0, ser.from_json("-99999999999999999999999999")
  end

  def test_float32_serializer_parity
    ser = Skir.primitive_serializer("float32")
    assert_equal 1_111_111_111.0, ser.from_json("1111111111")
    assert_in_delta 1.1111111111111112e39, ser.from_json("1111111111111111111111111111111111111111"), 1e25

    assert_reserialize(ser, 2, dense_json: 2.0, bytes_hex: "f000000040")
    assert_reserialize(ser, 0, dense_json: 0.0, bytes_hex: "00")
    assert_reserialize(ser, -1, dense_json: -1.0, bytes_hex: "f0000080bf")
    assert_reserialize(ser, -1.5, dense_json: -1.5, bytes_hex: "f00000c0bf")
    assert_reserialize(
      ser,
      2.8,
      dense_json: 2.8,
      bytes_hex: "f033333340",
      dense_json_from_reserialized: [2.8].pack("e").unpack1("e")
    )
    assert_reserialize(
      ser,
      -3.8,
      dense_json: -3.8,
      bytes_hex: "f0333373c0",
      dense_json_from_reserialized: [-3.8].pack("e").unpack1("e")
    )
    assert_reserialize(ser, Float::NAN, dense_json: "NaN", bytes_hex: "f00000c07f")
    assert_reserialize(ser, Float::INFINITY, dense_json: "Infinity", bytes_hex: "f00000807f")
    assert_reserialize(ser, -Float::INFINITY, dense_json: "-Infinity", bytes_hex: "f0000080ff")
    assert_equal 0.0, ser.from_json("0")
    assert_equal 2.5, ser.from_json("2.5")
  end

  def test_float64_serializer_parity
    ser = Skir.primitive_serializer("float64")
    assert_reserialize(ser, 2, dense_json: 2.0, bytes_hex: "f10000000000000040")
    assert_reserialize(ser, 0, dense_json: 0.0, bytes_hex: "00")
    assert_reserialize(ser, -1, dense_json: -1.0, bytes_hex: "f1000000000000f0bf")
    assert_reserialize(ser, 2.8, dense_json: 2.8, bytes_hex: "f16666666666660640")
    assert_reserialize(ser, -3.8, dense_json: -3.8, bytes_hex: "f16666666666660ec0")
    assert_reserialize(ser, Float::NAN, dense_json: "NaN", bytes_hex: "f1000000000000f87f")
    assert_reserialize(ser, Float::INFINITY, dense_json: "Infinity", bytes_hex: "f1000000000000f07f")
    assert_reserialize(ser, -Float::INFINITY, dense_json: "-Infinity", bytes_hex: "f1000000000000f0ff")
    assert_equal 0.0, ser.from_json("0")
    assert_equal 2.5, ser.from_json("2.5")
  end

  def test_string_serializer_parity
    ser = Skir.primitive_serializer("string")
    assert_reserialize(ser, "", dense_json: "", bytes_hex: "f2")
    assert_reserialize(ser, "Foôbar", dense_json: "Foôbar", bytes_hex: "f307466fc3b4626172")
    assert_reserialize(ser, "Foo\n\"bar\"", dense_json: "Foo\n\"bar\"", bytes_hex: "f309466f6f0a2262617222")
    assert_reserialize(
      ser,
      "é" * 5000,
      dense_json: "é" * 5000,
      bytes_hex: "f3e81027#{'c3a9' * 5000}"
    )
    assert_reserialize(
      ser,
      "\uFFFF" * 5000,
      dense_json: "\uFFFF" * 5000,
      bytes_hex: "f3e8983a#{'efbfbf' * 5000}"
    )
    assert_equal "", ser.from_json(0)
    assert_equal "", ser.from_bytes(binary(0))

    # Sanitizes invalid UTF-8 / lone UTF-8 surrogates
    bad_utf8 = ("\uFEFF😀".b + [237, 176, 128, 237, 160, 128].pack("C*") + "z".b).force_encoding(Encoding::UTF_8)
    expected = "\uFEFF😀\uFFFD\uFFFD\uFFFD\uFFFD\uFFFD\uFFFDz"
    assert_equal expected, ser.from_bytes(ser.to_bytes(bad_utf8))
    assert_equal expected, ser.to_json(bad_utf8)
    assert_equal expected, ser.from_json(bad_utf8)

    string_record = define_test_struct(text: Skir::Spec::PrimitiveType::STRING)
    [nil, false, 0].each do |invalid_val|
      assert_raises(TypeError) { string_record.serializer.to_json(string_record.new(text: invalid_val)) }
      assert_raises(TypeError) { string_record.serializer.to_json(string_record.new(text: invalid_val), readable: true) }
      assert_raises(TypeError) { string_record.serializer.to_bytes(string_record.new(text: invalid_val)) }
    end

    [nil, false].each do |invalid_json|
      assert_raises(TypeError) { string_record.serializer.from_json({ "text" => invalid_json }) }
    end

    assert_equal "\uFFFD\uFFFD\uFFFD", ser.from_bytes(binary(243, 3, 237, 160, 128))
    assert_equal "\uFFFD", string_record.serializer.from_bytes(binary(247, 243, 1, 255)).text

    [[247, 1, 65], [243, 235, 255], [243, 3, 65]].each do |payload|
      assert_raises(StandardError) { ser.from_bytes(binary(*payload)) }
    end

    [243, 245].each do |tag|
      assert_equal "", string_record.serializer.from_bytes(binary(248, 242, tag, 1, 255)).text
    end

    records_ser = Skir.array_serializer(string_record.serializer)
    [243, 245].each do |tag|
      input = binary(248, 248, 242, tag, 1, 65, 247, 243, 1, 66)
      assert_equal [[], ["B"]], records_ser.to_json(records_ser.from_bytes(input))
    end

    [243, 245].each do |tag|
      assert_raises(StandardError) do
        string_record.serializer.from_bytes(binary(248, 242, tag, 235, 255))
      end
      assert_raises(StandardError) do
        string_record.serializer.from_bytes(binary(248, 242, tag, 2, 65))
      end
    end
  end

  def test_bytes_serializer_parity
    ser = Skir.primitive_serializer("bytes")

    [122, 123, 124, 128, 130, 256, 1000].each do |len|
      raw = Array.new(len) { |i| i % 256 }.pack("C*")
      assert_equal raw, ser.from_bytes(ser.to_bytes(raw))
      arr_ser = Skir.array_serializer(ser)
      assert_equal [raw, raw], arr_ser.from_bytes(arr_ser.to_bytes([raw, raw]))
    end

    [
      binary(247, 1, 65),
      binary(245, 3, 65),
      binary(245, 235, 255),
      binary(245, 234, 0, 0, 0, 0, 0, 0, 0, 0),
      binary(245, 241, 0, 0, 0, 0, 0, 0, 248, 63)
    ].each do |invalid_bytes|
      assert_raises(StandardError) { ser.from_bytes(invalid_bytes) }
    end

    assert_reserialize(
      ser,
      Base64.decode64("abc123").b,
      dense_json: "abc12w==",
      readable_json: "hex:69b735db",
      bytes_hex: "f50469b735db"
    )
    assert_reserialize(
      ser,
      "".b,
      dense_json: "",
      readable_json: "hex:",
      bytes_hex: "f4"
    )
    assert_equal "".b, ser.from_json(0)
    assert_equal "".b, ser.from_bytes(binary(0))
  end
end
