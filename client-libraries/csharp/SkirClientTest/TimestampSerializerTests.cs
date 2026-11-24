using SkirClient;

namespace SkirClientTest;

/// <summary>
/// Unit tests for <see cref="Serializers.Timestamp"/>, mirroring the Rust
/// timestamp_serializer tests in serializers.rs.
/// </summary>
public sealed class TimestampSerializerTests
{
    private static Serializer<DateTimeOffset> S => Serializers.Timestamp;

    // Helper mirrors the Rust millis_to_system_time helper.
    private static DateTimeOffset Ms(long ms) =>
        DateTimeOffset.FromUnixTimeMilliseconds(ms);

    // =========================================================================
    // millis_to_iso8601 (internal helper, tested via ToJson readable)
    // =========================================================================

    [Fact]
    public void MillisToIso8601_Epoch()
    {
        // The readable JSON contains the formatted field; test it via ToJson.
        var json = S.ToJson(DateTimeOffset.UnixEpoch, readable: true);
        Assert.Contains("\"formatted\": \"1970-01-01T00:00:00.000Z\"", json);
    }

    [Fact]
    public void MillisToIso8601_KnownDate()
    {
        var json = S.ToJson(Ms(1_234_567_890_000), readable: true);
        Assert.Contains("\"formatted\": \"2009-02-13T23:31:30.000Z\"", json);
    }

    [Fact]
    public void MillisToIso8601_Milliseconds()
    {
        var json = S.ToJson(Ms(1_234_567_890_123), readable: true);
        Assert.Contains("\"formatted\": \"2009-02-13T23:31:30.123Z\"", json);
    }

    [Fact]
    public void MillisToIso8601_Negative()
    {
        // -1000 ms = 1969-12-31T23:59:59.000Z
        var json = S.ToJson(Ms(-1000), readable: true);
        Assert.Contains("\"formatted\": \"1969-12-31T23:59:59.000Z\"", json);
    }

    // =========================================================================
    // ToJson
    // =========================================================================

    [Fact]
    public void ToJson_Dense_Epoch()
    {
        Assert.Equal("0", S.ToJson(DateTimeOffset.UnixEpoch));
    }

    [Fact]
    public void ToJson_Dense_NonZero()
    {
        Assert.Equal("1234567890000", S.ToJson(Ms(1_234_567_890_000)));
    }

    [Fact]
    public void ToJson_Readable()
    {
        var ts = Ms(1_234_567_890_000);
        const string Expected =
            "{\n  \"unix_millis\": 1234567890000,\n  \"formatted\": \"2009-02-13T23:31:30.000Z\"\n}";
        Assert.Equal(Expected, S.ToJson(ts, readable: true));
    }

    // =========================================================================
    // FromJson
    // =========================================================================

    [Fact]
    public void FromJson_Number()
    {
        Assert.Equal(Ms(1_234_567_890_000), S.FromJson("1234567890000"));
    }

    [Fact]
    public void FromJson_String()
    {
        Assert.Equal(Ms(1_234_567_890_000), S.FromJson("\"1234567890000\""));
    }

    [Fact]
    public void FromJson_Object_Readable()
    {
        const string Json =
            "{\"unix_millis\": 1234567890000, \"formatted\": \"2009-02-13T23:31:30.000Z\"}";
        Assert.Equal(Ms(1_234_567_890_000), S.FromJson(Json));
    }

    [Fact]
    public void FromJson_Null_IsEpoch()
    {
        Assert.Equal(DateTimeOffset.UnixEpoch, S.FromJson("null"));
    }

    // =========================================================================
    // Binary encoding
    // =========================================================================

    [Fact]
    public void Encode_Epoch_IsSingleByteZero()
    {
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0x00 },
            S.ToBytes(DateTimeOffset.UnixEpoch));
    }

    [Fact]
    public void Encode_NonZero_IsWire239()
    {
        var ts = Ms(1_234_567_890_000);
        var bytes = S.ToBytes(ts);
        Assert.Equal(239, bytes[4]);
        Assert.Equal(BitConverter.GetBytes(1_234_567_890_000L), bytes[5..]);
    }

    [Fact]
    public void Binary_RoundTrip()
    {
        foreach (var ms in new long[] { 0L, 1L, 1_234_567_890_000L, -1000L })
        {
            var ts = Ms(ms);
            Assert.Equal(ts, S.FromBytes(S.ToBytes(ts)));
        }
    }

    // =========================================================================
    // TypeDescriptor
    // =========================================================================

    [Fact]
    public void TypeDescriptor_IsTimestamp()
    {
        var td = S.TypeDescriptor;
        var primitive = Assert.IsType<PrimitiveDescriptor>(td);
        Assert.Equal(PrimitiveType.Timestamp, primitive.PrimitiveType);
    }
}
