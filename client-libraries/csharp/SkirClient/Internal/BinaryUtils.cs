namespace SkirClient.Internal;

internal static class BinaryUtils
{
    internal static byte ReadU8(byte[] data, ref int offset)
    {
        if (offset >= data.Length)
            throw new InvalidOperationException("Unexpected end of input");
        return data[offset++];
    }

    internal static ushort ReadU16(byte[] data, ref int offset)
    {
        if (offset + 2 > data.Length)
            throw new InvalidOperationException("Unexpected end of input");
        ushort value = BitConverter.ToUInt16(data, offset);
        offset += 2;
        return value;
    }

    internal static uint ReadU32(byte[] data, ref int offset)
    {
        if (offset + 4 > data.Length)
            throw new InvalidOperationException("Unexpected end of input");
        uint value = BitConverter.ToUInt32(data, offset);
        offset += 4;
        return value;
    }

    internal static ulong ReadU64(byte[] data, ref int offset)
    {
        if (offset + 8 > data.Length)
            throw new InvalidOperationException("Unexpected end of input");
        ulong value = BitConverter.ToUInt64(data, offset);
        offset += 8;
        return value;
    }

    private static long DecodeNumberBody(byte wire, byte[] data, ref int offset)
    {
        return wire switch
        {
            <= 231 => wire,
            232 => ReadU16(data, ref offset),
            233 => ReadU32(data, ref offset),
            234 => (long)ReadU64(data, ref offset),
            235 => ReadU8(data, ref offset) - 256L,
            236 => ReadU16(data, ref offset) - 65536L,
            237 => (int)ReadU32(data, ref offset),
            238 or 239 => (long)ReadU64(data, ref offset),
            240 => ReadU32(data, ref offset),
            241 => (long)ReadU64(data, ref offset),
            _ => 0,
        };
    }

    internal static long DecodeNumber(byte[] data, ref int offset)
    {
        byte wire = ReadU8(data, ref offset);
        return DecodeNumberBody(wire, data, ref offset);
    }

    // Returns bytes in little-endian order regardless of host endianness.
    internal static byte[] LE(byte[] bytes)
    {
        if (!BitConverter.IsLittleEndian) System.Array.Reverse(bytes);
        return bytes;
    }

    // Encodes a non-negative length using the skir variable-length uint32 scheme.
    //   0..=231     → single byte
    //   232..=65535 → wire 232 + u16 LE
    //   else        → wire 233 + u32 LE
    internal static void EncodeUint32(uint n, List<byte> output)
    {
        if (n <= 231) { output.Add((byte)n); }
        else if (n <= 65535) { output.Add(232); output.AddRange(LE(BitConverter.GetBytes((ushort)n))); }
        else { output.Add(233); output.AddRange(LE(BitConverter.GetBytes(n))); }
    }

    internal static void SkipValue(byte[] data, ref int offset)
    {
        if (offset >= data.Length)
            return;

        byte wire = ReadU8(data, ref offset);
        if (wire <= 231)
            return;

        switch (wire)
        {
            case 232:
                offset += 2;
                return;
            case 233:
                offset += 4;
                return;
            case 234:
            case 238:
            case 239:
                offset += 8;
                return;
            case 235:
                offset += 1;
                return;
            case 236:
                offset += 2;
                return;
            case 237:
                offset += 4;
                return;
            case 240:
                offset += 4;
                return;
            case 241:
                offset += 8;
                return;
            case 242:
            case 244:
            case 246:
                return;
            case 243:
            case 245:
                {
                    long n = DecodeNumber(data, ref offset);
                    if (n > 0)
                        offset += (int)n;
                    return;
                }
            case 247:
            case 251:
            case 252:
            case 253:
            case 254:
                SkipValue(data, ref offset);
                return;
            case 248:
                _ = DecodeNumber(data, ref offset);
                SkipValue(data, ref offset);
                return;
            case 249:
                SkipValue(data, ref offset);
                SkipValue(data, ref offset);
                SkipValue(data, ref offset);
                return;
            case 250:
                {
                    long count = DecodeNumber(data, ref offset);
                    for (long i = 0; i < count; i++)
                        SkipValue(data, ref offset);
                    return;
                }
            default:
                return;
        }
    }
}
