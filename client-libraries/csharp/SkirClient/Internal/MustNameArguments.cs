namespace SkirClient.Internal;

/// <summary>
/// Marker parameter used to nudge callers toward naming trailing optional arguments.
/// </summary>
public readonly struct MustNameArguments
{
    private MustNameArguments(int _) { }
}
