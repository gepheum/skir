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
    assert_equal(-3, i32_ser.from_json_code("-3.14"))

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

    h64_ser = Skir.primitive_serializer("hash64")
    assert_equal "2147483648", h64_ser.to_json_code(2_147_483_648)
    assert_equal "0", h64_ser.to_json_code(-1)
    assert_equal "9007199254740991", h64_ser.to_json_code(9_007_199_254_740_991)
    assert_equal '"9007199254740992"', h64_ser.to_json_code(9_007_199_254_740_992)
    assert_equal 0, h64_ser.from_json_code("0")
    assert_equal 7, h64_ser.from_json_code('"7"')
    assert_equal 3, h64_ser.from_json_code("3.14")
    assert_equal(-3, h64_ser.from_json_code("-3.14"))

    f32_ser = Skir.primitive_serializer("float32")
    assert_equal "3.14", f32_ser.to_json_code(3.14)
    assert_equal '"Infinity"', f32_ser.to_json_code(Float::INFINITY)
    assert_equal '"-Infinity"', f32_ser.to_json_code(-Float::INFINITY)
    assert_equal '"NaN"', f32_ser.to_json_code(Float::NAN)
    assert_equal 3.14, f32_ser.from_json_code("3.14")
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
end
