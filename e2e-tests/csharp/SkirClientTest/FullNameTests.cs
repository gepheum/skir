using Skirout_FullName;

namespace SkirClientTest;

/// <summary>
/// Smoke test for the generated <see cref="FullName"/> struct.
/// Ensures struct-init syntax and the Serializer property compile and work.
/// </summary>
public sealed class FullNameTests
{
    [Fact]
    public void StructInitSyntax()
    {
        FullName name = new() { FirstName = "John", LastName = "Doe" };
        Assert.Equal("John", name.FirstName);
        Assert.Equal("Doe", name.LastName);
    }

    [Fact]
    public void RoundTrip_Json()
    {
        FullName name = new() { FirstName = "John", LastName = "Doe" };
        string json = FullName.Serializer.ToJson(name);
        FullName decoded = FullName.Serializer.FromJson(json);
        Assert.Equal(name, decoded);
    }

    [Fact]
    public void ModifiedCopyWithWith()
    {
        FullName name = new() { FirstName = "John", LastName = "Doe" };
        FullName otherName = name with { LastName = "Smith" };
        Assert.Equal("John", otherName.FirstName);
        Assert.Equal("Smith", otherName.LastName);
    }

    [Fact]
    public void ModifiedCopyWithWithOnDefault()
    {
        FullName otherName = FullName.Default with { LastName = "Smith" };
        Assert.Equal("", otherName.FirstName);
        Assert.Equal("Smith", otherName.LastName);
    }

    [Fact]
    public void ToString_ReturnsReadableJson()
    {
        FullName name = new() { FirstName = "John", LastName = "Doe" };
        Assert.Equal("{\n  \"first_name\": \"John\",\n  \"last_name\": \"Doe\"\n}", name.ToString());
    }

    [Fact]
    public void ToString_DefaultOmitsFields()
    {
        Assert.Equal("{}", FullName.Default.ToString());
    }
}
