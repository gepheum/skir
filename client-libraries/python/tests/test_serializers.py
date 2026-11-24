import unittest

from skir import Timestamp, array_serializer, optional_serializer, primitive_serializer


class SerializersTestCase(unittest.TestCase):
    def test_primitive_serializers(self):
        self.assertEqual(primitive_serializer("bool").to_json_code(True), "1")
        self.assertEqual(
            primitive_serializer("bool").to_json_code(True, readable=True),
            "true",
        )
        self.assertEqual(primitive_serializer("bool").from_json_code("true"), True)
        self.assertEqual(primitive_serializer("bool").from_json_code("false"), False)
        self.assertEqual(primitive_serializer("bool").from_json_code("0"), False)
        self.assertEqual(primitive_serializer("bool").from_json_code('"0"'), False)
        self.assertEqual(primitive_serializer("bool").from_json_code("1"), True)
        self.assertEqual(primitive_serializer("bool").from_json_code('"1"'), True)

        self.assertEqual(primitive_serializer("int32").to_json_code(7), "7")
        self.assertEqual(
            primitive_serializer("int32").to_json_code(7, readable=True), "7"
        )
        self.assertEqual(
            primitive_serializer("int32").to_json_code(2147483648), "2147483647"
        )
        self.assertEqual(
            primitive_serializer("int32").to_json_code(-2147483649), "-2147483648"
        )
        self.assertEqual(primitive_serializer("int32").from_json_code("0"), 0)
        self.assertEqual(primitive_serializer("int32").from_json_code('"7"'), 7)
        self.assertEqual(primitive_serializer("int32").from_json_code("3.14"), 3)
        self.assertEqual(primitive_serializer("int32").from_json_code("-3.14"), -3)

        self.assertEqual(
            primitive_serializer("int64").to_json_code(2147483648), "2147483648"
        )
        self.assertEqual(
            primitive_serializer("int64").to_json_code(9007199254740991),
            "9007199254740991",
        )
        self.assertEqual(
            primitive_serializer("int64").to_json_code(9007199254740992),
            '"9007199254740992"',
        )
        self.assertEqual(
            primitive_serializer("int64").to_json_code(9223372036854775808),
            '"9223372036854775807"',
        )
        self.assertEqual(
            primitive_serializer("int64").to_json_code(-9007199254740991),
            "-9007199254740991",
        )
        self.assertEqual(
            primitive_serializer("int64").to_json_code(-9007199254740992),
            '"-9007199254740992"',
        )
        self.assertEqual(
            primitive_serializer("int64").to_json_code(-9223372036854775809),
            '"-9223372036854775808"',
        )
        self.assertEqual(primitive_serializer("int64").from_json_code("0"), 0)
        self.assertEqual(primitive_serializer("int64").from_json_code('"7"'), 7)
        self.assertEqual(primitive_serializer("int64").from_json_code("3.14"), 3)
        self.assertEqual(primitive_serializer("int64").from_json_code("-3.14"), -3)

        self.assertEqual(
            primitive_serializer("hash64").to_json_code(2147483648),
            "2147483648",
        )
        self.assertEqual(
            primitive_serializer("hash64").to_json_code(-1),
            "0",
        )
        self.assertEqual(
            primitive_serializer("hash64").to_json_code(9007199254740991),
            "9007199254740991",
        )
        self.assertEqual(
            primitive_serializer("hash64").to_json_code(9007199254740992),
            '"9007199254740992"',
        )
        self.assertEqual(primitive_serializer("hash64").from_json_code("0"), 0)
        self.assertEqual(primitive_serializer("hash64").from_json_code('"7"'), 7)
        self.assertEqual(primitive_serializer("hash64").from_json_code("3.14"), 3)
        self.assertEqual(primitive_serializer("hash64").from_json_code("-3.14"), -3)

        self.assertEqual(primitive_serializer("float32").to_json_code(3.14), "3.14")
        self.assertEqual(
            primitive_serializer("float32").to_json_code(float("inf")), '"Infinity"'
        )
        self.assertEqual(
            primitive_serializer("float32").to_json_code(-float("inf")), '"-Infinity"'
        )
        self.assertEqual(
            primitive_serializer("float32").to_json_code(float("nan")), '"NaN"'
        )
        self.assertEqual(primitive_serializer("float32").from_json_code("3.14"), 3.14)
        self.assertEqual(
            primitive_serializer("float32").from_json_code('"Infinity"'), float("inf")
        )
        self.assertEqual(
            primitive_serializer("float32").from_json_code('"-Infinity"'), -float("inf")
        )
        self.assertNotEqual(
            primitive_serializer("float32").from_json_code('"NaN"'),
            primitive_serializer("float32").from_json_code('"NaN"'),
        )

        self.assertEqual(primitive_serializer("float64").to_json_code(3.14), "3.14")
        self.assertEqual(
            primitive_serializer("float64").to_json_code(3.14, readable=True),
            "3.14",
        )

        self.assertEqual(
            primitive_serializer("timestamp").to_json_code(
                Timestamp.from_unix_millis(3)
            ),
            "3",
        )
        self.assertEqual(
            primitive_serializer("timestamp").to_json_code(
                Timestamp.from_unix_millis(3), readable=True
            ),
            '{\n  "unix_millis": 3,\n  "formatted": "1970-01-01T00:00:00.003Z"\n}',
        )
        self.assertEqual(
            primitive_serializer("timestamp").from_json_code("3"),
            Timestamp.from_unix_millis(3),
        )
        self.assertEqual(
            primitive_serializer("timestamp").from_json_code(
                '{\n  "unix_millis": 3,\n  "formatted": "FOO",\n  "bar": true\n}'
            ),
            Timestamp.from_unix_millis(3),
        )

    def test_array_serializer(self):
        self.assertEqual(
            array_serializer(primitive_serializer("bool")).to_json_code((True, False)),
            "[1,0]",
        )
        self.assertEqual(
            array_serializer(primitive_serializer("bool")).to_json_code(
                (True, False), readable=True
            ),
            "[\n  true,\n  false\n]",
        )
        self.assertEqual(
            array_serializer(primitive_serializer("bool")).from_json_code(
                "[ true, false ]"
            ),
            (
                True,
                False,
            ),
        )
        self.assertEqual(
            array_serializer(primitive_serializer("bool")).from_json_code("0"),
            (),
        )

    def test_optional_serializer(self):
        self.assertEqual(
            optional_serializer(primitive_serializer("bool")).to_json_code(True),
            "1",
        )
        self.assertEqual(
            optional_serializer(primitive_serializer("bool")).to_json_code(
                True, readable=True
            ),
            "true",
        )
        self.assertEqual(
            optional_serializer(primitive_serializer("bool")).to_json_code(None),
            "null",
        )


class BinarySerializationTestCase(unittest.TestCase):
    """Test binary serialization (to_bytes/from_bytes) for all serializers."""

    def test_bool_binary_serialization(self):
        """Test bool binary encoding."""
        # Test true -> "736b697201" (skir prefix + 01)
        true_bytes = primitive_serializer("bool").to_bytes(True)
        self.assertEqual(true_bytes.hex(), "736b697201")
        self.assertEqual(primitive_serializer("bool").from_bytes(true_bytes), True)

        # Test false -> "736b697200" (skir prefix + 00)
        false_bytes = primitive_serializer("bool").to_bytes(False)
        self.assertEqual(false_bytes.hex(), "736b697200")
        self.assertEqual(primitive_serializer("bool").from_bytes(false_bytes), False)

    def test_int32_binary_encoding_specifics(self):
        """Test specific wire format encoding for int32."""
        test_cases = {
            0: "736b697200",
            1: "736b697201",
            231: "736b6972e7",
            232: "736b6972e8e800",
            257: "736b6972e80101",
            65535: "736b6972e8ffff",
            65536: "736b6972e900000100",
            -1: "736b6972ebff",
            -256: "736b6972eb00",
            -257: "736b6972ecfffe",
        }

        for value, expected_hex in test_cases.items():
            with self.subTest(value=value):
                result_bytes = primitive_serializer("int32").to_bytes(value)
                self.assertEqual(result_bytes.hex(), expected_hex)
                restored = primitive_serializer("int32").from_bytes(result_bytes)
                self.assertEqual(restored, value)

    def test_int32_binary_serialization(self):
        """Test int32 binary roundtrip."""
        values = [0, 1, -1, 42, -42, 2147483647, -2147483648]
        for value in values:
            with self.subTest(value=value):
                result_bytes = primitive_serializer("int32").to_bytes(value)
                restored = primitive_serializer("int32").from_bytes(result_bytes)
                self.assertEqual(restored, value)

    def test_int64_binary_serialization(self):
        """Test int64 binary roundtrip."""
        values = [0, 1, -1, 42, -42, 9223372036854775807, -9223372036854775808]
        for value in values:
            with self.subTest(value=value):
                result_bytes = primitive_serializer("int64").to_bytes(value)
                restored = primitive_serializer("int64").from_bytes(result_bytes)
                self.assertEqual(restored, value)

    def test_hash64_binary_serialization(self):
        """Test hash64 binary roundtrip."""
        values = [0, 1, 42, 18446744073709551615]
        for value in values:
            with self.subTest(value=value):
                result_bytes = primitive_serializer("hash64").to_bytes(value)
                restored = primitive_serializer("hash64").from_bytes(result_bytes)
                self.assertEqual(restored, value)

    def test_float32_binary_serialization(self):
        """Test float32 binary roundtrip."""
        values = [0.0, 1.0, -1.0, 3.14]
        for value in values:
            with self.subTest(value=value):
                result_bytes = primitive_serializer("float32").to_bytes(value)
                restored = primitive_serializer("float32").from_bytes(result_bytes)
                self.assertAlmostEqual(restored, value, places=5)

        # Test special float values
        inf_bytes = primitive_serializer("float32").to_bytes(float("inf"))
        self.assertEqual(
            primitive_serializer("float32").from_bytes(inf_bytes), float("inf")
        )

        neg_inf_bytes = primitive_serializer("float32").to_bytes(-float("inf"))
        self.assertEqual(
            primitive_serializer("float32").from_bytes(neg_inf_bytes), -float("inf")
        )

        nan_bytes = primitive_serializer("float32").to_bytes(float("nan"))
        self.assertTrue(
            str(primitive_serializer("float32").from_bytes(nan_bytes)) == "nan"
        )

    def test_float64_binary_serialization(self):
        """Test float64 binary roundtrip."""
        values = [0.0, 1.0, -1.0, 3.14159265359]
        for value in values:
            with self.subTest(value=value):
                result_bytes = primitive_serializer("float64").to_bytes(value)
                restored = primitive_serializer("float64").from_bytes(result_bytes)
                self.assertAlmostEqual(restored, value, places=10)

        # Test special float values
        inf_bytes = primitive_serializer("float64").to_bytes(float("inf"))
        self.assertEqual(
            primitive_serializer("float64").from_bytes(inf_bytes), float("inf")
        )

        neg_inf_bytes = primitive_serializer("float64").to_bytes(-float("inf"))
        self.assertEqual(
            primitive_serializer("float64").from_bytes(neg_inf_bytes), -float("inf")
        )

        nan_bytes = primitive_serializer("float64").to_bytes(float("nan"))
        self.assertTrue(
            str(primitive_serializer("float64").from_bytes(nan_bytes)) == "nan"
        )

    def test_string_binary_encoding_edge_cases(self):
        """Test string encoding edge cases."""
        test_cases = {
            "": "736b6972f2",
            "0": "736b6972f30130",
            "A": "736b6972f30141",
            "🚀": "736b6972f304f09f9a80",
            "\u0000": "736b6972f30100",
            "Hello\nWorld": "736b6972f30b48656c6c6f0a576f726c64",
        }

        for value, expected_hex in test_cases.items():
            with self.subTest(value=repr(value)):
                result_bytes = primitive_serializer("string").to_bytes(value)
                self.assertEqual(result_bytes.hex(), expected_hex)
                restored = primitive_serializer("string").from_bytes(result_bytes)
                self.assertEqual(restored, value)

    def test_string_binary_serialization(self):
        """Test string binary roundtrip."""
        values = [
            "",
            "hello",
            "world",
            "Hello, 世界!",
            "🚀",
            "\n\t\r",
            "A very long string that exceeds normal buffer sizes",
        ]
        for value in values:
            with self.subTest(value=value[:20]):
                result_bytes = primitive_serializer("string").to_bytes(value)
                restored = primitive_serializer("string").from_bytes(result_bytes)
                self.assertEqual(restored, value)

    def test_string_binary_decode_replaces_malformed_utf8(self):
        """Malformed UTF-8 byte sequences are replaced instead of raising."""
        invalid_bytes = bytes.fromhex("736b6972f302ff7a")
        restored = primitive_serializer("string").from_bytes(invalid_bytes)
        self.assertEqual(restored, "\ufffdz")

    def test_string_binary_encode_sanitizes_lone_surrogates(self):
        """Lone surrogates are sanitized to valid UTF-8 during encoding."""
        result_bytes = primitive_serializer("string").to_bytes("\ud800z")
        restored = primitive_serializer("string").from_bytes(result_bytes)
        self.assertEqual(restored, "?z")

    def test_bytes_binary_serialization(self):
        """Test bytes binary roundtrip."""
        values = [
            b"",
            b"hello",
            b"world",
            "Hello, 世界!".encode("utf-8"),
        ]
        for value in values:
            with self.subTest(value=value[:20]):
                result_bytes = primitive_serializer("bytes").to_bytes(value)
                restored = primitive_serializer("bytes").from_bytes(result_bytes)
                self.assertEqual(restored, value)

    def test_timestamp_binary_encoding_specifics(self):
        """Test timestamp binary encoding specifics."""
        test_cases = {
            Timestamp.from_unix_millis(0): "736b697200",
            Timestamp.from_unix_millis(1000): "736b6972efe803000000000000",
            Timestamp.from_unix_millis(-1000): "736b6972ef18fcffffffffffff",
        }

        for instant, expected_hex in test_cases.items():
            with self.subTest(instant=instant):
                result_bytes = primitive_serializer("timestamp").to_bytes(instant)
                self.assertEqual(result_bytes.hex(), expected_hex)
                restored = primitive_serializer("timestamp").from_bytes(result_bytes)
                self.assertEqual(restored, instant)

    def test_timestamp_binary_serialization(self):
        """Test timestamp binary roundtrip."""
        values = [
            Timestamp.from_unix_millis(0),
            Timestamp.from_unix_millis(1756117845000),  # 2025-08-25T10:30:45Z
            Timestamp.from_unix_millis(946684800000),  # 2000-01-01T00:00:00Z
        ]
        for value in values:
            with self.subTest(value=value):
                result_bytes = primitive_serializer("timestamp").to_bytes(value)
                restored = primitive_serializer("timestamp").from_bytes(result_bytes)
                self.assertEqual(restored, value)

    def test_optional_with_null_binary_serialization(self):
        """Test optional serializer with null values in binary format."""
        serializers = [
            optional_serializer(primitive_serializer("int32")),
            optional_serializer(primitive_serializer("string")),
            optional_serializer(primitive_serializer("bool")),
            optional_serializer(primitive_serializer("bytes")),
            optional_serializer(primitive_serializer("timestamp")),
        ]

        for ser in serializers:
            with self.subTest(serializer=ser):
                # Test null values in binary format
                null_bytes = ser.to_bytes(None)
                self.assertEqual(null_bytes.hex(), "736b6972ff")  # Should end with 0xFF
                restored = ser.from_bytes(null_bytes)
                self.assertIsNone(restored)

    def test_optional_with_non_null_binary_serialization(self):
        """Test optional serializer with non-null values."""
        # Test int32
        int_optional = optional_serializer(primitive_serializer("int32"))
        test_value = 42
        result_bytes = int_optional.to_bytes(test_value)
        restored = int_optional.from_bytes(result_bytes)
        self.assertEqual(restored, test_value)

        # Test string
        string_optional = optional_serializer(primitive_serializer("string"))
        test_string = "hello"
        string_bytes = string_optional.to_bytes(test_string)
        restored_string = string_optional.from_bytes(string_bytes)
        self.assertEqual(restored_string, test_string)

        # Test bool
        bool_optional = optional_serializer(primitive_serializer("bool"))
        test_bool = True
        bool_bytes = bool_optional.to_bytes(test_bool)
        restored_bool = bool_optional.from_bytes(bool_bytes)
        self.assertEqual(restored_bool, test_bool)

        # Test timestamp
        timestamp_optional = optional_serializer(primitive_serializer("timestamp"))
        test_timestamp = Timestamp.from_unix_millis(1756117845000)
        timestamp_bytes = timestamp_optional.to_bytes(test_timestamp)
        restored_timestamp = timestamp_optional.from_bytes(timestamp_bytes)
        self.assertEqual(restored_timestamp, test_timestamp)

    def test_optional_binary_format_specifics(self):
        """Test specific binary encodings for optional values."""
        int_optional = optional_serializer(primitive_serializer("int32"))

        test_cases = {
            None: "736b6972ff",
            0: "736b697200",
            42: "736b69722a",
            -1: "736b6972ebff",
        }

        for value, expected_hex in test_cases.items():
            with self.subTest(value=value):
                result_bytes = int_optional.to_bytes(value)
                self.assertEqual(result_bytes.hex(), expected_hex)
                restored = int_optional.from_bytes(result_bytes)
                self.assertEqual(restored, value)

    def test_list_with_empty_arrays_binary(self):
        """Test list serializers with empty arrays in binary format."""
        int_array_ser = array_serializer(primitive_serializer("int32"))
        string_array_ser = array_serializer(primitive_serializer("string"))
        bool_array_ser = array_serializer(primitive_serializer("bool"))

        # Test empty arrays - should have wire format 0xF6 (246)
        empty_int_array = ()
        empty_int_bytes = int_array_ser.to_bytes(empty_int_array)
        self.assertEqual(empty_int_bytes.hex(), "736b6972f6")
        self.assertEqual(int_array_ser.from_bytes(empty_int_bytes), empty_int_array)

        empty_string_array = ()
        empty_string_bytes = string_array_ser.to_bytes(empty_string_array)
        self.assertEqual(empty_string_bytes.hex(), "736b6972f6")
        self.assertEqual(
            string_array_ser.from_bytes(empty_string_bytes), empty_string_array
        )

        empty_bool_array = ()
        empty_bool_bytes = bool_array_ser.to_bytes(empty_bool_array)
        self.assertEqual(empty_bool_bytes.hex(), "736b6972f6")
        self.assertEqual(bool_array_ser.from_bytes(empty_bool_bytes), empty_bool_array)

    def test_list_with_small_arrays_binary(self):
        """Test arrays with 1-3 elements (should use wire bytes 247-249)."""
        int_array_ser = array_serializer(primitive_serializer("int32"))

        # Test single element array (wire 247)
        single_array = (42,)
        single_bytes = int_array_ser.to_bytes(single_array)
        self.assertTrue(single_bytes.hex().startswith("736b6972f7"))
        self.assertEqual(int_array_ser.from_bytes(single_bytes), single_array)

        # Test two element array (wire 248)
        double_array = (1, 2)
        double_bytes = int_array_ser.to_bytes(double_array)
        self.assertTrue(double_bytes.hex().startswith("736b6972f8"))
        self.assertEqual(int_array_ser.from_bytes(double_bytes), double_array)

        # Test three element array (wire 249)
        triple_array = (10, 20, 30)
        triple_bytes = int_array_ser.to_bytes(triple_array)
        self.assertTrue(triple_bytes.hex().startswith("736b6972f9"))
        self.assertEqual(int_array_ser.from_bytes(triple_bytes), triple_array)

    def test_list_with_large_arrays_binary(self):
        """Test arrays with more than 3 elements (should use wire byte 250 + length)."""
        int_array_ser = array_serializer(primitive_serializer("int32"))

        # Test array with 10 elements
        large_array = tuple(range(1, 11))
        large_bytes = int_array_ser.to_bytes(large_array)
        self.assertTrue(large_bytes.hex().startswith("736b6972fa"))
        self.assertEqual(int_array_ser.from_bytes(large_bytes), large_array)

        # Test array with 100 elements
        very_large_array = tuple(range(1, 101))
        very_large_bytes = int_array_ser.to_bytes(very_large_array)
        self.assertTrue(very_large_bytes.hex().startswith("736b6972fa"))
        self.assertEqual(int_array_ser.from_bytes(very_large_bytes), very_large_array)

    def test_list_binary_format_specifics(self):
        """Test specific binary format expectations based on list size."""
        int_array_ser = array_serializer(primitive_serializer("int32"))

        test_cases = {
            (): "736b6972f6",
            (1,): "736b6972f701",
            (1, 2): "736b6972f80102",
            (1, 2, 3): "736b6972f9010203",
        }

        for array, expected_hex in test_cases.items():
            with self.subTest(array=array):
                result_bytes = int_array_ser.to_bytes(array)
                self.assertEqual(result_bytes.hex(), expected_hex)
                restored = int_array_ser.from_bytes(result_bytes)
                self.assertEqual(restored, array)

    def test_list_with_different_element_types_binary(self):
        """Test list serializers with all primitive types in binary format."""
        test_cases = [
            (array_serializer(primitive_serializer("bool")), (True, False, True)),
            (array_serializer(primitive_serializer("int32")), (0, 1, -1, 42)),
            (
                array_serializer(primitive_serializer("int64")),
                (0, 42, -1, 9223372036854775807),
            ),
            (
                array_serializer(primitive_serializer("hash64")),
                (0, 42, 18446744073709551615),
            ),
            (
                array_serializer(primitive_serializer("string")),
                ("", "hello", "world", "🚀"),
            ),
            (
                array_serializer(primitive_serializer("bytes")),
                (b"", b"test", b"hello world"),
            ),
        ]

        for serializer, array in test_cases:
            with self.subTest(array=array):
                result_bytes = serializer.to_bytes(array)
                restored = serializer.from_bytes(result_bytes)
                self.assertEqual(restored, array)

    def test_list_with_optional_elements_binary(self):
        """Test list with optional elements (some None, some not)."""
        optional_int_ser = optional_serializer(primitive_serializer("int32"))
        optional_int_array_ser = array_serializer(optional_int_ser)

        # Test list with mixed None and non-None values
        mixed_array = (1, None, 42, None, 0)
        mixed_bytes = optional_int_array_ser.to_bytes(mixed_array)
        restored = optional_int_array_ser.from_bytes(mixed_bytes)
        self.assertEqual(restored, mixed_array)

        # Test all None list
        all_none_array = (None, None, None)
        all_none_bytes = optional_int_array_ser.to_bytes(all_none_array)
        restored_all_none = optional_int_array_ser.from_bytes(all_none_bytes)
        self.assertEqual(restored_all_none, all_none_array)

        # Test no None list
        no_none_array = (1, 2, 3)
        no_none_bytes = optional_int_array_ser.to_bytes(no_none_array)
        restored_no_none = optional_int_array_ser.from_bytes(no_none_bytes)
        self.assertEqual(restored_no_none, no_none_array)

    def test_nested_list_serializers_binary(self):
        """Test nested list serializers in binary format."""
        int_array_ser = array_serializer(primitive_serializer("int32"))
        nested_int_array_ser = array_serializer(int_array_ser)

        # Test list of arrays
        nested_array = (
            (1, 2, 3),
            (4, 5),
            (),
            (6,),
        )

        nested_bytes = nested_int_array_ser.to_bytes(nested_array)
        restored = nested_int_array_ser.from_bytes(nested_bytes)
        self.assertEqual(restored, nested_array)

    def test_all_defaults_roundtrip_binary(self):
        """Test that default values roundtrip correctly through binary serialization."""
        # Test bool
        bool_ser = primitive_serializer("bool")
        bool_bytes = bool_ser.to_bytes(False)
        self.assertEqual(bool_ser.from_bytes(bool_bytes), False)

        # Test int32
        int32_ser = primitive_serializer("int32")
        int32_bytes = int32_ser.to_bytes(0)
        self.assertEqual(int32_ser.from_bytes(int32_bytes), 0)

        # Test int64
        int64_ser = primitive_serializer("int64")
        int64_bytes = int64_ser.to_bytes(0)
        self.assertEqual(int64_ser.from_bytes(int64_bytes), 0)

        # Test hash64
        hash64_ser = primitive_serializer("hash64")
        hash64_bytes = hash64_ser.to_bytes(0)
        self.assertEqual(hash64_ser.from_bytes(hash64_bytes), 0)

        # Test float32
        float32_ser = primitive_serializer("float32")
        float32_bytes = float32_ser.to_bytes(0.0)
        self.assertEqual(float32_ser.from_bytes(float32_bytes), 0.0)

        # Test float64
        float64_ser = primitive_serializer("float64")
        float64_bytes = float64_ser.to_bytes(0.0)
        self.assertEqual(float64_ser.from_bytes(float64_bytes), 0.0)

        # Test string
        string_ser = primitive_serializer("string")
        string_bytes = string_ser.to_bytes("")
        self.assertEqual(string_ser.from_bytes(string_bytes), "")

        # Test bytes
        bytes_ser = primitive_serializer("bytes")
        bytes_bytes = bytes_ser.to_bytes(b"")
        self.assertEqual(bytes_ser.from_bytes(bytes_bytes), b"")

        # Test timestamp
        timestamp_ser = primitive_serializer("timestamp")
        timestamp_bytes = timestamp_ser.to_bytes(Timestamp.from_unix_millis(0))
        self.assertEqual(
            timestamp_ser.from_bytes(timestamp_bytes), Timestamp.from_unix_millis(0)
        )
