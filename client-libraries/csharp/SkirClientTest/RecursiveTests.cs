using SkirClient;

namespace SkirClientTest;

public sealed class RecursiveTests
{
    [Fact]
    public void Default_HasNoValue()
    {
        var recursive = Recursive<int>.Default;
        Assert.False(recursive.HasValue);
    }

    [Fact]
    public void Default_ThrowsWhenAccessingValue()
    {
        var recursive = Recursive<int>.Default;
        Assert.Throws<InvalidOperationException>(() => recursive.Value);
    }

    [Fact]
    public void FromValue_CreatesInstanceWithValue()
    {
        var recursive = Recursive<int>.FromValue(42);
        Assert.True(recursive.HasValue);
        Assert.Equal(42, recursive.Value);
    }

    [Fact]
    public void FromValue_WithReferenceType_CreatesInstanceWithValue()
    {
        var value = "test";
        var recursive = Recursive<string>.FromValue(value);
        Assert.True(recursive.HasValue);
        Assert.Equal("test", recursive.Value);
    }

    [Fact]
    public void FromValue_WithNull_ThrowsArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(() => Recursive<string>.FromValue(null!));
    }

    [Fact]
    public void Equals_DefaultToDefault_ReturnsTrue()
    {
        var recursive1 = Recursive<int>.Default;
        var recursive2 = Recursive<int>.Default;
        Assert.Equal(recursive1, recursive2);
    }

    [Fact]
    public void Equals_SameValue_ReturnsTrue()
    {
        var recursive1 = Recursive<int>.FromValue(42);
        var recursive2 = Recursive<int>.FromValue(42);
        Assert.Equal(recursive1, recursive2);
    }

    [Fact]
    public void Equals_DifferentValues_ReturnsFalse()
    {
        var recursive1 = Recursive<int>.FromValue(42);
        var recursive2 = Recursive<int>.FromValue(43);
        Assert.NotEqual(recursive1, recursive2);
    }

    [Fact]
    public void Equals_DefaultToValue_ReturnsFalse()
    {
        var recursive1 = Recursive<int>.Default;
        var recursive2 = Recursive<int>.FromValue(42);
        Assert.NotEqual(recursive1, recursive2);
    }

    [Fact]
    public void GetHashCode_DefaultIsConsistent()
    {
        var recursive1 = Recursive<int>.Default;
        var recursive2 = Recursive<int>.Default;
        Assert.Equal(recursive1.GetHashCode(), recursive2.GetHashCode());
    }

    [Fact]
    public void GetHashCode_SameValue_ReturnsSameHash()
    {
        var recursive1 = Recursive<int>.FromValue(42);
        var recursive2 = Recursive<int>.FromValue(42);
        Assert.Equal(recursive1.GetHashCode(), recursive2.GetHashCode());
    }

    [Fact]
    public void ToString_Default_ReturnsEmptyString()
    {
        var recursive = Recursive<int>.Default;
        Assert.Equal("", recursive.ToString());
    }

    [Fact]
    public void ToString_WithValue_ReturnsValueString()
    {
        var recursive = Recursive<int>.FromValue(42);
        Assert.Equal("42", recursive.ToString());
    }

    [Fact]
    public void ToString_WithStringValue_ReturnsValueString()
    {
        var recursive = Recursive<string>.FromValue("hello");
        Assert.Equal("hello", recursive.ToString());
    }

    [Fact]
    public void Value_CanBeRepeatedlyAccessed()
    {
        var recursive = Recursive<int>.FromValue(100);
        var value1 = recursive.Value;
        var value2 = recursive.Value;
        Assert.Equal(value1, value2);
        Assert.Equal(100, value1);
    }

    [Fact]
    public void HasValue_TrueForFromValue_FalseForDefault()
    {
        var withValue = Recursive<int>.FromValue(50);
        var withoutValue = Recursive<int>.Default;
        
        Assert.True(withValue.HasValue);
        Assert.False(withoutValue.HasValue);
    }

    [Fact]
    public void NestedRecursive_WorksCorrectly()
    {
        var innerRecursive = Recursive<int>.FromValue(42);
        var outerRecursive = Recursive<Recursive<int>>.FromValue(innerRecursive);
        
        Assert.True(outerRecursive.HasValue);
        Assert.True(outerRecursive.Value.HasValue);
        Assert.Equal(42, outerRecursive.Value.Value);
    }
}
