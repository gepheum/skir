using System.Collections.Immutable;
using SkirClient;
using Skirout_External_Gepheum_SkirGoldenTests_Goldens;

namespace SkirClientTest;

/// <summary>
/// Golden tests – verify that serialization and deserialization output is
/// consistent and matches the cross-language spec defined in
/// goldens.readonly.skir.
/// </summary>
public sealed class GoldensTests
{
    // =========================================================================
    // Test entry point
    // =========================================================================

    [Fact]
    public void RunGoldenTests()
    {
        var unitTests = Consts.UnitTests;
        Assert.False(unitTests.IsEmpty, "UNIT_TESTS constant is empty — golden test data failed to load");

        // Verify test numbers are sequential.
        int firstNumber = unitTests[0].TestNumber;
        for (int i = 0; i < unitTests.Length; i++)
        {
            Assert.Equal(firstNumber + i, unitTests[i].TestNumber);
        }

        // Run each test, collecting all failures.
        var failures = new System.Collections.Generic.List<string>();
        foreach (var unitTest in unitTests)
        {
            try
            {
                VerifyAssertion(unitTest.Assertion);
            }
            catch (GoldenAssertionException ex)
            {
                failures.Add($"Test #{unitTest.TestNumber}: {ex.Message}");
            }
        }

        if (failures.Count > 0)
        {
            throw new Xunit.Sdk.XunitException(
                $"{failures.Count} golden test(s) failed:\n\n{string.Join("\n\n", failures)}");
        }
    }

    // =========================================================================
    // Assertion evaluation
    // =========================================================================

    private static void VerifyAssertion(Assertion assertion)
    {
        switch (assertion.Kind)
        {
            case Assertion.KindType.BytesEqualWrapper: VerifyBytesEqual(assertion.AsBytesEqual()); return;
            case Assertion.KindType.BytesInWrapper: VerifyBytesIn(assertion.AsBytesIn()); return;
            case Assertion.KindType.StringEqualWrapper: VerifyStringEqual(assertion.AsStringEqual()); return;
            case Assertion.KindType.StringInWrapper: VerifyStringIn(assertion.AsStringIn()); return;
            case Assertion.KindType.ReserializeValueWrapper: VerifyReserializeValue(assertion.AsReserializeValue()); return;
            case Assertion.KindType.ReserializeLargeStringWrapper: VerifyReserializeLargeString(assertion.AsReserializeLargeString()); return;
            case Assertion.KindType.ReserializeLargeArrayWrapper: VerifyReserializeLargeArray(assertion.AsReserializeLargeArray()); return;
            case Assertion.KindType.EnumAFromJsonIsConstantWrapper: VerifyEnumAFromJsonIsConstant(assertion.AsEnumAFromJsonIsConstant()); return;
            case Assertion.KindType.EnumAFromBytesIsConstantWrapper: VerifyEnumAFromBytesIsConstant(assertion.AsEnumAFromBytesIsConstant()); return;
            case Assertion.KindType.EnumBFromJsonIsWrapperBWrapper: VerifyEnumBFromJsonIsWrapperB(assertion.AsEnumBFromJsonIsWrapperB()); return;
            case Assertion.KindType.EnumBFromBytesIsWrapperBWrapper: VerifyEnumBFromBytesIsWrapperB(assertion.AsEnumBFromBytesIsWrapperB()); return;
            default: throw new GoldenAssertionException("unknown Assertion variant");
        }
    }

    private static void VerifyBytesEqual(Assertion_BytesEqual a)
    {
        var actual = EvaluateBytes(a.Actual);
        var expected = EvaluateBytes(a.Expected);
        if (!actual.SequenceEqual(expected))
        {
            throw new GoldenAssertionException(
                $"bytes mismatch\n  actual:   hex:{ToHex(actual)}\n  expected: hex:{ToHex(expected)}");
        }
    }

    private static void VerifyBytesIn(Assertion_BytesIn a)
    {
        var actual = EvaluateBytes(a.Actual);
        bool found = a.Expected.Any(exp => exp.Span.SequenceEqual(actual));
        if (!found)
        {
            var expectedHex = string.Join(" or ", a.Expected.Select(b => $"hex:{ToHex(b.ToArray())}"));
            throw new GoldenAssertionException(
                $"bytes not in expected set\n  actual:   hex:{ToHex(actual)}\n  expected: {expectedHex}");
        }
    }

    private static void VerifyStringEqual(Assertion_StringEqual a)
    {
        var actual = EvaluateString(a.Actual);
        var expected = EvaluateString(a.Expected);
        if (actual != expected)
        {
            throw new GoldenAssertionException(
                $"string mismatch\n  actual:   {actual}\n  expected: {expected}");
        }
    }

    private static void VerifyStringIn(Assertion_StringIn a)
    {
        var actual = EvaluateString(a.Actual);
        if (!a.Expected.Contains(actual))
        {
            var expectedList = string.Join(" or ", a.Expected.Select(s => $"\"{s}\""));
            throw new GoldenAssertionException(
                $"string not in expected set\n  actual:   \"{actual}\"\n  expected: {expectedList}");
        }
    }

    private static void VerifyEnumAFromJsonIsConstant(Assertion_EnumAFromJsonIsConstant a)
    {
        var json = EvaluateString(a.Actual);
        var value = EnumA.Serializer.FromJson(json, keepUnrecognizedValues: a.KeepUnrecognized);
        if (!ReferenceEquals(value, EnumA.A))
        {
            throw new GoldenAssertionException(
                $"enum_a_from_json_is_constant mismatch\n  actual json: \"{json}\"\n  expected: EnumA.A");
        }
    }

    private static void VerifyEnumAFromBytesIsConstant(Assertion_EnumAFromBytesIsConstant a)
    {
        var bytes = EvaluateBytes(a.Actual);
        var value = EnumA.Serializer.FromBytes(bytes, keepUnrecognizedValues: a.KeepUnrecognized);
        if (!ReferenceEquals(value, EnumA.A))
        {
            throw new GoldenAssertionException(
                $"enum_a_from_bytes_is_constant mismatch\n  actual bytes: hex:{ToHex(bytes)}\n  expected: EnumA.A");
        }
    }

    private static void VerifyEnumBFromJsonIsWrapperB(Assertion_EnumBFromJsonIsWrapperB a)
    {
        var json = EvaluateString(a.Actual);
        var value = EnumB.Serializer.FromJson(json, keepUnrecognizedValues: a.KeepUnrecognized);
        if (value.Kind == EnumB.KindType.BWrapper)
        {
            var b = value.AsB();
            if (b != a.Expected)
            {
                throw new GoldenAssertionException(
                    $"enum_b_from_json_is_wrapper_b mismatch\n  actual json: \"{json}\"\n  expected: EnumB.B(\"{a.Expected}\"), got EnumB.B(\"{b}\")");
            }
        }
        else
        {
            throw new GoldenAssertionException(
                $"enum_b_from_json_is_wrapper_b mismatch\n  actual json: \"{json}\"\n  expected: EnumB.B, got {value?.GetType().Name ?? "null"}");
        }
    }

    private static void VerifyEnumBFromBytesIsWrapperB(Assertion_EnumBFromBytesIsWrapperB a)
    {
        var bytes = EvaluateBytes(a.Actual);
        var value = EnumB.Serializer.FromBytes(bytes, keepUnrecognizedValues: a.KeepUnrecognized);
        if (value.Kind == EnumB.KindType.BWrapper)
        {
            var b = value.AsB();
            if (b != a.Expected)
            {
                throw new GoldenAssertionException(
                    $"enum_b_from_bytes_is_wrapper_b mismatch\n  actual bytes: hex:{ToHex(bytes)}\n  expected: EnumB.B(\"{a.Expected}\"), got EnumB.B(\"{b}\")");
            }
        }
        else
        {
            throw new GoldenAssertionException(
                $"enum_b_from_bytes_is_wrapper_b mismatch\n  actual bytes: hex:{ToHex(bytes)}\n  expected: EnumB.B, got {value?.GetType().Name ?? "null"}");
        }
    }

    private static void VerifyReserializeValue(Assertion_ReserializeValue input)
    {
        // Build 4 input typed values: original + 3 round-trip variants.
        var roundTripVariants = new TypedValue[]
        {
            TypedValue.WrapRoundTripDenseJson(input.Value),
            TypedValue.WrapRoundTripReadableJson(input.Value),
            TypedValue.WrapRoundTripBytes(input.Value),
        };
        var allValues = new TypedValue[] { input.Value }
            .Concat(roundTripVariants.Cast<TypedValue>())
            .ToList();

        foreach (var inputTv in allValues)
        {
            try
            {
                var ev = EvaluateTypedValue(inputTv);

                // Verify bytes.
                var actualBytes = ev.ToBytes();
                bool foundBytes = input.ExpectedBytes.Any(exp => exp.Span.SequenceEqual(actualBytes));
                if (!foundBytes)
                {
                    var expectedHex = string.Join(" or ", input.ExpectedBytes.Select(b => $"hex:{ToHex(b.ToArray())}"));
                    throw new GoldenAssertionException(
                        $"bytes not in expected set\n  actual:   hex:{ToHex(actualBytes)}\n  expected: {expectedHex}");
                }

                // Verify dense JSON.
                var denseJson = ev.ToDenseJson();
                if (!input.ExpectedDenseJson.Contains(denseJson))
                {
                    var expectedList = string.Join(" or ", input.ExpectedDenseJson.Select(s => $"\"{s}\""));
                    throw new GoldenAssertionException(
                        $"dense JSON not in expected set\n  actual:   \"{denseJson}\"\n  expected: {expectedList}");
                }

                // Verify readable JSON.
                var readableJson = ev.ToReadableJson();
                if (!input.ExpectedReadableJson.Contains(readableJson))
                {
                    var expectedList = string.Join(" or ", input.ExpectedReadableJson.Select(s => $"\"{s}\""));
                    throw new GoldenAssertionException(
                        $"readable JSON not in expected set\n  actual:   \"{readableJson}\"\n  expected: {expectedList}");
                }
            }
            catch (GoldenAssertionException ex)
            {
                throw new GoldenAssertionException($"{ex.Message}\n  (while evaluating round-trip variant)");
            }
        }

        // Verify that encoded values can be skipped during decoding.
        // Build a buffer: "skir" + 0xF8 + payload_without_magic + 0x01
        // After decoding as Point, x must equal 1 (skipped unknown payload).
        foreach (var expectedBytes in input.ExpectedBytes)
        {
            var expectedByteArray = expectedBytes.ToArray();
            var buf = new byte[expectedByteArray.Length + 2];
            // "skir" magic
            buf[0] = (byte)'s'; buf[1] = (byte)'k'; buf[2] = (byte)'i'; buf[3] = (byte)'r';
            buf[4] = 248; // tag that causes decoder to skip the embedded value
            // payload without "skir" magic (starts at offset 4)
            Array.Copy(expectedByteArray, 4, buf, 5, expectedByteArray.Length - 4);
            buf[expectedByteArray.Length + 1] = 1; // encodes x = 1 for Point (field 0, small positive varint)
            var point = Point.Serializer.FromBytes(buf);
            if (point.X != 1)
            {
                throw new GoldenAssertionException(
                    $"skip-value test: expected point.X == 1, got {point.X}");
            }
        }

        // Round-trip alternative JSONs through the canonical serializer.
        var typedEv = EvaluateTypedValue(input.Value);
        foreach (var altJsonExpr in input.AlternativeJsons)
        {
            try
            {
                var altJson = EvaluateString(altJsonExpr);
                var roundTripped = typedEv.FromJsonKeepUnrecognized(altJson);
                var roundTripJson = roundTripped.ToDenseJson();
                if (!input.ExpectedDenseJson.Contains(roundTripJson))
                {
                    var expectedList = string.Join(" or ", input.ExpectedDenseJson.Select(s => $"\"{s}\""));
                    throw new GoldenAssertionException(
                        $"alternative JSON round-trip mismatch\n  got: \"{roundTripJson}\"\n  expected: {expectedList}\n  (while processing alternative JSON: \"{altJson}\")");
                }
            }
            catch (GoldenAssertionException)
            {
                throw;
            }
        }

        // Round-trip expected dense and readable JSONs.
        var allExpectedJsons = input.ExpectedDenseJson.Concat(input.ExpectedReadableJson);
        foreach (var altJson in allExpectedJsons)
        {
            try
            {
                var roundTripped = typedEv.FromJsonKeepUnrecognized(altJson);
                var roundTripJson = roundTripped.ToDenseJson();
                if (!input.ExpectedDenseJson.Contains(roundTripJson))
                {
                    var expectedList = string.Join(" or ", input.ExpectedDenseJson.Select(s => $"\"{s}\""));
                    throw new GoldenAssertionException(
                        $"expected JSON round-trip mismatch\n  got: \"{roundTripJson}\"\n  expected: {expectedList}\n  (while processing expected JSON: \"{altJson}\")");
                }
            }
            catch (GoldenAssertionException)
            {
                throw;
            }
        }

        // Round-trip alternative bytes.
        foreach (var altBytesExpr in input.AlternativeBytes)
        {
            try
            {
                var altBytes = EvaluateBytes(altBytesExpr);
                var roundTripped = typedEv.FromBytesDropUnrecognized(altBytes);
                var roundTripBytes = roundTripped.ToBytes();
                bool found = input.ExpectedBytes.Any(exp => exp.Span.SequenceEqual(roundTripBytes));
                if (!found)
                {
                    var expectedHex = string.Join(" or ", input.ExpectedBytes.Select(b => $"hex:{ToHex(b.ToArray())}"));
                    throw new GoldenAssertionException(
                        $"alternative bytes round-trip mismatch\n  got:      hex:{ToHex(roundTripBytes)}\n  expected: {expectedHex}\n  (while processing alternative bytes: hex:{ToHex(altBytes)})");
                }
            }
            catch (GoldenAssertionException)
            {
                throw;
            }
        }

        // Round-trip expected bytes.
        foreach (var altBytes in input.ExpectedBytes)
        {
            try
            {
                var altByteArray = altBytes.ToArray();
                var roundTripped = typedEv.FromBytesDropUnrecognized(altByteArray);
                var roundTripBytes = roundTripped.ToBytes();
                bool found = input.ExpectedBytes.Any(exp => exp.Span.SequenceEqual(roundTripBytes));
                if (!found)
                {
                    var expectedHex = string.Join(" or ", input.ExpectedBytes.Select(b => $"hex:{ToHex(b.ToArray())}"));
                    throw new GoldenAssertionException(
                        $"expected bytes round-trip mismatch\n  got:      hex:{ToHex(roundTripBytes)}\n  expected: {expectedHex}\n  (while processing expected bytes: hex:{ToHex(altByteArray)})");
                }
            }
            catch (GoldenAssertionException)
            {
                throw;
            }
        }

        // Type descriptor check.
        if (input.ExpectedTypeDescriptor is string expectedTd)
        {
            var actualTd = typedEv.TypeDescriptorJson();
            if (actualTd != expectedTd)
            {
                throw new GoldenAssertionException(
                    $"type descriptor mismatch\n  actual:   \"{actualTd}\"\n  expected: \"{expectedTd}\"");
            }
            // Verify round-trip of the type descriptor itself.
            var parsed = TypeDescriptor.ParseFromJson(expectedTd);
            var reparsedTd = parsed.AsJson();
            if (reparsedTd != expectedTd)
            {
                throw new GoldenAssertionException(
                    $"type descriptor round-trip mismatch\n  actual:   \"{reparsedTd}\"\n  expected: \"{expectedTd}\"");
            }
        }
    }

    private static void VerifyReserializeLargeString(Assertion_ReserializeLargeString input)
    {
        var s = new string('a', input.NumChars);
        var ser = Serializers.String;

        // Dense JSON round-trip.
        {
            var json = ser.ToJson(s);
            var roundTrip = ser.FromJson(json);
            if (roundTrip != s)
            {
                throw new GoldenAssertionException(
                    $"large string dense JSON round-trip mismatch  actual len: {roundTrip.Length}  expected len: {s.Length}");
            }
        }

        // Readable JSON round-trip.
        {
            var json = ser.ToJson(s, readable: true);
            var roundTrip = ser.FromJson(json);
            if (roundTrip != s)
            {
                throw new GoldenAssertionException(
                    $"large string readable JSON round-trip mismatch  actual len: {roundTrip.Length}  expected len: {s.Length}");
            }
        }

        // Binary round-trip + prefix check.
        {
            var bytes = ser.ToBytes(s);
            var prefix = input.ExpectedBytePrefix.ToArray();
            if (!bytes.Take(prefix.Length).SequenceEqual(prefix))
            {
                throw new GoldenAssertionException(
                    $"large string byte prefix mismatch\n  actual:   hex:{ToHex(bytes.Take(prefix.Length + 8).ToArray())}\n  expected prefix: hex:{ToHex(prefix)}...");
            }
            var roundTrip = ser.FromBytes(bytes);
            if (roundTrip != s)
            {
                throw new GoldenAssertionException(
                    $"large string bytes round-trip mismatch  actual len: {roundTrip.Length}  expected len: {s.Length}");
            }
        }
    }

    private static void VerifyReserializeLargeArray(Assertion_ReserializeLargeArray input)
    {
        var n = input.NumItems;
        var array = Enumerable.Repeat(1, n).ToImmutableArray();
        var ser = Serializers.Array(Serializers.Int32);

        bool IsCorrect(ImmutableArray<int> v) => v.Length == n && v.All(x => x == 1);

        // Dense JSON round-trip.
        {
            var json = ser.ToJson(array);
            var roundTrip = ser.FromJson(json);
            if (!IsCorrect(roundTrip))
            {
                throw new GoldenAssertionException(
                    $"large array dense JSON round-trip mismatch (len={roundTrip.Length}, all_ones={roundTrip.All(x => x == 1)})");
            }
        }

        // Readable JSON round-trip.
        {
            var json = ser.ToJson(array, readable: true);
            var roundTrip = ser.FromJson(json);
            if (!IsCorrect(roundTrip))
            {
                throw new GoldenAssertionException(
                    $"large array readable JSON round-trip mismatch (len={roundTrip.Length}, all_ones={roundTrip.All(x => x == 1)})");
            }
        }

        // Binary round-trip + prefix check.
        {
            var bytes = ser.ToBytes(array);
            var prefix = input.ExpectedBytePrefix.ToArray();
            if (!bytes.Take(prefix.Length).SequenceEqual(prefix))
            {
                throw new GoldenAssertionException(
                    $"large array byte prefix mismatch\n  actual:   hex:{ToHex(bytes.Take(prefix.Length + 8).ToArray())}\n  expected prefix: hex:{ToHex(prefix)}...");
            }
            var roundTrip = ser.FromBytes(bytes);
            if (!IsCorrect(roundTrip))
            {
                throw new GoldenAssertionException(
                    $"large array bytes round-trip mismatch (len={roundTrip.Length}, all_ones={roundTrip.All(x => x == 1)})");
            }
        }
    }

    // =========================================================================
    // EvaluatedValue — type-erased value + serializer
    // =========================================================================

    /// <summary>Holds a value together with its serializer.</summary>
    private abstract class EvaluatedValue
    {
        public abstract byte[] ToBytes();
        public abstract string ToDenseJson();
        public abstract string ToReadableJson();
        public abstract string TypeDescriptorJson();
        public abstract EvaluatedValue FromJsonKeepUnrecognized(string json);
        public abstract EvaluatedValue FromBytesDropUnrecognized(byte[] bytes);
    }

    private sealed class EvaluatedValue<T> : EvaluatedValue
    {
        private readonly T _value;
        private readonly Serializer<T> _serializer;

        public EvaluatedValue(T value, Serializer<T> serializer)
        {
            _value = value;
            _serializer = serializer;
        }

        public override byte[] ToBytes() => _serializer.ToBytes(_value);
        public override string ToDenseJson() => _serializer.ToJson(_value);
        public override string ToReadableJson() => _serializer.ToJson(_value, readable: true);
        public override string TypeDescriptorJson() => _serializer.TypeDescriptor.AsJson();

        public override EvaluatedValue FromJsonKeepUnrecognized(string json)
        {
            var value = _serializer.FromJson(json, keepUnrecognizedValues: true);
            return new EvaluatedValue<T>(value, _serializer);
        }

        public override EvaluatedValue FromBytesDropUnrecognized(byte[] bytes)
        {
            var value = _serializer.FromBytes(bytes, keepUnrecognizedValues: false);
            return new EvaluatedValue<T>(value, _serializer);
        }
    }

    private static EvaluatedValue Ev<T>(T value, Serializer<T> serializer)
        => new EvaluatedValue<T>(value, serializer);

    // =========================================================================
    // Evaluate helpers
    // =========================================================================

    private static string ToHex(byte[] bytes)
        => BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();

    private static string ToHex(ReadOnlySpan<byte> bytes)
        => ToHex(bytes.ToArray());

    private static byte[] EvaluateBytes(BytesExpression expr) =>
        expr.Kind switch
        {
            BytesExpression.KindType.LiteralWrapper => expr.AsLiteral().ToArray(),
            BytesExpression.KindType.ToBytesWrapper => EvaluateTypedValue(expr.AsToBytes()).ToBytes(),
            _ => throw new GoldenAssertionException("unknown BytesExpression variant")
        };

    private static string EvaluateString(StringExpression expr) =>
        expr.Kind switch
        {
            StringExpression.KindType.LiteralWrapper => expr.AsLiteral(),
            StringExpression.KindType.ToDenseJsonWrapper => EvaluateTypedValue(expr.AsToDenseJson()).ToDenseJson(),
            StringExpression.KindType.ToReadableJsonWrapper => EvaluateTypedValue(expr.AsToReadableJson()).ToReadableJson(),
            _ => throw new GoldenAssertionException("unknown StringExpression variant")
        };

    private static EvaluatedValue EvaluateTypedValue(TypedValue tv)
    {
        switch (tv.Kind)
        {
            case TypedValue.KindType.BoolWrapper: return Ev(tv.AsBool(), Serializers.Bool);
            case TypedValue.KindType.Int32Wrapper: return Ev(tv.AsInt32(), Serializers.Int32);
            case TypedValue.KindType.Int64Wrapper: return Ev(tv.AsInt64(), Serializers.Int64);
            case TypedValue.KindType.Hash64Wrapper: return Ev(tv.AsHash64(), Serializers.Hash64);
            case TypedValue.KindType.Float32Wrapper: return Ev(tv.AsFloat32(), Serializers.Float32);
            case TypedValue.KindType.Float64Wrapper: return Ev(tv.AsFloat64(), Serializers.Float64);
            case TypedValue.KindType.TimestampWrapper: return Ev(tv.AsTimestamp(), Serializers.Timestamp);
            case TypedValue.KindType.StringWrapper: return Ev(tv.AsString(), Serializers.String);
            case TypedValue.KindType.BytesWrapper: return Ev(tv.AsBytes(), Serializers.Bytes);
            case TypedValue.KindType.BoolOptionalWrapper: return Ev(tv.AsBoolOptional(), Serializers.OptionalValue(Serializers.Bool));
            case TypedValue.KindType.IntsWrapper: return Ev(tv.AsInts(), Serializers.Array(Serializers.Int32));
            case TypedValue.KindType.PointWrapper: return Ev(tv.AsPoint(), Point.Serializer);
            case TypedValue.KindType.ColorWrapper: return Ev(tv.AsColor(), Color.Serializer);
            case TypedValue.KindType.MyEnumWrapper: return Ev(tv.AsMyEnum(), MyEnum.Serializer);
            case TypedValue.KindType.EnumAWrapper: return Ev(tv.AsEnumA(), EnumA.Serializer);
            case TypedValue.KindType.EnumBWrapper: return Ev(tv.AsEnumB(), EnumB.Serializer);
            case TypedValue.KindType.KeyedArraysWrapper: return Ev(tv.AsKeyedArrays(), KeyedArrays.Serializer);
            case TypedValue.KindType.RecStructWrapper: return Ev(tv.AsRecStruct(), RecStruct.Serializer);
            case TypedValue.KindType.RecEnumWrapper: return Ev(tv.AsRecEnum(), RecEnum.Serializer);
            case TypedValue.KindType.RoundTripDenseJsonWrapper: return RoundTripViaJson(tv.AsRoundTripDenseJson(), dense: true);
            case TypedValue.KindType.RoundTripReadableJsonWrapper: return RoundTripViaJson(tv.AsRoundTripReadableJson(), dense: false);
            case TypedValue.KindType.RoundTripBytesWrapper: return RoundTripViaBytes(tv.AsRoundTripBytes());
            case TypedValue.KindType.PointFromJsonKeepUnrecognizedWrapper:
                return Ev(Point.Serializer.FromJson(EvaluateString(tv.AsPointFromJsonKeepUnrecognized()), keepUnrecognizedValues: true), Point.Serializer);
            case TypedValue.KindType.PointFromJsonDropUnrecognizedWrapper:
                return Ev(Point.Serializer.FromJson(EvaluateString(tv.AsPointFromJsonDropUnrecognized()), keepUnrecognizedValues: false), Point.Serializer);
            case TypedValue.KindType.PointFromBytesKeepUnrecognizedWrapper:
                return Ev(Point.Serializer.FromBytes(EvaluateBytes(tv.AsPointFromBytesKeepUnrecognized()), keepUnrecognizedValues: true), Point.Serializer);
            case TypedValue.KindType.PointFromBytesDropUnrecognizedWrapper:
                return Ev(Point.Serializer.FromBytes(EvaluateBytes(tv.AsPointFromBytesDropUnrecognized()), keepUnrecognizedValues: false), Point.Serializer);
            case TypedValue.KindType.ColorFromJsonKeepUnrecognizedWrapper:
                return Ev(Color.Serializer.FromJson(EvaluateString(tv.AsColorFromJsonKeepUnrecognized()), keepUnrecognizedValues: true), Color.Serializer);
            case TypedValue.KindType.ColorFromJsonDropUnrecognizedWrapper:
                return Ev(Color.Serializer.FromJson(EvaluateString(tv.AsColorFromJsonDropUnrecognized()), keepUnrecognizedValues: false), Color.Serializer);
            case TypedValue.KindType.ColorFromBytesKeepUnrecognizedWrapper:
                return Ev(Color.Serializer.FromBytes(EvaluateBytes(tv.AsColorFromBytesKeepUnrecognized()), keepUnrecognizedValues: true), Color.Serializer);
            case TypedValue.KindType.ColorFromBytesDropUnrecognizedWrapper:
                return Ev(Color.Serializer.FromBytes(EvaluateBytes(tv.AsColorFromBytesDropUnrecognized()), keepUnrecognizedValues: false), Color.Serializer);
            case TypedValue.KindType.MyEnumFromJsonKeepUnrecognizedWrapper:
                return Ev(MyEnum.Serializer.FromJson(EvaluateString(tv.AsMyEnumFromJsonKeepUnrecognized()), keepUnrecognizedValues: true), MyEnum.Serializer);
            case TypedValue.KindType.MyEnumFromJsonDropUnrecognizedWrapper:
                return Ev(MyEnum.Serializer.FromJson(EvaluateString(tv.AsMyEnumFromJsonDropUnrecognized()), keepUnrecognizedValues: false), MyEnum.Serializer);
            case TypedValue.KindType.MyEnumFromBytesKeepUnrecognizedWrapper:
                return Ev(MyEnum.Serializer.FromBytes(EvaluateBytes(tv.AsMyEnumFromBytesKeepUnrecognized()), keepUnrecognizedValues: true), MyEnum.Serializer);
            case TypedValue.KindType.MyEnumFromBytesDropUnrecognizedWrapper:
                return Ev(MyEnum.Serializer.FromBytes(EvaluateBytes(tv.AsMyEnumFromBytesDropUnrecognized()), keepUnrecognizedValues: false), MyEnum.Serializer);
            case TypedValue.KindType.EnumAFromJsonKeepUnrecognizedWrapper:
                return Ev(EnumA.Serializer.FromJson(EvaluateString(tv.AsEnumAFromJsonKeepUnrecognized()), keepUnrecognizedValues: true), EnumA.Serializer);
            case TypedValue.KindType.EnumAFromJsonDropUnrecognizedWrapper:
                return Ev(EnumA.Serializer.FromJson(EvaluateString(tv.AsEnumAFromJsonDropUnrecognized()), keepUnrecognizedValues: false), EnumA.Serializer);
            case TypedValue.KindType.EnumAFromBytesKeepUnrecognizedWrapper:
                return Ev(EnumA.Serializer.FromBytes(EvaluateBytes(tv.AsEnumAFromBytesKeepUnrecognized()), keepUnrecognizedValues: true), EnumA.Serializer);
            case TypedValue.KindType.EnumAFromBytesDropUnrecognizedWrapper:
                return Ev(EnumA.Serializer.FromBytes(EvaluateBytes(tv.AsEnumAFromBytesDropUnrecognized()), keepUnrecognizedValues: false), EnumA.Serializer);
            case TypedValue.KindType.EnumBFromJsonKeepUnrecognizedWrapper:
                return Ev(EnumB.Serializer.FromJson(EvaluateString(tv.AsEnumBFromJsonKeepUnrecognized()), keepUnrecognizedValues: true), EnumB.Serializer);
            case TypedValue.KindType.EnumBFromJsonDropUnrecognizedWrapper:
                return Ev(EnumB.Serializer.FromJson(EvaluateString(tv.AsEnumBFromJsonDropUnrecognized()), keepUnrecognizedValues: false), EnumB.Serializer);
            case TypedValue.KindType.EnumBFromBytesKeepUnrecognizedWrapper:
                return Ev(EnumB.Serializer.FromBytes(EvaluateBytes(tv.AsEnumBFromBytesKeepUnrecognized()), keepUnrecognizedValues: true), EnumB.Serializer);
            case TypedValue.KindType.EnumBFromBytesDropUnrecognizedWrapper:
                return Ev(EnumB.Serializer.FromBytes(EvaluateBytes(tv.AsEnumBFromBytesDropUnrecognized()), keepUnrecognizedValues: false), EnumB.Serializer);
            default: throw new GoldenAssertionException("unknown TypedValue variant");
        }
    }

    private static EvaluatedValue RoundTripViaJson(TypedValue inner, bool dense)
    {
        var ev = EvaluateTypedValue(inner);
        var json = dense ? ev.ToDenseJson() : ev.ToReadableJson();
        return ev.FromBytesDropUnrecognized(
            ev.FromJsonKeepUnrecognized(json).ToBytes());
    }

    private static EvaluatedValue RoundTripViaBytes(TypedValue inner)
    {
        var ev = EvaluateTypedValue(inner);
        return ev.FromBytesDropUnrecognized(ev.ToBytes());
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    private sealed class GoldenAssertionException : Exception
    {
        public GoldenAssertionException(string message) : base(message) { }
    }
}
