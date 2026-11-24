using SkirClient;

namespace SkirClientTest;

/// <summary>
/// Unit tests for <see cref="Serializers.Hash64"/>, mirroring the Rust
/// uint64_serializer tests in serializers.rs.
/// </summary>
public sealed class Hash64SerializerTests
{
    private static Serializer<ulong> S => Serializers.Hash64;

    // =========================================================================
    // ToJson
    // =========================================================================

    [Fact]
    public void ToJson_SafeInteger()
    {
        Assert.Equal("0", S.ToJson(0UL));
        Assert.Equal("9007199254740991", S.ToJson(9_007_199_254_740_991UL));
    }

    [Fact]
    public void ToJson_LargeValueIsQuoted()
    {
        Assert.Equal("\"9007199254740992\"", S.ToJson(9_007_199_254_740_992UL));
        Assert.Equal($"\"{ulong.MaxValue}\"", S.ToJson(ulong.MaxValue));
    }

    // =========================================================================
    // FromJson
    // =========================================================================

    [Fact]
    public void FromJson_Integer()
    {
        Assert.Equal(42UL, S.FromJson("42"));
    }

    [Fact]
    public void FromJson_NegativeNumberIsZero()
    {
        // negative float → clamped to 0
        Assert.Equal(0UL, S.FromJson("-1.0"));
    }

    [Fact]
    public void FromJson_QuotedLarge()
    {
        Assert.Equal(9_007_199_254_740_992UL, S.FromJson("\"9007199254740992\""));
    }

    [Fact]
    public void FromJson_NullIsZero()
    {
        Assert.Equal(0UL, S.FromJson("null"));
    }

    // =========================================================================
    // Binary encoding
    // =========================================================================

    [Fact]
    public void Encode_SingleByteRange()
    {
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0x00 }, S.ToBytes(0UL));
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0xe7 }, S.ToBytes(231UL));
    }

    [Fact]
    public void Encode_U16Range()
    {
        // 232..65535 → wire 232 + u16 LE; 1000 = 0x03E8
        var bytes = S.ToBytes(1000UL);
        Assert.Equal(new byte[] { 232, 232, 3 }, bytes[4..]);
    }

    [Fact]
    public void Encode_U32Range()
    {
        // 65536..4294967295 → wire 233 + u32 LE
        var bytes = S.ToBytes(65536UL);
        Assert.Equal(new byte[] { 233, 0, 0, 1, 0 }, bytes[4..]);
    }

    [Fact]
    public void Encode_U64Range()
    {
        // >= 2^32 → wire 234 + u64 LE
        ulong v = 4_294_967_296UL;
        var bytes = S.ToBytes(v);
        Assert.Equal(234, bytes[4]);
        Assert.Equal(BitConverter.GetBytes(v), bytes[5..]);
    }

    [Fact]
    public void Binary_RoundTrip()
    {
        ulong[] values = [0UL, 1UL, 231UL, 232UL, 65535UL, 65536UL, 4_294_967_295UL, 4_294_967_296UL, ulong.MaxValue];
        foreach (var v in values)
        {
            Assert.Equal(v, S.FromBytes(S.ToBytes(v)));
        }
    }

    // =========================================================================
    // TypeDescriptor
    // =========================================================================

    [Fact]
    public void TypeDescriptor_IsHash64()
    {
        var td = S.TypeDescriptor;
        var primitive = Assert.IsType<PrimitiveDescriptor>(td);
        Assert.Equal(PrimitiveType.Hash64, primitive.PrimitiveType);
    }
}
