using SkirClient;

namespace SkirClientTest;

/// <summary>
/// Unit tests for <see cref="Serializers.Int64"/>, mirroring the Rust
/// int64_serializer tests in serializers.rs.
/// </summary>
public sealed class Int64SerializerTests
{
    private static Serializer<long> S => Serializers.Int64;

    // =========================================================================
    // ToJson
    // =========================================================================

    [Fact]
    public void ToJson_SafeInteger()
    {
        Assert.Equal("0", S.ToJson(0L));
        Assert.Equal("9007199254740991", S.ToJson(9_007_199_254_740_991L));
        Assert.Equal("-9007199254740991", S.ToJson(-9_007_199_254_740_991L));
    }

    [Fact]
    public void ToJson_LargeValueIsQuoted()
    {
        Assert.Equal("\"9007199254740992\"", S.ToJson(9_007_199_254_740_992L));
        Assert.Equal($"\"{long.MaxValue}\"", S.ToJson(long.MaxValue));
    }

    // =========================================================================
    // FromJson
    // =========================================================================

    [Fact]
    public void FromJson_Integer()
    {
        Assert.Equal(42L, S.FromJson("42"));
        Assert.Equal(-1L, S.FromJson("-1"));
    }

    [Fact]
    public void FromJson_QuotedLarge()
    {
        Assert.Equal(9_007_199_254_740_992L, S.FromJson("\"9007199254740992\""));
    }

    [Fact]
    public void FromJson_NullIsZero()
    {
        Assert.Equal(0L, S.FromJson("null"));
    }

    // =========================================================================
    // Binary encoding
    // =========================================================================

    [Fact]
    public void Encode_FitsI32_ReusesI32Encoding()
    {
        // Values in i32 range reuse the int32 wire format
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0x00 }, S.ToBytes(0L));
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0x2a }, S.ToBytes(42L));
    }

    [Fact]
    public void Encode_Wire238()
    {
        // Values outside i32 range → wire 238 + i64 LE
        long v = (long)int.MaxValue + 1;
        var bytes = S.ToBytes(v);
        Assert.Equal(238, bytes[4]);
        Assert.Equal(BitConverter.GetBytes(v), bytes[5..]);
    }

    [Fact]
    public void Binary_RoundTrip()
    {
        long[] values = [0L, 1L, 231L, 232L, 65536L, int.MaxValue, (long)int.MaxValue + 1, long.MaxValue, -1L, int.MinValue, long.MinValue];
        foreach (var v in values)
        {
            Assert.Equal(v, S.FromBytes(S.ToBytes(v)));
        }
    }

    // =========================================================================
    // TypeDescriptor
    // =========================================================================

    [Fact]
    public void TypeDescriptor_IsInt64()
    {
        var td = S.TypeDescriptor;
        var primitive = Assert.IsType<PrimitiveDescriptor>(td);
        Assert.Equal(PrimitiveType.Int64, primitive.PrimitiveType);
    }
}
