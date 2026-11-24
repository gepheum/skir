using SkirClient;
using Skirout_Enums;
using Skirout_Structs;

namespace SkirClientTest;

public sealed class StructKeyedArrayTests
{
    [Fact]
    public void FindByKey_ReturnsMatchingItem_AndNullWhenMissing()
    {
        Item alpha = CreateItem(boolValue: true, stringValue: "alpha", int32Value: 1);
        Item beta = CreateItem(boolValue: false, stringValue: "beta", int32Value: 2);
        Items items = Items.Default with
        {
            ArrayWithStringKey = [alpha, beta],
        };

        Assert.Equal(beta, items.ArrayWithStringKey_FindByString("beta"));
        Assert.Null(items.ArrayWithStringKey_FindByString("missing"));
    }

    [Fact]
    public void FindByKeyOrDefault_ReturnsDefaultWhenMissing()
    {
        Item alpha = CreateItem(boolValue: true, stringValue: "alpha", int32Value: 1);
        Items items = Items.Default with
        {
            ArrayWithStringKey = [alpha],
        };

        Assert.Equal(alpha, items.ArrayWithStringKey_FindByStringOrDefault("alpha"));
        Assert.Equal(Item.Default, items.ArrayWithStringKey_FindByStringOrDefault("missing"));
    }

    private static Item CreateItem(bool boolValue, string stringValue, int int32Value)
    {
        return Item.Default with
        {
            Bool = boolValue,
            String = stringValue,
            Int32 = int32Value,
            Int64 = int32Value,
            User = Item_User.Default with { Id = $"user-{stringValue}" },
            Weekday = Weekday.Monday,
            Bytes = ImmutableBytes.Empty,
            Timestamp = DateTimeOffset.UnixEpoch.AddSeconds(int32Value),
            OtherString = $"other-{stringValue}",
        };
    }
}