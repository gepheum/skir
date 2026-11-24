using SkirClient;

namespace SkirClientTest;

public sealed class ImmutableBytesTests
{
    [Fact]
    public void Empty_IsEmptyAndLengthZero()
    {
        Assert.True(ImmutableBytes.Empty.IsEmpty);
        Assert.Equal(0, ImmutableBytes.Empty.Length);
        Assert.Empty(ImmutableBytes.Empty.ToArray());
    }

    [Fact]
    public void Default_EqualsEmpty()
    {
        ImmutableBytes value = default;
        Assert.Equal(ImmutableBytes.Empty, value);
        Assert.True(value.IsEmpty);
        Assert.Equal(0, value.Length);
    }

    [Fact]
    public void CopyFrom_Array_ThrowsOnNull()
    {
        Assert.Throws<ArgumentNullException>(() => ImmutableBytes.CopyFrom((byte[])null!));
    }

    [Fact]
    public void CopyFrom_Array_CopiesInput()
    {
        var source = new byte[] { 1, 2, 3 };
        var immutable = ImmutableBytes.CopyFrom(source);

        source[0] = 9;

        Assert.Equal(new byte[] { 1, 2, 3 }, immutable.ToArray());
    }

    [Fact]
    public void CopyFrom_Span_CopiesInput()
    {
        var source = new byte[] { 4, 5, 6 };
        var immutable = ImmutableBytes.CopyFrom(source.AsSpan());

        source[1] = 9;

        Assert.Equal(new byte[] { 4, 5, 6 }, immutable.ToArray());
    }

    [Fact]
    public void ToArray_ReturnsCopy()
    {
        var immutable = ImmutableBytes.CopyFrom(new byte[] { 7, 8, 9 });

        var copy = immutable.ToArray();
        copy[0] = 0;

        Assert.Equal(new byte[] { 7, 8, 9 }, immutable.ToArray());
    }

    [Fact]
    public void Indexer_ReadsExpectedByte()
    {
        var immutable = ImmutableBytes.CopyFrom(new byte[] { 10, 11, 12 });

        Assert.Equal((byte)10, immutable[0]);
        Assert.Equal((byte)12, immutable[2]);
    }

    [Fact]
    public void Enumerator_YieldsBytesInOrder()
    {
        var immutable = ImmutableBytes.CopyFrom(new byte[] { 1, 3, 5, 7 });

        Assert.Equal(new byte[] { 1, 3, 5, 7 }, immutable);
    }

    [Fact]
    public void Equality_AndHashCode_AreValueBased()
    {
        var a = ImmutableBytes.CopyFrom(new byte[] { 1, 2, 3 });
        var b = ImmutableBytes.CopyFrom(new byte[] { 1, 2, 3 });
        var c = ImmutableBytes.CopyFrom(new byte[] { 3, 2, 1 });

        Assert.True(a == b);
        Assert.False(a != b);
        Assert.Equal(a, b);
        Assert.Equal(a.GetHashCode(), b.GetHashCode());

        Assert.NotEqual(a, c);
    }

    [Fact]
    public void Span_ReflectsStoredData()
    {
        var immutable = ImmutableBytes.CopyFrom(new byte[] { 42, 43 });

        Assert.Equal((byte)42, immutable.Span[0]);
        Assert.Equal((byte)43, immutable.Span[1]);
    }
}
