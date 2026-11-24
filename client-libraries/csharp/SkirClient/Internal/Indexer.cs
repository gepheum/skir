using System.Collections.Immutable;

namespace SkirClient.Internal;

public sealed class Indexer<TValue, TKey> where TKey : notnull
{
    private readonly Func<TValue, TKey> _keySelector;
    private readonly Dictionary<ImmutableArray<TValue>, ImmutableDictionary<TKey, int>> _cache = [];
    private readonly System.Threading.Lock _mutex = new();

    /// <summary>Creates an indexer using <paramref name="keySelector"/> as key projection.</summary>
    public Indexer(Func<TValue, TKey> keySelector)
    {
        _keySelector = keySelector ?? throw new ArgumentNullException(nameof(keySelector));
    }

    /// <summary>
    /// Returns a map from key to element index for the provided array.
    /// </summary>
    public ImmutableDictionary<TKey, int> Index(ImmutableArray<TValue> values)
    {
        lock (_mutex)
        {
            if (_cache.TryGetValue(values, out var cached))
            {
                return cached;
            }

            var map = BuildIndex(values);
            _cache[values] = map;
            return map;
        }
    }

    private ImmutableDictionary<TKey, int> BuildIndex(ImmutableArray<TValue> values)
    {
        var builder = ImmutableDictionary.CreateBuilder<TKey, int>();
        for (int i = 0; i < values.Length; i++)
        {
            builder[_keySelector(values[i])] = i;
        }

        return builder.ToImmutable();
    }
}