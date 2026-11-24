using SkirClient;

namespace SkirClientTest;

/// <summary>
/// Unit tests for <see cref="Serializers.Bool"/>, mirroring the Rust
/// bool-serializer tests in serializers.rs (lines 1551–1631).
/// </summary>
public sealed class BoolSerializerTests
{
    private static Serializer<bool> S => Serializers.Bool;

    // =========================================================================
    // ToJson
    // =========================================================================

    [Fact]
    public void ToJson_Dense_True()
    {
        Assert.Equal("1", S.ToJson(true, readable: false));
    }

    [Fact]
    public void ToJson_Dense_False()
    {
        Assert.Equal("0", S.ToJson(false, readable: false));
    }

    [Fact]
    public void ToJson_Readable_True()
    {
        Assert.Equal("true", S.ToJson(true, readable: true));
    }

    [Fact]
    public void ToJson_Readable_False()
    {
        Assert.Equal("false", S.ToJson(false, readable: true));
    }

    // =========================================================================
    // FromJson
    // =========================================================================

    [Fact]
    public void FromJson_BoolLiteral_True()
    {
        Assert.True(S.FromJson("true"));
    }

    [Fact]
    public void FromJson_BoolLiteral_False()
    {
        Assert.False(S.FromJson("false"));
    }

    [Fact]
    public void FromJson_Number1_IsTrue()
    {
        Assert.True(S.FromJson("1"));
    }

    [Fact]
    public void FromJson_Number0_IsFalse()
    {
        Assert.False(S.FromJson("0"));
    }

    [Fact]
    public void FromJson_NumberNonzero_IsTrue()
    {
        Assert.True(S.FromJson("42"));
    }

    [Fact]
    public void FromJson_FloatZero_IsFalse()
    {
        Assert.False(S.FromJson("0.0"));
    }

    [Fact]
    public void FromJson_String0_IsFalse()
    {
        Assert.False(S.FromJson("\"0\""));
    }

    [Fact]
    public void FromJson_String1_IsTrue()
    {
        Assert.True(S.FromJson("\"1\""));
    }

    [Fact]
    public void FromJson_StringTrue_IsTrue()
    {
        // The string literal "true" (not the JSON bool true) is truthy
        // because it is not equal to "0".
        Assert.True(S.FromJson("\"true\""));
    }

    [Fact]
    public void FromJson_StringFalse_IsTrue()
    {
        // The string literal "false" (not the JSON bool false) is truthy
        // because it is not equal to "0".
        Assert.True(S.FromJson("\"false\""));
    }

    // =========================================================================
    // Binary encoding / decoding
    // =========================================================================

    [Fact]
    public void Binary_RoundTrip_True()
    {
        var bytes = S.ToBytes(true);
        Assert.True(S.FromBytes(bytes));
    }

    [Fact]
    public void Binary_RoundTrip_False()
    {
        var bytes = S.ToBytes(false);
        Assert.False(S.FromBytes(bytes));
    }

    [Fact]
    public void Binary_Encoding_True_Is_SkirtThen1()
    {
        // Expected: "skir" magic prefix (0x73 0x6B 0x69 0x72) followed by 0x01.
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0x01 }, S.ToBytes(true));
    }

    [Fact]
    public void Binary_Encoding_False_Is_SkirThen0()
    {
        // Expected: "skir" magic prefix (0x73 0x6B 0x69 0x72) followed by 0x00.
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0x00 }, S.ToBytes(false));
    }

    // =========================================================================
    // TypeDescriptor
    // =========================================================================

    [Fact]
    public void TypeDescriptor_IsBool()
    {
        var td = S.TypeDescriptor;
        var primitive = Assert.IsType<PrimitiveDescriptor>(td);
        Assert.Equal(PrimitiveType.Bool, primitive.PrimitiveType);
    }
}
