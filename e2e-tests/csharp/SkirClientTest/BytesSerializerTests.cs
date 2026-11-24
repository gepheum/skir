using SkirClient;

namespace SkirClientTest;

/// <summary>
/// Unit tests for <see cref="Serializers.Bytes"/>, mirroring the Rust
/// bytes_serializer tests in serializers.rs (including base64 / hex helpers).
/// </summary>
public sealed class BytesSerializerTests
{
    private static Serializer<ImmutableBytes> S => Serializers.Bytes;

    private static ImmutableBytes B(params byte[] bytes) => ImmutableBytes.CopyFrom(bytes);

    // =========================================================================
    // Base64 helpers (tested via ToJson / FromJson in dense mode)
    // =========================================================================

    [Fact]
    public void Base64_Encode_Hello()
    {
        Assert.Equal("\"aGVsbG8=\"", S.ToJson(B(0x68, 0x65, 0x6C, 0x6C, 0x6F)));
    }

    [Fact]
    public void Base64_Encode_Empty()
    {
        Assert.Equal("\"\"", S.ToJson(ImmutableBytes.Empty));
    }

    [Fact]
    public void Base64_Decode_Hello()
    {
        Assert.Equal(B(0x68, 0x65, 0x6C, 0x6C, 0x6F), S.FromJson("\"aGVsbG8=\""));
    }

    [Fact]
    public void Base64_RoundTrip()
    {
        ImmutableBytes[] samples = [
            ImmutableBytes.Empty,
            B(0x61),
            B(0x61, 0x62),
            B(0x61, 0x62, 0x63),
            B("hello world"u8.ToArray()),
        ];
        foreach (var data in samples)
        {
            var json = S.ToJson(data, readable: false);
            Assert.Equal(data, S.FromJson(json));
        }
    }

    // =========================================================================
    // Hex helpers (tested via ToJson / FromJson in readable mode and "hex:" prefix)
    // =========================================================================

    [Fact]
    public void Hex_Encode_Hello()
    {
        Assert.Equal("\"hex:68656c6c6f\"",
            S.ToJson(B("hello"u8.ToArray()), readable: true));
    }

    [Fact]
    public void Hex_RoundTrip()
    {
        ImmutableBytes[] samples = [ImmutableBytes.Empty, B(0x00, 0xFF), B("hello"u8.ToArray())];
        foreach (var data in samples)
        {
            var json = S.ToJson(data, readable: true);  // "hex:..."
            Assert.Equal(data, S.FromJson(json));
        }
    }

    // =========================================================================
    // ToJson
    // =========================================================================

    [Fact]
    public void ToJson_Dense_Base64()
    {
        Assert.Equal("\"aGVsbG8=\"", S.ToJson(B("hello"u8.ToArray())));
    }

    [Fact]
    public void ToJson_Readable_Hex()
    {
        Assert.Equal("\"hex:68656c6c6f\"", S.ToJson(B("hello"u8.ToArray()), readable: true));
    }

    [Fact]
    public void ToJson_Empty_Dense()
    {
        Assert.Equal("\"\"", S.ToJson(ImmutableBytes.Empty));
    }

    // =========================================================================
    // FromJson
    // =========================================================================

    [Fact]
    public void FromJson_Base64()
    {
        Assert.Equal(B("hello"u8.ToArray()), S.FromJson("\"aGVsbG8=\""));
    }

    [Fact]
    public void FromJson_Hex()
    {
        Assert.Equal(B("hello"u8.ToArray()), S.FromJson("\"hex:68656c6c6f\""));
    }

    [Fact]
    public void FromJson_Number_IsEmpty()
    {
        Assert.Equal(ImmutableBytes.Empty, S.FromJson("0"));
    }

    [Fact]
    public void FromJson_Null_IsEmpty()
    {
        Assert.Equal(ImmutableBytes.Empty, S.FromJson("null"));
    }

    // =========================================================================
    // Binary encoding
    // =========================================================================

    [Fact]
    public void Encode_Empty_IsWire244()
    {
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0xF4 }, S.ToBytes(ImmutableBytes.Empty));
    }

    [Fact]
    public void Encode_NonEmpty()
    {
        // wire 245 + length (0x03) + raw bytes [1, 2, 3]
        var bytes = S.ToBytes(B(1, 2, 3));
        Assert.Equal(new byte[] { 0xF5, 0x03, 1, 2, 3 }, bytes[4..]);
    }

    [Fact]
    public void Binary_RoundTrip()
    {
        var longBytes = new byte[300];
        System.Array.Fill(longBytes, (byte)0xFF);
        ImmutableBytes[] samples = [
            ImmutableBytes.Empty,
            B(0x00),
            B("hello"u8.ToArray()),
            B(longBytes),
        ];
        foreach (var data in samples)
        {
            Assert.Equal(data, S.FromBytes(S.ToBytes(data)));
        }
    }

    // =========================================================================
    // TypeDescriptor
    // =========================================================================

    [Fact]
    public void TypeDescriptor_IsBytes()
    {
        var td = S.TypeDescriptor;
        var primitive = Assert.IsType<PrimitiveDescriptor>(td);
        Assert.Equal(PrimitiveType.Bytes, primitive.PrimitiveType);
    }
}
