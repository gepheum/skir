using System.Text;
using SkirClient;

namespace SkirClientTest;

/// <summary>
/// Unit tests for <see cref="Serializers.String"/>, mirroring the Rust
/// string_serializer tests in serializers.rs.
/// </summary>
public sealed class StringSerializerTests
{
    private static Serializer<string> S => Serializers.String;

    // =========================================================================
    // ToJson
    // =========================================================================

    [Fact]
    public void ToJson_Plain()
    {
        Assert.Equal("\"hello\"", S.ToJson("hello"));
    }

    [Fact]
    public void ToJson_Empty()
    {
        Assert.Equal("\"\"", S.ToJson(""));
    }

    [Fact]
    public void ToJson_EscapesQuoteAndBackslash()
    {
        // say "hi"  →  "say \"hi\""
        Assert.Equal("\"say \\\"hi\\\"\"", S.ToJson("say \"hi\""));
        // a\b  →  "a\\b"
        Assert.Equal("\"a\\\\b\"", S.ToJson("a\\b"));
    }

    [Fact]
    public void ToJson_EscapesControlChars()
    {
        Assert.Equal("\"\\n\\t\\r\"", S.ToJson("\n\t\r"));
    }

    [Fact]
    public void ToJson_SameInReadableMode()
    {
        Assert.Equal(S.ToJson("hello", readable: false), S.ToJson("hello", readable: true));
    }

    [Fact]
    public void ToJson_LoneSurrogate_IsSanitized()
    {
        string invalid = "\ud800";

        Assert.Equal("\"\uFFFD\"", S.ToJson(invalid));

        var strictUtf8 = new UTF8Encoding(false, true);
        byte[] utf8 = strictUtf8.GetBytes(S.ToJson(invalid));
        Assert.Equal("\"�\"", strictUtf8.GetString(utf8));
    }

    // =========================================================================
    // FromJson
    // =========================================================================

    [Fact]
    public void FromJson_String()
    {
        Assert.Equal("hello", S.FromJson("\"hello\""));
    }

    [Fact]
    public void FromJson_Number_IsEmpty()
    {
        Assert.Equal("", S.FromJson("0"));
    }

    [Fact]
    public void FromJson_Null_IsEmpty()
    {
        Assert.Equal("", S.FromJson("null"));
    }

    // =========================================================================
    // Binary encoding
    // =========================================================================

    [Fact]
    public void Encode_Empty_IsWire242()
    {
        Assert.Equal(new byte[] { (byte)'s', (byte)'k', (byte)'i', (byte)'r', 0xF2 },
            S.ToBytes(""));
    }

    [Fact]
    public void Encode_NonEmpty()
    {
        // wire 243 + length (0x02) + UTF-8 bytes 'h','i'
        var bytes = S.ToBytes("hi");
        Assert.Equal(new byte[] { 0xF3, 0x02, (byte)'h', (byte)'i' }, bytes[4..]);
    }

    [Fact]
    public void Binary_RoundTrip()
    {
        foreach (var v in new[] { "", "hello", "emoji: \U0001F600", "quotes: \"x\"" })
        {
            Assert.Equal(v, S.FromBytes(S.ToBytes(v)));
        }
    }

    [Fact]
    public void Encode_LoneSurrogate_UsesReplacementCharacterUtf8()
    {
        string invalid = "\ud800";

        var bytes = S.ToBytes(invalid);

        Assert.Equal(new byte[]
        {
            (byte)'s', (byte)'k', (byte)'i', (byte)'r',
            0xF3, 0x03, 0xEF, 0xBF, 0xBD,
        }, bytes);
        Assert.Equal("�", S.FromBytes(bytes));
    }

    // =========================================================================
    // TypeDescriptor
    // =========================================================================

    [Fact]
    public void TypeDescriptor_IsString()
    {
        var td = S.TypeDescriptor;
        var primitive = Assert.IsType<PrimitiveDescriptor>(td);
        Assert.Equal(PrimitiveType.String, primitive.PrimitiveType);
    }
}
