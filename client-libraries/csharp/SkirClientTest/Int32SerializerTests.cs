using SkirClient;

namespace SkirClientTest;

/// <summary>
/// Unit tests for <see cref="Serializers.Int32"/>, mirroring the Rust
/// int32_serializer tests in serializers.rs.
/// </summary>
public sealed class Int32SerializerTests
{
    private static Serializer<int> S => Serializers.Int32;

    // =========================================================================
    // ToJson
    // =========================================================================

    [Fact]
    public void ToJson_Zero()
    {
        Assert.Equal("0", S.ToJson(0));
    }

    [Fact]
    public void ToJson_Positive()
    {
        Assert.Equal("42", S.ToJson(42));
    }

    [Fact]
    public void ToJson_Negative()
    {
        Assert.Equal("-1", S.ToJson(-1));
    }

    [Fact]
    public void ToJson_SameInReadableMode()
    {
        Assert.Equal(S.ToJson(12345, readable: false), S.ToJson(12345, readable: true));
    }

    // =========================================================================
    // FromJson
    // =========================================================================

    [Fact]
    public void FromJson_Integer()
    {
        Assert.Equal(42, S.FromJson("42"));
        Assert.Equal(-1, S.FromJson("-1"));
        Assert.Equal(0, S.FromJson("0"));
    }

    [Fact]
    public void FromJson_FloatTruncates()
    {
        Assert.Equal(3, S.FromJson("3.9"));
        Assert.Equal(-1, S.FromJson("-1.5"));
    }

    [Fact]
    public void FromJson_String()
    {
        Assert.Equal(7, S.FromJson("\"7\""));
    }

    [Fact]
    public void FromJson_UnparseableStringIsZero()
    {
        Assert.Equal(0, S.FromJson("\"abc\""));
    }

    [Fact]
    public void FromJson_NullIsZero()
    {
        Assert.Equal(0, S.FromJson("null"));
    }

    // =========================================================================
    // Binary encoding
    // =========================================================================

    [Fact]
    public void Encode_SmallPositive_IsSingleByte()
    {
        // 0..=231 encoded as the value itself
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0x00 }, S.ToBytes(0));
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0x01 }, S.ToBytes(1));
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0xe7 }, S.ToBytes(231));
    }

    [Fact]
    public void Encode_U16Range()
    {
        // 232..65535 → wire 232 + u16 LE; 1000 = 0x03E8
        var bytes = S.ToBytes(1000);
        Assert.Equal(new byte[] { 232, 232, 3 }, bytes[4..]);
    }

    [Fact]
    public void Encode_U32Range()
    {
        // >= 65536 → wire 233 + u32 LE
        var bytes = S.ToBytes(65536);
        Assert.Equal(new byte[] { 233, 0, 0, 1, 0 }, bytes[4..]);
    }

    [Fact]
    public void Encode_SmallNegative()
    {
        // -256..-1 → wire 235 + u8(v+256)
        var bytes = S.ToBytes(-1);
        Assert.Equal(new byte[] { 235, 255 }, bytes[4..]);
    }

    [Fact]
    public void Encode_MediumNegative()
    {
        // -65536..-257 → wire 236 + u16 LE
        // -300 + 65536 = 65236 = 0xFED4 → [0xD4, 0xFE]
        var bytes = S.ToBytes(-300);
        Assert.Equal(new byte[] { 236, 0xD4, 0xFE }, bytes[4..]);
    }

    [Fact]
    public void Encode_LargeNegative()
    {
        // < -65536 → wire 237 + i32 LE
        var bytes = S.ToBytes(-100_000);
        Assert.Equal(new byte[] { 237, 96, 121, 254, 255 }, bytes[4..]);
    }

    [Fact]
    public void Binary_RoundTrip()
    {
        foreach (var v in new[] { 0, 1, 42, 231, 232, 300, 65535, 65536, int.MaxValue, -1, -255, -256, -65536, int.MinValue })
        {
            Assert.Equal(v, S.FromBytes(S.ToBytes(v)));
        }
    }

    // =========================================================================
    // TypeDescriptor
    // =========================================================================

    [Fact]
    public void TypeDescriptor_IsInt32()
    {
        var td = S.TypeDescriptor;
        var primitive = Assert.IsType<PrimitiveDescriptor>(td);
        Assert.Equal(PrimitiveType.Int32, primitive.PrimitiveType);
    }
}
