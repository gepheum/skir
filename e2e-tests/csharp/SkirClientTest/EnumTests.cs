using System.Collections.Immutable;
using Skirout_Enums;

namespace SkirClientTest;

/// <summary>
/// Smoke tests for the generated enum types in enums.skir.
/// </summary>
public sealed class EnumTests
{
    // =========================================================================
    // Constant variants
    // =========================================================================

    [Fact]
    public void ConstantVariant_Kind()
    {
        Assert.Equal(Weekday.KindType.Monday, Weekday.Monday.Kind);
        Assert.Equal(Weekday.KindType.Unknown, Weekday.Unknown.Kind);
    }

    [Fact]
    public void ConstantVariant_SameInstanceEqualityAndHashCode()
    {
        // The static singletons are the canonical instances.
        Assert.True(ReferenceEquals(Weekday.Monday, Weekday.Monday));
        Assert.Equal(Weekday.Monday, Weekday.Monday);
        Assert.Equal(Weekday.Monday.GetHashCode(), Weekday.Monday.GetHashCode());
    }

    [Fact]
    public void ConstantVariant_DifferentVariantsNotEqual()
    {
        Assert.NotEqual(Weekday.Monday, Weekday.Tuesday);
        Assert.NotEqual(Weekday.Monday, Weekday.Unknown);
    }

    [Fact]
    public void UnknownVariants_AreAlwaysEqual()
    {
        // Two Unknown values (e.g. from different deserialization paths) are equal.
        Assert.Equal(Weekday.Unknown, Weekday.Unknown);
        Assert.Equal(0, Weekday.Unknown.GetHashCode());
    }

    // =========================================================================
    // Wrapper variants
    // =========================================================================

    [Fact]
    public void WrapperVariant_Kind()
    {
        var v = JsonValue.WrapBoolean(true);
        Assert.Equal(JsonValue.KindType.BooleanWrapper, v.Kind);
    }

    [Fact]
    public void WrapperVariant_AsX_ReturnsWrappedValue()
    {
        var v = JsonValue.WrapNumber(3.14);
        Assert.Equal(3.14, v.AsNumber());
    }

    [Fact]
    public void WrapperVariant_AsX_WrongKindThrows()
    {
        var v = JsonValue.WrapBoolean(true);
        Assert.Throws<InvalidOperationException>(() => v.AsNumber());
    }

    [Fact]
    public void WrapperVariant_EqualWhenSamePayload()
    {
        var a = JsonValue.WrapString("hello");
        var b = JsonValue.WrapString("hello");
        Assert.Equal(a, b);
        Assert.Equal(a.GetHashCode(), b.GetHashCode());
    }

    [Fact]
    public void ToString_ConstantVariant_ReturnsReadableJson()
    {
        Assert.Equal("\"monday\"", Weekday.Monday.ToString());
    }

    [Fact]
    public void ToString_UnknownVariant_ReturnsReadableJson()
    {
        Assert.Equal("\"unknown\"", Weekday.Unknown.ToString());
    }

    [Fact]
    public void ToString_WrapperVariant_ReturnsReadableJson()
    {
        var v = JsonValue.WrapBoolean(true);
        Assert.Equal("{\n  \"kind\": \"boolean\",\n  \"value\": true\n}", v.ToString());
    }

    [Fact]
    public void WrapperVariant_NotEqualWhenDifferentPayload()
    {
        var a = JsonValue.WrapString("hello");
        var b = JsonValue.WrapString("world");
        Assert.NotEqual(a, b);
    }

    [Fact]
    public void WrapperVariant_NotEqualToDifferentKind()
    {
        Assert.NotEqual(JsonValue.WrapBoolean(true), JsonValue.Null);
    }

    // =========================================================================
    // Visitor / Accept
    // =========================================================================

    [Fact]
    public void Accept_ConstantVariant()
    {
        var day = Weekday.Friday;
        string result = day.Accept(new WeekdayNameVisitor());
        Assert.Equal("Friday", result);
    }

    [Fact]
    public void Accept_UnknownVariant()
    {
        string result = Weekday.Unknown.Accept(new WeekdayNameVisitor());
        Assert.Equal("Unknown", result);
    }

    [Fact]
    public void Accept_WrapperVariant()
    {
        var v = JsonValue.WrapBoolean(true);
        string result = v.Accept(new JsonValueKindVisitor());
        Assert.Equal("boolean:True", result);
    }

    // =========================================================================
    // Round-trip serialization
    // =========================================================================

    [Fact]
    public void RoundTrip_Json_ConstantVariant()
    {
        var original = Weekday.Wednesday;
        string json = Weekday.Serializer.ToJson(original);
        var decoded = Weekday.Serializer.FromJson(json);
        Assert.Equal(original, decoded);
        Assert.True(ReferenceEquals(decoded, Weekday.Wednesday));
    }

    [Fact]
    public void RoundTrip_Json_WrapperVariant()
    {
        var original = JsonValue.WrapString("hello");
        string json = JsonValue.Serializer.ToJson(original);
        var decoded = JsonValue.Serializer.FromJson(json);
        Assert.Equal(original, decoded);
    }

    [Fact]
    public void RoundTrip_Bytes_ConstantVariant()
    {
        var original = Weekday.Friday;
        byte[] bytes = Weekday.Serializer.ToBytes(original);
        var decoded = Weekday.Serializer.FromBytes(bytes);
        Assert.Equal(original, decoded);
        Assert.True(ReferenceEquals(decoded, Weekday.Friday));
    }

    [Fact]
    public void RoundTrip_Bytes_WrapperVariant()
    {
        var original = JsonValue.WrapNumber(42.0);
        byte[] bytes = JsonValue.Serializer.ToBytes(original);
        var decoded = JsonValue.Serializer.FromBytes(bytes);
        Assert.Equal(original, decoded);
    }

    [Fact]
    public void RoundTrip_Json_NestedWrapperVariant()
    {
        var pair = new JsonValue_Pair { Name = "key", Value = JsonValue.WrapBoolean(false) };
        var original = JsonValue.WrapObject([pair]);
        string json = JsonValue.Serializer.ToJson(original);
        var decoded = JsonValue.Serializer.FromJson(json);
        Assert.Equal(JsonValue.KindType.ObjectWrapper, decoded.Kind);
        var obj = decoded.AsObject();
        var entry = Assert.Single(obj);
        Assert.Equal("key", entry.Name);
        Assert.Equal(JsonValue.WrapBoolean(false), entry.Value);
    }

    // =========================================================================
    // Visitor helpers
    // =========================================================================

    private sealed class WeekdayNameVisitor : Weekday.IVisitor<string>
    {
        public string OnUnknown() => "Unknown";
        public string OnMonday() => "Monday";
        public string OnTuesday() => "Tuesday";
        public string OnWednesday() => "Wednesday";
        public string OnThursday() => "Thursday";
        public string OnFriday() => "Friday";
        public string OnSaturday() => "Saturday";
        public string OnSunday() => "Sunday";
    }

    private sealed class JsonValueKindVisitor : JsonValue.IVisitor<string>
    {
        public string OnUnknown() => "unknown";
        public string OnNull() => "null";
        public string OnBoolean(bool value) => $"boolean:{value}";
        public string OnNumber(double value) => $"number:{value}";
        public string OnString(string value) => $"string:{value}";
        public string OnArray(ImmutableArray<JsonValue> value) => $"array[{value.Length}]";
        public string OnObject(ImmutableArray<JsonValue_Pair> value) => $"object[{value.Length}]";
    }
}
