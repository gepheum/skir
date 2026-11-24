#include "skir.h"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <limits>
#include <string>
#include <type_traits>
#include <utility>
#include <variant>

#include "absl/log/die_if_null.h"
#include "absl/log/log.h"
#include "absl/status/status.h"
#include "absl/strings/ascii.h"
#include "absl/strings/escaping.h"
#include "absl/strings/numbers.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/str_join.h"
#include "absl/strings/str_split.h"
#include "absl/strings/string_view.h"
#include "absl/time/time.h"

namespace skir_internal {
namespace {

inline const char *cast(const uint8_t *ptr) { return (const char *)ptr; }

inline const uint8_t *cast(const char *ptr) { return (const uint8_t *)ptr; }

inline int64_t ClampUnixMillis(int64_t unix_millis) {
  return std::min<int64_t>(std::max<int64_t>(unix_millis, -8640000000000000),
                           8640000000000000);
}

static constexpr char kHexDigits[] = "0123456789ABCDEF";

enum class NullTerminated { kFalse = false, kTrue = true };

namespace copy_utf8_codepoint {
struct ToString {
  template <typename Char> inline static void Push(Char c, std::string &out) {
    out += static_cast<char>(c);
  }
  inline static void PopN(size_t n, std::string &out) {
    out.resize(out.length() - n);
  }
  inline static void OnError(const char *pos, const char *end,
                             size_t continuation_bytes, std::string &out) {
    // Push the replacement character: � (u+FFFD)
    out += "�";
  }
};

struct ToDebugString {
  template <typename Char> inline static void Push(Char c, std::string &out) {
    out += static_cast<char>(c);
  }
  inline static void PopN(size_t n, std::string &out) {
    out.resize(out.length() - n);
  }
  inline static void OnError(const char *pos, const char *end,
                             size_t continuation_bytes, std::string &out) {
    // Escape all the chars in the invalid sequence.
    for (const char *back_pos = pos - continuation_bytes - 1; back_pos < pos;
         ++back_pos) {
      const uint8_t back_byte = static_cast<uint8_t>(*back_pos);
      out += {'\\', 'x', kHexDigits[(back_byte >> 4) & 0x0F],
              kHexDigits[back_byte & 0x0F]};
    }
  }
};

struct ToByteSink {
  template <typename Char> inline static void Push(Char c, ByteSink &out) {
    out.PushUnsafe(static_cast<uint8_t>(c));
  }
  inline static void PopN(size_t n, ByteSink &out) { out.PopN(n); }
  inline static void OnError(const char *pos, const char *end,
                             size_t continuation_bytes, ByteSink &out) {
    // Push the replacement character: � (u+FFFD). It's possible that we need
    // more capacity.
    out.Prepare((end - pos) + 3);
    out.PushUnsafe(0xEF);
    out.PushUnsafe(0xBF);
    out.PushUnsafe(0xBD);
  }
};
} // namespace copy_utf8_codepoint

// Copy the non-ASCII-7 codepoint at pos - 1 to out.
// The first_byte is expected to be greater than 127.
template <typename Sink, NullTerminated kNullTerminated, typename Out>
inline void CopyUtf8Codepoint(uint8_t first_byte, const char *&pos,
                              const char *end, Out &out) {
  // The first byte of the UTF-8 sequence for a non-ASCII-7 codepoint,
  // assuming the input string is a well-formed UTF-8 string.

  // Push byte and all the continuation bytes that follow. If the input
  // string happens to not be a well-formed UTF-8 string, we'll remove the
  // chars we have pushed.
  Sink::Push(first_byte, out);

  // Total number of continuation bytes actually read.
  size_t continuation_bytes = 0;

  // From https://github.com/chansen/c-utf8-valid/blob/master/utf8_valid.h
  uint32_t v = first_byte;

  for (;;) {
    if (kNullTerminated == NullTerminated::kFalse && pos == end) {
      break;
    }
    const uint8_t continuation_byte = static_cast<uint8_t>(*pos);
    if ((continuation_byte & 0xC0) == 0x80) {
      Sink::Push(continuation_byte, out);
      ++continuation_bytes;
      v = (v << 8) | continuation_byte;
      ++pos;
    } else {
      // Not a continuation byte.
      break;
    }
  }

  // Validate the UTF-8 sequence we just read.
  if ((first_byte & 0xE0) == 0xC0) {
    // 1 continuation byte expected
    if (continuation_bytes != 1)
      goto utf8_error;
    // Ensure that the top 4 bits is not zero
    v = v & 0x1E00;
    if (v == 0)
      goto utf8_error;
  } else if ((first_byte & 0xF0) == 0xE0) {
    // 2 continuation bytes expected
    if (continuation_bytes != 2)
      goto utf8_error;
    // Ensure that the top 5 bits is not zero and not a surrogate
    v = v & 0x0F2000;
    if (v == 0 || v == 0x0D2000)
      goto utf8_error;
  } else if ((first_byte & 0xF8) == 0xF0) {
    // 3 continuation bytes expected
    if (continuation_bytes != 3)
      goto utf8_error;
    // Ensure that the top 5 bits is not zero and not out of range
    v = v & 0x07300000;
    if (v == 0 || v > 0x04000000)
      goto utf8_error;
  } else {
    goto utf8_error;
  }

  return;

utf8_error:
  // Remove the last (continuation_bytes + 1) chars from the output.
  Sink::PopN(continuation_bytes + 1, out);
  Sink::OnError(pos, end, continuation_bytes, out);
}

template <NullTerminated kNullTerminated>
inline void EscapeJsonString(const char *pos, const char *end,
                             std::string &out) {
  while (kNullTerminated == NullTerminated::kTrue || pos < end) {
    const uint8_t byte = static_cast<uint8_t>(*pos++);
    if (byte < 0x80) {
      if (byte < 0x20) {
        // A non-printable character.
        switch (byte) {
        case '\0':
          // \0 may indicate the end of the string, but it can also be part of
          // the string's contents.
          if (kNullTerminated == NullTerminated::kTrue && pos > end) {
            // The end of the input string was reached.
            return;
          } else {
            out += {'\\', 'u', '0', '0', '0', '0'};
            break;
          }
        case '\b':
          out += {'\\', 'b'};
          break;
        case '\f':
          out += {'\\', 'f'};
          break;
        case '\n':
          out += {'\\', 'n'};
          break;
        case '\r':
          out += {'\\', 'r'};
          break;
        case '\t':
          out += {'\\', 't'};
          break;
        default:
          out += {'\\',
                  'u',
                  '0',
                  '0',
                  kHexDigits[(byte >> 4) & 0x0F],
                  kHexDigits[byte & 0x0F]};
        }
      } else {
        // A printable character.
        switch (byte) {
        case '"':
          out += {'\\', '"'};
          break;
        case '\\':
          out += {'\\', '\\'};
          break;
        default:
          out += byte;
        }
      }
    } else {
      CopyUtf8Codepoint<copy_utf8_codepoint::ToString, kNullTerminated>(
          byte, pos, end, out);
    }
  }
}

inline void EscapeJsonString(const std::string &input, std::string &out) {
  const char *c_str = input.c_str();
  EscapeJsonString<NullTerminated::kTrue>(c_str, c_str + input.length(), out);
}

inline void CopyUtf8String(const std::string &input, ByteSink &out) {
  const char *input_pos = input.c_str();
  const char *input_end = input_pos + input.length();
  uint8_t *out_pos = out.pos();
  for (;;) {
    const int8_t c = static_cast<int8_t>(*(input_pos++));
    if (c <= 0) {
      if (c == 0) {
        // The input string is guaranteed to end with \0, but \0 can also be
        // found within the string.
        if (input_pos > input_end) {
          // The end of the input string was reached.
          out.set_pos(out_pos);
          return;
        } else {
          *(out_pos++) = 0;
          out.PushUnsafe(0);
        }
      } else {
        out.set_pos(out_pos);
        CopyUtf8Codepoint<copy_utf8_codepoint::ToByteSink,
                          NullTerminated::kTrue>(c, input_pos, input_end, out);
        out_pos = out.pos();
      }
    } else {
      *(out_pos++) = c;
    }
  }
}

inline void EscapeDebugString(const std::string &input, std::string &out) {
  const char *pos = input.c_str();
  const char *input_end = pos + input.length() + 1;
  for (;;) {
    const uint8_t byte = static_cast<uint8_t>(*(pos++));
    if (byte < 0x80) {
      if (byte < 0x20) {
        // A non-printable character.
        switch (byte) {
        case '\0':
          // The input string is guaranteed to end with \0, but \0 can also be
          // found within the string.
          if (pos == input_end) {
            // The end of the input string was reached.
            return;
          } else {
            out += {'\\', '0'};
            break;
          }
        case '\a':
          out += {'\\', 'a'};
          break;
        case '\b':
          out += {'\\', 'b'};
          break;
        case '\f':
          out += {'\\', 'f'};
          break;
        case '\n':
          out += {'\\', 'n'};
          break;
        case '\r':
          out += {'\\', 'r'};
          break;
        case '\t':
          out += {'\\', 't'};
          break;
        case '\v':
          out += {'\\', 'v'};
          break;
        default:
          out += {'\\', 'x', kHexDigits[(byte >> 4) & 0x0F],
                  kHexDigits[byte & 0x0F]};
        }
      } else {
        // A printable character.
        switch (byte) {
        case '"':
          out += {'\\', '"'};
          break;
        case '\\':
          out += {'\\', '\\'};
          break;
        default:
          out += byte;
        }
      }
    } else {
      CopyUtf8Codepoint<copy_utf8_codepoint::ToDebugString,
                        NullTerminated::kTrue>(byte, pos, input_end, out);
    }
  }
}

inline bool IsDigit(char c) { return '0' <= c && c <= '9'; }

int HexDigitToInt(char c) {
  if ('0' <= c && c <= '9') {
    return c - '0';
  } else if ('A' <= c && c <= 'F') {
    return c - 'A' + 10;
  } else if ('a' <= c && c <= 'f') {
    return c - 'a' + 10;
  }
  return -1;
}

inline absl::Status ParseIntStatus(const char *str, const char *str_end) {
  return *str_end == '\0' && str_end != str
             ? absl::OkStatus()
             : absl::UnknownError("can't parse number from JSON string");
}
template <typename number>
inline absl::Status TryParseNumber(const char *str, number &out) {
  int64_t n = 0;
  const absl::Status status = TryParseNumber(str, n);
  out = static_cast<number>(n);
  return status;
}
template <>
inline absl::Status TryParseNumber<long>(const char *str, long &out) {
  char *str_end = nullptr;
  out = std::strtol(str, &str_end, 10);
  return ParseIntStatus(str, str_end);
}
template <>
inline absl::Status TryParseNumber<long long>(const char *str, long long &out) {
  char *str_end = nullptr;
  out = std::strtoll(str, &str_end, 10);
  return ParseIntStatus(str, str_end);
}
template <>
inline absl::Status TryParseNumber<unsigned long>(const char *str,
                                                  unsigned long &out) {
  char *str_end = nullptr;
  out = std::strtoul(str, &str_end, 10);
  return ParseIntStatus(str, str_end);
}
template <>
inline absl::Status
TryParseNumber<unsigned long long>(const char *str, unsigned long long &out) {
  char *str_end = nullptr;
  out = std::strtoull(str, &str_end, 10);
  return ParseIntStatus(str, str_end);
}
template <typename number>
inline bool TryParseSpecialNumber(const std::string &str, number &out) {
  constexpr bool kIsFloatOrDouble =
      std::is_same<number, float>::value || std::is_same<number, double>::value;
  if (kIsFloatOrDouble) {
    if (str == "NaN") {
      out = std::numeric_limits<number>::quiet_NaN();
      return true;
    } else if (str == "Infinity") {
      out = std::numeric_limits<number>::infinity();
      return true;
    } else if (str == "-Infinity") {
      out = -std::numeric_limits<number>::infinity();
      return true;
    }
  }
  return false;
}

template <char kSign>
inline JsonTokenType ParseFractionalPart(char c, const char *token_start,
                                         JsonTokenizer::State &s,
                                         uint64_t integral_part) {
  switch (c) {
  case '.': {
    if (!IsDigit(s.NextCharOrNull())) {
      s.PushErrorAtPosition("digit");
      return JsonTokenType::kError;
    }
    while (IsDigit(c = s.NextCharOrNull())) {
    }
    break;
  }
  case 'E':
  case 'e': {
    c = s.NextCharOrNull();
    goto parse_exponential_part;
  }
  default:
    if (integral_part == 0) {
      return JsonTokenType::kZero;
    }
    if (kSign == '-') {
      s.int_value = -integral_part;
      return JsonTokenType::kSignedInteger;
    } else {
      s.uint_value = integral_part;
      return JsonTokenType::kUnsignedInteger;
    }
  }
  switch (c) {
  case 'E':
  case 'e': {
    c = s.NextCharOrNull();
    break;
  }
  default:
    goto parse_float;
  }
parse_exponential_part:
  switch (c) {
  case '+':
  case '-':
    c = s.NextCharOrNull();
  }
  if (!IsDigit(c)) {
    s.PushErrorAtPosition("digit");
    return JsonTokenType::kError;
  }
  while (IsDigit(s.NextCharOrNull())) {
  }
parse_float:
  const absl::string_view substr(token_start, s.pos - token_start);
  if (!absl::SimpleAtod(substr, &s.float_value)) {
    LOG(ERROR) << "can't parse \"" << substr << "\" as float";
  }
  return JsonTokenType::kFloat;
}

inline bool ParseUnicodeEscapeSequence(JsonTokenizer::State &s,
                                       std::string &out) {
  int codepoint = 0;
  if (s.chars_left() < 4)
    return false;
  for (int i = 0; i < 4; ++i) {
    codepoint = (codepoint << 4) | HexDigitToInt(s.pos[i]);
    if (codepoint < 0) {
      return false;
    }
  }
  s.pos += 4;

  if (0xD800 <= codepoint && codepoint <= 0xDBFF) {
    // We got a high surrogate. Read the low surrogate.
    if (s.chars_left() < 6 || s.pos[0] != '\\' || s.pos[1] != 'u') {
      return false;
    }
    int lo_code_unit = 0;
    for (int i = 2; i < 6; ++i) {
      lo_code_unit = (lo_code_unit << 4) | HexDigitToInt(s.pos[i]);
      if (lo_code_unit < 0) {
        return false;
      }
    }
    s.pos += 6;
    codepoint =
        ((codepoint - 0xD800) << 10) + (lo_code_unit - 0xDC00) + 0x10000;
  }

  // Now write the codepoint in UTF-8.
  if (codepoint <= 0x7F) {
    out += static_cast<char>(codepoint);
  } else if (codepoint <= 0x7FF) {
    out += 0xC0 | (codepoint >> 6);
    out += 0x80 | (codepoint & 0x3F);
  } else if (codepoint <= 0xFFFF) {
    if (0xD800 <= codepoint && codepoint <= 0xDFFF) {
      return false;
    }
    out += 0xE0 | (codepoint >> 12);
    out += 0x80 | ((codepoint >> 6) & 0x3F);
    out += 0x80 | (codepoint & 0x3F);
  } else if (codepoint <= 0x10FFFF) {
    // Four-byte encoding
    out += 0xF0 | (codepoint >> 18);
    out += 0x80 | ((codepoint >> 12) & 0x3F);
    out += 0x80 | ((codepoint >> 6) & 0x3F);
    out += 0x80 | (codepoint & 0x3F);
  } else {
    return false;
  }
  return true;
}

inline JsonTokenType ParseString(JsonTokenizer::State &s) {
  // pos[0] == '"'
  ++s.pos;
  std::string value;
  for (;;) {
    if (s.pos == s.end) {
      s.PushError("error while parsing JSON: unterminated string literal");
      return JsonTokenType::kError;
    }
    const uint8_t byte = static_cast<uint8_t>(*s.pos++);
    if (byte < 0x80) {
      // ASCII-7 codepoint.
      switch (byte) {
      case '"': {
        s.string_value = std::move(value);
        return JsonTokenType::kString;
      }
      case '\\': {
        if (s.pos == s.end) {
          s.PushErrorAtPosition("escape sequence");
          return JsonTokenType::kError;
        }
        const char escape_char = *s.pos++;
        switch (escape_char) {
        case '"':
        case '\'':
        case '\\':
        case '/': {
          value += escape_char;
          break;
        }
        case 'b': {
          value += '\b';
          break;
        }
        case 'f': {
          value += '\f';
          break;
        }
        case 'n': {
          value += '\n';
          break;
        }
        case 'r': {
          value += '\r';
          break;
        }
        case 't': {
          value += '\t';
          break;
        }
        case 'u': {
          if (!ParseUnicodeEscapeSequence(s, value)) {
            s.PushError("error while parsing JSON: invalid unicode escape "
                        "sequence");
            return JsonTokenType::kError;
          }
          break;
        }
        default: {
          s.PushError("error while parsing JSON: invalid escape sequence");
          return JsonTokenType::kError;
        }
        }
        break;
      }
      default: {
        value += byte;
        break;
      }
      }
    } else {
      CopyUtf8Codepoint<copy_utf8_codepoint::ToString, NullTerminated::kFalse>(
          byte, s.pos, s.end, value);
    }
  }
}

inline JsonTokenType NextImpl(JsonTokenizer::State &state) {
  for (;;) {
    if (state.pos == state.end) {
      return JsonTokenType::kStrEnd;
    }
    switch (*state.pos) {
    case '\t':
    case '\n':
    case '\r': {
      ++state.pos;
      break;
    }
    case ' ': {
      // Very common for whitespaces to come together.
      while (*(++state.pos) == ' ') {
      }
      break;
    }
    case '[':
    case ']':
    case '{':
    case '}':
    case ',':
    case ':': {
      state.token_begin = state.pos;
      return static_cast<JsonTokenType>(*state.pos++);
    }
    case 't': {
      state.token_begin = state.pos;
      if (state.chars_left() < 4 || state.pos[1] != 'r' ||
          state.pos[2] != 'u' || state.pos[3] != 'e') {
        state.PushErrorAtPosition("JSON token");
        return JsonTokenType::kError;
      }
      state.pos += 4;
      return JsonTokenType::kTrue;
    }
    case 'f': {
      state.token_begin = state.pos;
      if (state.chars_left() < 5 || state.pos[1] != 'a' ||
          state.pos[2] != 'l' || state.pos[3] != 's' || state.pos[4] != 'e') {
        state.PushErrorAtPosition("JSON token");
        return JsonTokenType::kError;
      }
      state.pos += 5;
      return JsonTokenType::kFalse;
    }
    case 'n': {
      state.token_begin = state.pos;
      if (state.chars_left() < 4 || state.pos[1] != 'u' ||
          state.pos[2] != 'l' || state.pos[3] != 'l') {
        state.PushErrorAtPosition("JSON token");
        return JsonTokenType::kError;
      }
      state.pos += 4;
      return JsonTokenType::kNull;
    }
    case '-': {
      state.token_begin = state.pos;
      const char *token_start = state.pos;
      char digit = state.NextCharOrNull();
      if (!IsDigit(digit)) {
        state.PushErrorAtPosition("digit");
        return JsonTokenType::kError;
      }
      uint64_t integral_part = digit - '0';
      while (IsDigit(digit = state.NextCharOrNull())) {
        integral_part = integral_part * 10 + (digit - '0');
      }
      return ParseFractionalPart<'-'>(digit, token_start, state, integral_part);
    }
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9': {
      state.token_begin = state.pos;
      const char *token_start = state.pos;
      char digit = *token_start;
      uint64_t integral_part = digit - '0';
      while (IsDigit(digit = state.NextCharOrNull())) {
        integral_part = integral_part * 10 + (digit - '0');
      }
      return ParseFractionalPart<'+'>(digit, token_start, state, integral_part);
    }
    case '"': {
      state.token_begin = state.pos;
      return ParseString(state);
    }
    case '\0': {
      return JsonTokenType::kStrEnd;
    }
    default: {
      state.PushErrorAtPosition("JSON token");
      return JsonTokenType::kError;
    }
    }
  }
}

template <typename number>
inline void ParseJsonNumber(JsonTokenizer &tokenizer, number &out) {
  switch (tokenizer.state().token_type) {
  case JsonTokenType::kTrue:
    tokenizer.Next();
    out = static_cast<number>(true);
    break;
  case JsonTokenType::kFalse:
  case JsonTokenType::kZero:
    tokenizer.Next();
    // Zero is the default for any numeric type.
    break;
  case JsonTokenType::kUnsignedInteger:
    out = static_cast<number>(tokenizer.state().uint_value);
    tokenizer.Next();
    break;
  case JsonTokenType::kSignedInteger:
    out = static_cast<number>(tokenizer.state().int_value);
    tokenizer.Next();
    break;
  case JsonTokenType::kFloat:
    out = static_cast<number>(tokenizer.state().float_value);
    tokenizer.Next();
    break;
  case JsonTokenType::kString: {
    const std::string &string_value = tokenizer.state().string_value;
    if (TryParseSpecialNumber(string_value, out)) {
      tokenizer.Next();
      break;
    }
    if (false) {
      // To remove the "unused function" warnings.
      (void)TryParseNumber<long>;
      (void)TryParseNumber<long long>;
      (void)TryParseNumber<unsigned long>;
      (void)TryParseNumber<unsigned long long>;
    }
    const absl::Status status = TryParseNumber(string_value.c_str(), out);
    if (!status.ok()) {
      tokenizer.mutable_state().status = status;
    }
    tokenizer.Next();
    break;
  }
  default:
    tokenizer.mutable_state().PushUnexpectedTokenError("number");
  }
}

inline void AppendWiredUint8(uint8_t value, ByteSink &out) {
  out.Push(235, value);
}

template <int kWire = 232>
inline void AppendWiredUint16(uint16_t value, ByteSink &out) {
  static_assert(kWire == 232 || kWire == 236);
  out.Push(kWire, value & 0xFF, value >> 8);
}

template <int kWire = 233>
inline void AppendWiredUint32(uint32_t value, ByteSink &out) {
  static_assert(kWire == 233 || kWire == 237 || kWire == 240);
  out.Push(kWire, value & 0xFF, value >> 8, value >> 16, value >> 24);
}

inline void AppendWiredInt32(int32_t value, ByteSink &out) {
  AppendWiredUint32<237>(static_cast<uint32_t>(value), out);
}

inline void AppendWiredFloat32(float value, ByteSink &out) {
  union {
    float f;
    uint32_t i;
  } u;
  u.f = value;
  AppendWiredUint32<240>(u.i, out);
}

template <int kWire = 234>
inline void AppendWiredUint64(uint64_t value, ByteSink &out) {
  static_assert(kWire == 234 || kWire == 238 || kWire == 239 || kWire == 241);
  out.Push(kWire, value & 0xFF, value >> 8, value >> 16, value >> 24,
           value >> 32, value >> 40, value >> 48, value >> 56);
}

template <int kWire = 238>
inline void AppendWiredInt64(int64_t value, ByteSink &out) {
  AppendWiredUint64<kWire>(static_cast<uint64_t>(value), out);
}

inline void AppendWiredFloat64(double value, ByteSink &out) {
  union {
    double f;
    uint64_t i;
  } u;
  u.f = value;
  AppendWiredUint64<241>(u.i, out);
}

template <int kWire>
inline void AppendLengthPrefix(size_t length, ByteSink &out) {
  static_assert(kWire == 245 || kWire == 250);
  constexpr bool kPrepareLengthBytes = (kWire == 245);
  if (kWire == 250 && length < 4) {
    out.Prepare(1 + (kPrepareLengthBytes ? length : 0));
    out.PushUnsafe((kWire - 4) + length);
  } else if (length < 232) {
    out.Prepare(2 + (kPrepareLengthBytes ? length : 0));
    out.PushUnsafe(kWire, length);
  } else if (length < 65536) {
    out.Prepare(4 + (kPrepareLengthBytes ? length : 0));
    out.PushUnsafe(kWire, 232, length & 0xFF, length >> 8);
  } else if (length < 4294967296) {
    out.Prepare(6 + (kPrepareLengthBytes ? length : 0));
    out.PushUnsafe(kWire, 233, length & 0xFF, length >> 8, length >> 16,
                   length >> 24);
  } else {
    LOG(FATAL) << "overflow error while encoding skir value; length: "
               << length;
  }
}

inline uint16_t ReadUint16(ByteSource &source) {
  const uint8_t *pos = source.pos;
  const uint16_t result =
      static_cast<uint16_t>(pos[0]) | static_cast<uint16_t>(pos[1] << 8);
  source.pos += 2;
  return result;
};

inline uint32_t ReadUint32(ByteSource &source) {
  const uint8_t *pos = source.pos;
  const uint32_t result = static_cast<uint32_t>(pos[0]) |       //
                          static_cast<uint32_t>(pos[1]) << 8 |  //
                          static_cast<uint32_t>(pos[2]) << 16 | //
                          static_cast<uint32_t>(pos[3]) << 24;
  source.pos = pos + 4;
  return result;
};

inline uint64_t ReadUint64(ByteSource &source) {
  const uint8_t *pos = source.pos;
  const uint64_t result = static_cast<uint64_t>(pos[0]) |       //
                          static_cast<uint64_t>(pos[1]) << 8 |  //
                          static_cast<uint64_t>(pos[2]) << 16 | //
                          static_cast<uint64_t>(pos[3]) << 24 | //
                          static_cast<uint64_t>(pos[4]) << 32 | //
                          static_cast<uint64_t>(pos[5]) << 40 | //
                          static_cast<uint64_t>(pos[6]) << 48 | //
                          static_cast<uint64_t>(pos[7]) << 56;
  source.pos += 8;
  return result;
};

template <typename number>
inline void ParseNumberWithWire(uint8_t wire, ByteSource &source, number &out) {
  constexpr bool kIsFloatOrDouble =
      std::is_same<number, float>::value || std::is_same<number, double>::value;
  if (wire < 232) {
    if (wire != 0) {
      out = static_cast<number>(wire);
    }
    return;
  }
  switch (static_cast<uint8_t>(wire - 232)) {
  case 0: {
    // 232
    if (source.num_bytes_left() < 2) {
      return source.RaiseError();
    }
    out = static_cast<number>(ReadUint16(source));
    break;
  }
  case 1: {
    // 233
    if (source.num_bytes_left() < 4) {
      return source.RaiseError();
    }
    out = static_cast<number>(ReadUint32(source));
    break;
  }
  case 2: {
    // 234
    if (source.num_bytes_left() < 8) {
      return source.RaiseError();
    }
    out = static_cast<number>(ReadUint64(source));
    break;
  }
  case 3: {
    // 235
    if (source.num_bytes_left() < 1) {
      return source.RaiseError();
    }
    out = static_cast<number>(*(source.pos++) - 256);
    break;
  }
  case 4: {
    // 236
    if (source.num_bytes_left() < 2) {
      return source.RaiseError();
    }
    out = static_cast<number>(ReadUint16(source) - 65536);
    break;
  }
  case 5: {
    // 237
    if (source.num_bytes_left() < 4) {
      return source.RaiseError();
    }
    out = static_cast<number>(static_cast<int32_t>(ReadUint32(source)));
    break;
  }
  case 6:
  case 7: {
    // 238, 239
    if (source.num_bytes_left() < 8) {
      return source.RaiseError();
    }
    out = static_cast<number>(static_cast<int64_t>(ReadUint64(source)));
    break;
  }
  case 8: {
    // 240
    if (source.num_bytes_left() < 4) {
      return source.RaiseError();
    }
    union {
      float f;
      uint32_t i;
    } u;
    u.i = ReadUint32(source);
    if (!kIsFloatOrDouble && !std::isfinite(u.f)) {
      return source.RaiseError();
    }
    out = static_cast<number>(u.f);
    break;
  }
  case 9: {
    // 241
    if (source.num_bytes_left() < 8) {
      return source.RaiseError();
    }
    union {
      double f;
      uint64_t i;
    } u;
    u.i = ReadUint64(source);
    if (!kIsFloatOrDouble && !std::isfinite(u.f)) {
      return source.RaiseError();
    }
    out = static_cast<number>(u.f);
    break;
  }
  default: {
    source.RaiseError();
  }
  }
}

template <typename number>
inline void ParseNumber(ByteSource &source, number &out) {
  return ParseNumberWithWire(source.ReadWire(), source, out);
}

inline void SkipValues(ByteSource &source, size_t n) {
  for (size_t i = 0; i < n; ++i) {
    if (source.error)
      return;
    SkipValue(source);
  }
}

struct ReflectionStructOrEnum {
  std::string kind;
  std::string id;
  std::string doc;
  skir::keyed_items<::skir::reflection::Field, ::skir::reflection::get_name>
      fields;
  skir::keyed_items<::skir::reflection::Variant, ::skir::reflection::get_name>
      variants;
  std::vector<int> removed_numbers;
};

template <typename FieldOrVariant>
void AppendFieldOrVariant(const FieldOrVariant &input, ReadableJson &out) {
  JsonObjectWriter(&out)
      .Write("name", input.name)
      .WriteEvenIfDefault("number", input.number)
      .Write("type", input.type)
      .Write("doc", input.doc);
}

template <typename FieldOrVariant>
void ParseFieldOrVariant(JsonTokenizer &tokenizer, FieldOrVariant &out) {
  if (tokenizer.state().token_type == JsonTokenType::kLeftCurlyBracket) {
    static const auto *kParser =
        (new StructJsonObjectParser<FieldOrVariant>())
            ->AddField("name", &FieldOrVariant::name)
            ->AddField("number", &FieldOrVariant::number)
            ->AddField("type", &FieldOrVariant::type)
            ->AddField("doc", &FieldOrVariant::doc);
    kParser->Parse(tokenizer, out);
    return;
  }
  tokenizer.mutable_state().PushUnexpectedTokenError("'{'");
}
} // namespace

skir::service::RawResponse MakeOkJsonResponse(std::string data) {
  return {
      .data = std::move(data),
      .status_code = 200,
      .content_type = "application/json",
  };
}

skir::service::RawResponse MakeOkHtmlResponse(std::string data) {
  return {
      .data = std::move(data),
      .status_code = 200,
      .content_type = "text/html; charset=utf-8",
  };
}

std::string GetStudioHtml(absl::string_view studio_app_js_url) {
  const std::string escaped_url =
      absl::StrReplaceAll(studio_app_js_url, {{"&", "&amp;"},
                                              {"<", "&lt;"},
                                              {">", "&gt;"},
                                              {"\"", "&quot;"},
                                              {"'", "&#39;"}});
  return absl::StrCat(R"html(<!DOCTYPE html>

<html>
  <head>
    <meta charset="utf-8" />
    <title>RPC Studio</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🐙</text></svg>">
    <script src=")html",
                      escaped_url,
                      R"html("></script>
  </head>
  <body style="margin: 0; padding: 0;">
    <skir-studio-app></skir-studio-app>
  </body>
</html>
)html");
}

skir::service::RawResponse MakeBadRequestResponse(std::string data) {
  return {
      .data = std::move(data),
      .status_code = 400,
      .content_type = "text/plain; charset=utf-8",
  };
}

skir::service::RawResponse MakeServerErrorResponse(std::string data,
                                                   int status_code) {
  return {
      .data = std::move(data),
      .status_code = status_code,
      .content_type = "text/plain; charset=utf-8",
  };
}

JsonTokenType JsonTokenizer::Next() {
  if (!state_.status.ok())
    return JsonTokenType::kError;
  return state_.token_type = NextImpl(state_);
}

void JsonTokenizer::State::PushError(absl::string_view message) {
  // Only keep the first error pushed.
  if (status.ok()) {
    status = absl::UnknownError(message);
    token_type = JsonTokenType::kError;
  }
}

void JsonTokenizer::State::PushErrorAtPosition(absl::string_view expected) {
  const size_t position = pos - begin;
  PushError(absl::StrCat("error while parsing JSON at position ", position,
                         ": expected: ", expected));
}

void JsonTokenizer::State::PushUnexpectedTokenError(
    absl::string_view expected) {
  std::string actual_str;
  switch (token_type) {
  case JsonTokenType::kError:
    // Should not happen
    actual_str = "ERROR";
    break;
  case JsonTokenType::kTrue:
    actual_str = "true";
    break;
  case JsonTokenType::kFalse:
    actual_str = "false";
    break;
  case JsonTokenType::kNull:
    actual_str = "null";
    break;
  case JsonTokenType::kZero:
  case JsonTokenType::kUnsignedInteger:
  case JsonTokenType::kSignedInteger:
  case JsonTokenType::kFloat:
    actual_str = "number";
    break;
  case JsonTokenType::kString:
    actual_str = "string";
    break;
  case JsonTokenType::kLeftSquareBracket:
  case JsonTokenType::kRightSquareBracket:
  case JsonTokenType::kLeftCurlyBracket:
  case JsonTokenType::kRightCurlyBracket:
  case JsonTokenType::kComma:
  case JsonTokenType::kColon:
    actual_str = {'\'', static_cast<char>(token_type), '\''};
    break;
  case JsonTokenType::kStrEnd:
    actual_str = "end";
  }
  PushError(absl::StrCat("error while parsing JSON: expected: ", expected,
                         "; found: ", actual_str));
}

void SkipValue(JsonTokenizer &tokenizer) {
  // A stack of (']' | '}'). The element on the top of the stack corresponds to
  // the next expected closing bracket.
  std::string open_brackets;
  while (true) {
    if (!open_brackets.empty() && open_brackets.back() == '}') {
      if (tokenizer.state().token_type != JsonTokenType::kString) {
        tokenizer.mutable_state().PushUnexpectedTokenError("string");
        return;
      }
      if (tokenizer.Next() != JsonTokenType::kColon) {
        tokenizer.mutable_state().PushUnexpectedTokenError("':'");
        return;
      }
      tokenizer.Next();
    }
    switch (tokenizer.state().token_type) {
    case JsonTokenType::kTrue:
    case JsonTokenType::kFalse:
    case JsonTokenType::kNull:
    case JsonTokenType::kZero:
    case JsonTokenType::kUnsignedInteger:
    case JsonTokenType::kSignedInteger:
    case JsonTokenType::kFloat:
    case JsonTokenType::kString: {
      tokenizer.Next();
      break;
    }
    case JsonTokenType::kLeftSquareBracket: {
      if (tokenizer.Next() == JsonTokenType::kRightSquareBracket) {
        tokenizer.Next();
        break;
      }
      open_brackets += ']';
      continue;
    }
    case JsonTokenType::kLeftCurlyBracket: {
      if (tokenizer.Next() == JsonTokenType::kRightCurlyBracket) {
        tokenizer.Next();
        break;
      }
      open_brackets += '}';
      continue;
    }
    default: {
      tokenizer.mutable_state().PushUnexpectedTokenError("value");
      return;
    }
    }
    while (!open_brackets.empty() &&
           open_brackets.back() ==
               static_cast<char>(tokenizer.state().token_type)) {
      tokenizer.Next();
      open_brackets.pop_back();
    }
    if (open_brackets.empty())
      return;
    if (tokenizer.state().token_type == JsonTokenType::kComma) {
      tokenizer.Next();
    } else {
      tokenizer.mutable_state().PushUnexpectedTokenError("','");
      return;
    }
  }
}

JsonArrayReader::JsonArrayReader(JsonTokenizer *tokenizer)
    : tokenizer_(*ABSL_DIE_IF_NULL(tokenizer)) {}

bool JsonArrayReader::NextElement() {
  if (zero_state_) {
    zero_state_ = false;
    if (tokenizer_.Next() == JsonTokenType::kRightSquareBracket) {
      tokenizer_.Next();
      return false;
    } else {
      return true;
    }
  }
  switch (tokenizer_.state().token_type) {
  case JsonTokenType::kComma: {
    tokenizer_.Next();
    return true;
  }
  case JsonTokenType::kRightSquareBracket: {
    tokenizer_.Next();
    return false;
  }
  default: {
    tokenizer_.mutable_state().PushUnexpectedTokenError("','");
    return false;
  }
  }
}

JsonObjectReader::JsonObjectReader(JsonTokenizer *tokenizer)
    : tokenizer_(*ABSL_DIE_IF_NULL(tokenizer)) {}

bool JsonObjectReader::NextEntry() {
  if (zero_state_) {
    tokenizer_.Next();
  }
  switch (tokenizer_.state().token_type) {
  case JsonTokenType::kRightCurlyBracket: {
    tokenizer_.Next();
    return false;
  }
  case JsonTokenType::kComma: {
    if (zero_state_) {
      tokenizer_.mutable_state().PushUnexpectedTokenError("string");
      return false;
    }
    tokenizer_.Next();
    break;
  }
  default: {
    if (!zero_state_) {
      tokenizer_.mutable_state().PushUnexpectedTokenError("','");
      return false;
    }
    zero_state_ = false;
  }
  }
  if (tokenizer_.state().token_type != JsonTokenType::kString) {
    tokenizer_.mutable_state().PushUnexpectedTokenError("string");
    return false;
  }
  name_ = std::move(tokenizer_.mutable_state().string_value);
  if (tokenizer_.Next() != JsonTokenType::kColon) {
    tokenizer_.mutable_state().PushUnexpectedTokenError("':'");
    return false;
  }
  tokenizer_.Next();
  return true;
}

void SkipValue(ByteSource &source) {
  for (size_t num_values_left = 1; num_values_left > 0; --num_values_left) {
    const uint8_t wire = source.ReadWire();
    if (source.error)
      return;
    if (wire < 232)
      continue;
    switch (static_cast<uint8_t>(wire - 232)) {
    case 0:
    case 4: {
      // 232, 236
      if (!source.TryAdvance(2))
        return;
      break;
    }
    case 1:
    case 5:
    case 8: {
      // 233, 237, 240
      if (!source.TryAdvance(4))
        return;
      break;
    }
    case 2:
    case 6:
    case 7:
    case 9: {
      // 234, 238, 239, 241
      if (!source.TryAdvance(8))
        return;
      break;
    }
    case 3: {
      // 235
      if (!source.TryAdvance(1))
        return;
      break;
    }
    case 11:
    case 13: {
      // 243, 245
      uint32_t length = 0;
      ParseNumber(source, length);
      if (!source.TryAdvance(length))
        return;
      break;
    }
    case 15:
    case 16:
    case 17: {
      // 247-249
      num_values_left += wire - 246;
      break;
    }
    case 18: {
      // 250
      uint32_t array_len = 0;
      ParseNumber(source, array_len);
      num_values_left += array_len;
      break;
    }
    case 19:
    case 20:
    case 21:
    case 22: {
      // 251-254
      ++num_values_left;
      break;
    }
    default:
      break;
    }
  }
}

void AppendArrayPrefix(size_t length, ByteSink &out) {
  if (length < 4) {
    out.Push(246 + length);
  } else {
    AppendLengthPrefix<250>(length, out);
  }
}

void ParseArrayPrefix(ByteSource &source, uint32_t &length) {
  const uint8_t byte = source.ReadWire();
  switch (static_cast<uint8_t>(byte - 246)) {
  case 0: {
    // 246
    break;
  }
  case 1: {
    // 247
    length = 1;
    break;
  }
  case 2: {
    // 248
    length = 2;
    break;
  }
  case 3: {
    // 249
    length = 3;
    break;
  }
  case 4: {
    // 250
    ParseNumber(source, length);
    break;
  }
  case 10: {
    // 0
    break;
  }
  default: {
    source.RaiseError();
  }
  }
}

void BoolAdapter::Parse(JsonTokenizer &tokenizer, bool &out) {
  ParseJsonNumber(tokenizer, out);
}

void BoolAdapter::Parse(ByteSource &source, bool &out) {
  ParseNumber(source, out);
}

void Int32Adapter::Append(int32_t input, ByteSink &out) {
  if (input < 0) {
    if (input >= -256) {
      AppendWiredUint8(input + 256, out);
    } else if (input >= -65536) {
      AppendWiredUint16<236>(input + 65536, out);
    } else {
      AppendWiredInt32(input, out);
    }
  } else if (input < 232) {
    out.Push(input);
  } else if (input < 65536) {
    AppendWiredUint16(input, out);
  } else {
    AppendWiredUint32(input, out);
  }
}

void Int32Adapter::Parse(JsonTokenizer &tokenizer, int32_t &out) {
  ParseJsonNumber(tokenizer, out);
}

void Int32Adapter::Parse(ByteSource &source, int32_t &out) {
  ParseNumber(source, out);
}

void Int64Adapter::Append(int64_t input, ByteSink &out) {
  if (input < 0) {
    if (input >= -256) {
      AppendWiredUint8(input + 256, out);
    } else if (input >= -65536) {
      AppendWiredUint16<236>(input + 65536, out);
    } else if (input >= -2147483648) {
      AppendWiredInt32(input, out);
    } else {
      AppendWiredInt64(input, out);
    }
  } else if (input < 232) {
    out.Push(input);
  } else if (input < 65536) {
    AppendWiredUint16(input, out);
  } else if (input < 4294967296) {
    AppendWiredUint32(input, out);
  } else {
    AppendWiredInt64(input, out);
  }
}

void Int64Adapter::Parse(JsonTokenizer &tokenizer, int64_t &out) {
  ParseJsonNumber(tokenizer, out);
}

void Int64Adapter::Parse(ByteSource &source, int64_t &out) {
  ParseNumber(source, out);
}

void Hash64Adapter::Append(uint64_t input, ByteSink &out) {
  if (input < 232) {
    out.Push(input);
  } else if (input < 4294967296) {
    if (input < 65536) {
      AppendWiredUint16(input, out);
    } else {
      AppendWiredUint32(input, out);
    }
  } else {
    AppendWiredUint64(input, out);
  }
}

void Hash64Adapter::Parse(JsonTokenizer &tokenizer, uint64_t &out) {
  ParseJsonNumber(tokenizer, out);
}

void Hash64Adapter::Parse(ByteSource &source, uint64_t &out) {
  ParseNumber(source, out);
}

void Float32Adapter::Append(float input, ByteSink &out) {
  if (input == 0.0) {
    out.Push(0);
  } else {
    AppendWiredFloat32(input, out);
  }
}

void Float32Adapter::Parse(JsonTokenizer &tokenizer, float &out) {
  ParseJsonNumber(tokenizer, out);
}

void Float32Adapter::Parse(ByteSource &source, float &out) {
  ParseNumber(source, out);
}

void Float64Adapter::Append(double input, ByteSink &out) {
  if (input == 0.0) {
    out.Push(0);
  } else {
    AppendWiredFloat64(input, out);
  }
}

void Float64Adapter::Parse(JsonTokenizer &tokenizer, double &out) {
  ParseJsonNumber(tokenizer, out);
}

void Float64Adapter::Parse(ByteSource &source, double &out) {
  ParseNumber(source, out);
}

void TimestampAdapter::Append(absl::Time input, DenseJson &out) {
  absl::StrAppend(&out.out, ClampUnixMillis(absl::ToUnixMillis(input)));
}

void TimestampAdapter::Append(absl::Time input, ReadableJson &out) {
  const int64_t unix_millis = ClampUnixMillis(absl::ToUnixMillis(input));
  input = absl::FromUnixMillis(unix_millis);
  absl::StrAppend(
      &out.out, "{", *out.new_line, "  \"unix_millis\": ", unix_millis, ",",
      *out.new_line, "  \"formatted\": \"",
      absl::FormatTime("%Y-%m-%dT%H:%M:%E3SZ", input, absl::UTCTimeZone()),
      "\"", *out.new_line, "}");
}

void TimestampAdapter::Append(absl::Time input, DebugString &out) {
  const int64_t unix_millis = absl::ToUnixMillis(input); // Don't clamp
  input = absl::FromUnixMillis(unix_millis);
  absl::StrAppend(
      &out.out, "absl::FromUnixMillis(", unix_millis, " /* ",
      absl::FormatTime("%Y-%m-%dT%H:%M:%E3SZ", input, absl::UTCTimeZone()),
      " */)");
}

void TimestampAdapter::Append(absl::Time input, ByteSink &out) {
  const int64_t unix_millis = ClampUnixMillis(absl::ToUnixMillis(input));
  if (unix_millis != 0) {
    AppendWiredInt64<239>(unix_millis, out);
  } else {
    out.Push(0);
  }
}

void TimestampAdapter::Parse(JsonTokenizer &tokenizer, absl::Time &out) {
  if (tokenizer.state().token_type == JsonTokenType::kLeftCurlyBracket) {
    bool has_unix_millis = false;
    JsonObjectReader object_reader(&tokenizer);
    while (object_reader.NextEntry()) {
      if (object_reader.name() == "unix_millis") {
        has_unix_millis = true;
        int64_t unix_millis = 0;
        ParseJsonNumber(tokenizer, unix_millis);
        out = absl::FromUnixMillis(ClampUnixMillis(unix_millis));
      } else {
        SkipValue(tokenizer);
      }
    }
    if (!has_unix_millis) {
      tokenizer.mutable_state().PushError(
          "object missing entry with name 'unix_millis'");
    }
  } else {
    int64_t unix_millis = 0;
    ParseJsonNumber(tokenizer, unix_millis);
    out = absl::FromUnixMillis(ClampUnixMillis(unix_millis));
  }
}

void TimestampAdapter::Parse(ByteSource &source, absl::Time &out) {
  int64_t unix_millis = 0;
  ParseNumber(source, unix_millis);
  out = absl::FromUnixMillis(ClampUnixMillis(unix_millis));
}

void StringAdapter::AppendJson(const std::string &input, std::string &out) {
  if (input.empty()) {
    out += {'"', '"'};
    return;
  }
  out += '"';
  skir_internal::EscapeJsonString(input, out);
  out += '"';
}

void StringAdapter::Append(const std::string &input, DebugString &out) {
  out.out += '"';
  EscapeDebugString(input, out.out);
  out.out += '"';
}

void StringAdapter::Append(const std::string &input, ByteSink &out) {
  if (input.empty()) {
    out.Push(242);
    return;
  }
  // We don't know the length of the UTF-8 string until we actually encode the
  // string. We just know that it's at most 3 times the length of the input
  // string.
  const uint64_t max_encoded_length = input.length() * static_cast<uint64_t>(3);

  const int prefix_length = max_encoded_length < 232     ? 2
                            : max_encoded_length < 65536 ? 4
                                                         : 6;

  // Prepare for the most-likely scenario: the input string does not contain
  // invalid UTF-8 sequences. We will call Prepare again otherwise.
  out.Prepare(prefix_length + input.length());

  // Write zero in place of the UTF-8 sequence length. We will override this
  // number later.
  if (max_encoded_length < 232) {
    out.Push(243, 0);
  } else if (max_encoded_length < 65536) {
    out.Push(243, 232, 0, 0);
  } else {
    out.Push(243, 233, 0, 0, 0, 0);
  }

  const size_t prefix_end_offset = out.length();
  CopyUtf8String(input, out);
  const size_t encoded_length = out.length() - prefix_end_offset;

  // Now we can actually write the encoded length to the prefix.
  uint8_t *data = out.data();
  if (max_encoded_length < 232) {
    data[prefix_end_offset - 1] = encoded_length;
  } else if (max_encoded_length < 65536) {
    data[prefix_end_offset - 2] = encoded_length & 0xFF;
    data[prefix_end_offset - 1] = encoded_length >> 8;
  } else {
    if (encoded_length < 4294967296) {
      data[prefix_end_offset - 4] = encoded_length & 0xFF;
      data[prefix_end_offset - 3] = encoded_length >> 8;
      data[prefix_end_offset - 2] = encoded_length >> 16;
      data[prefix_end_offset - 1] = encoded_length >> 24;
    } else {
      LOG(FATAL) << "overflow error while encoding skir value; length: "
                 << input.length();
    }
  }
}

void StringAdapter::Parse(JsonTokenizer &tokenizer, std::string &out) {
  switch (tokenizer.state().token_type) {
  case JsonTokenType::kString:
    out = std::move(tokenizer.mutable_state().string_value);
    tokenizer.Next();
    break;
  case JsonTokenType::kZero:
    tokenizer.Next();
    break;
  default:
    tokenizer.mutable_state().PushUnexpectedTokenError("string");
  }
}

void StringAdapter::Parse(ByteSource &source, std::string &out) {
  const uint8_t wire = source.ReadWire();
  if (wire == 243) {
    uint32_t length = 0;
    ParseNumber(source, length);
    if (source.num_bytes_left() < length) {
      return source.RaiseError();
    };
    out.reserve(length);
    out.append(cast(source.pos), length);
    source.pos += length;
  } else if (wire != 242 && wire != 0) {
    source.RaiseError();
  }
}

void BytesAdapter::Append(const skir::ByteString &input, DenseJson &out) {
  absl::StrAppend(&out.out, "\"", absl::Base64Escape(input.as_string()), "\"");
}

void BytesAdapter::Append(const skir::ByteString &input, ReadableJson &out) {
  absl::StrAppend(&out.out, "\"hex:", absl::BytesToHexString(input.as_string()),
                  "\"");
}

void BytesAdapter::Append(const skir::ByteString &input, DebugString &out) {
  out.out += "skir::ByteString({";
  const absl::string_view bytes = input.as_string();
  for (size_t i = 0; i < bytes.length(); ++i) {
    if (i != 0) {
      out.out += {',', ' '};
    }
    const uint8_t byte = static_cast<uint8_t>(bytes[i]);
    out.out += {'0', 'x', skir_internal::kHexDigits[byte >> 4],
                skir_internal::kHexDigits[byte & 0xf]};
  }
  out.out += "})";
}

void BytesAdapter::Append(const skir::ByteString &input, ByteSink &out) {
  if (input.empty()) {
    out.Push(244);
  } else {
    AppendLengthPrefix<245>(input.length(), out);
    out.PushNUnsafe(cast(input.as_string().data()), input.length());
  }
}

void BytesAdapter::Parse(JsonTokenizer &tokenizer, skir::ByteString &out) {
  switch (tokenizer.state().token_type) {
  case JsonTokenType::kString: {
    const std::string &string_value = tokenizer.state().string_value;
    std::string bytes;
    if (absl::StartsWith(string_value, "hex:")) {
      const absl::string_view hex_string =
          absl::string_view(string_value).substr(4);
      if (!absl::HexStringToBytes(hex_string, &bytes)) {
        tokenizer.mutable_state().PushError(
            "error while parsing JSON: not a hex string");
      }
    } else if (!absl::Base64Unescape(string_value, &bytes)) {
      tokenizer.mutable_state().PushError(
          "error while parsing JSON: not a Base64 string");
    }
    out = std::move(bytes);
    tokenizer.Next();
    break;
  }
  case JsonTokenType::kZero:
    tokenizer.Next();
    break;
  default:
    tokenizer.mutable_state().PushUnexpectedTokenError("Base64 string");
  }
}

void BytesAdapter::Parse(ByteSource &source, skir::ByteString &out) {
  const uint8_t wire = source.ReadWire();
  switch (wire) {
  case 0:
  case 244:
    break;
  case 245: {
    uint32_t length = 0;
    ParseNumber(source, length);
    if (source.num_bytes_left() < length) {
      return source.RaiseError();
    }
    const char *begin = cast(source.pos);
    out = absl::string_view(begin, length);
    source.pos += length;
    break;
  }
  default: {
    source.RaiseError();
  }
  }
}

// =============================================================================
// BEGIN serialization of type descriptors
// =============================================================================

void ReflectionTypeAdapter::Append(const skir::reflection::Type &input,
                                   ReadableJson &out) {
  absl::StrAppend(&out.out, "{", out.new_line.Indent());
  struct visitor {
    ReadableJson &out;
    void operator()(skir::reflection::PrimitiveType primitive) {
      absl::StrAppend(&out.out, "\"kind\": \"primitive\",", *out.new_line,
                      "\"value\": ");
      skir_internal::Append(primitive, out);
    }
    void operator()(const skir::reflection::OptionalType &optional) {
      absl::StrAppend(&out.out, "\"kind\": \"optional\",", *out.new_line,
                      "\"value\": ");
      skir_internal::Append(optional, out);
    }
    void operator()(const skir::reflection::ArrayType &array) {
      absl::StrAppend(&out.out, "\"kind\": \"array\",", *out.new_line,
                      "\"value\": ");
      skir_internal::Append(array, out);
    }
    void operator()(const skir::reflection::RecordType &record) {
      absl::StrAppend(&out.out, "\"kind\": \"record\",", *out.new_line,
                      "\"value\": ");
      skir_internal::Append(record, out);
    }
  };
  std::visit(visitor{out}, input);
  absl::StrAppend(&out.out, out.new_line.Dedent(), "}");
}

void ReflectionTypeAdapter::Parse(JsonTokenizer &tokenizer,
                                  skir::reflection::Type &out) {
  if (tokenizer.state().token_type == JsonTokenType::kLeftCurlyBracket) {
    static const auto *kParser =
        (new EnumJsonObjectParser<skir::reflection::Type>())
            ->AddVariantAsVariant<skir::reflection::PrimitiveType>("primitive")
            ->AddVariantAsVariant<skir::reflection::OptionalType>("optional")
            ->AddVariantAsVariant<skir::reflection::ArrayType>("array")
            ->AddVariantAsVariant<skir::reflection::RecordType>("record");
    kParser->Parse(tokenizer, out);
  } else {
    tokenizer.mutable_state().PushUnexpectedTokenError("'}'");
  }
}

void ReflectionPrimitiveTypeAdapter::Append(
    skir::reflection::PrimitiveType input, ReadableJson &out) {
  switch (input) {
  case skir::reflection::PrimitiveType::kBool: {
    out.out += "\"bool\"";
    break;
  }
  case skir::reflection::PrimitiveType::kInt32: {
    out.out += "\"int32\"";
    break;
  }
  case skir::reflection::PrimitiveType::kInt64: {
    out.out += "\"int64\"";
    break;
  }
  case skir::reflection::PrimitiveType::kHash64: {
    out.out += "\"hash64\"";
    break;
  }
  case skir::reflection::PrimitiveType::kFloat32: {
    out.out += "\"float32\"";
    break;
  }
  case skir::reflection::PrimitiveType::kFloat64: {
    out.out += "\"float64\"";
    break;
  }
  case skir::reflection::PrimitiveType::kTimestamp: {
    out.out += "\"timestamp\"";
    break;
  }
  case skir::reflection::PrimitiveType::kString: {
    out.out += "\"string\"";
    break;
  }
  case skir::reflection::PrimitiveType::kBytes: {
    out.out += "\"bytes\"";
    break;
  }
  }
}

void ReflectionPrimitiveTypeAdapter::Parse(
    JsonTokenizer &tokenizer, skir::reflection::PrimitiveType &out) {
  static const auto *kMap =
      new ::absl::flat_hash_map<std::string, skir::reflection::PrimitiveType>({
          {"bool", skir::reflection::PrimitiveType::kBool},
          {"int32", skir::reflection::PrimitiveType::kInt32},
          {"int64", skir::reflection::PrimitiveType::kInt64},
          {"hash64", skir::reflection::PrimitiveType::kHash64},
          {"float32", skir::reflection::PrimitiveType::kFloat32},
          {"float64", skir::reflection::PrimitiveType::kFloat64},
          {"timestamp", skir::reflection::PrimitiveType::kTimestamp},
          {"string", skir::reflection::PrimitiveType::kString},
          {"bytes", skir::reflection::PrimitiveType::kBytes},
      });
  if (tokenizer.state().token_type == JsonTokenType::kString) {
    const auto it = kMap->find(tokenizer.state().string_value);
    if (it != kMap->cend()) {
      out = it->second;
      tokenizer.Next();
      return;
    }
  }
  // Error.
  std::vector<std::string> options;
  options.reserve(kMap->size());
  for (const auto &[option, _] : *kMap) {
    options.push_back(absl::StrCat("\"", option, "\""));
  }
  absl::c_sort(options);
  tokenizer.mutable_state().PushUnexpectedTokenError(
      absl::StrCat("one of: [", absl::StrJoin(options, ", "), "]"));
}

void ReflectionOptionalTypeAdapter::Append(
    const skir::reflection::OptionalType &input, ReadableJson &out) {
  TypeAdapter<skir::reflection::Type>::Append(*input.other, out);
}

void ReflectionOptionalTypeAdapter::Parse(JsonTokenizer &tokenizer,
                                          skir::reflection::OptionalType &out) {
  TypeAdapter<skir::reflection::Type>::Parse(tokenizer, *out.other);
}

void ReflectionRecordTypeAdapter::Append(
    const skir::reflection::RecordType &input, ReadableJson &out) {
  TypeAdapter<std::string>::Append(input.record_id, out);
}

void ReflectionRecordTypeAdapter::Parse(JsonTokenizer &tokenizer,
                                        skir::reflection::RecordType &out) {
  TypeAdapter<std::string>::Parse(tokenizer, out.record_id);
}

void ReflectionArrayTypeAdapter::Append(
    const skir::reflection::ArrayType &input, ReadableJson &out) {
  JsonObjectWriter(&out)
      .Write("item", input.item)
      .Write("key_extractor", input.key_extractor);
}

void ReflectionArrayTypeAdapter::Parse(JsonTokenizer &tokenizer,
                                       skir::reflection::ArrayType &out) {
  if (tokenizer.state().token_type == JsonTokenType::kLeftCurlyBracket) {
    static const auto *kParser =
        (new StructJsonObjectParser<skir::reflection::ArrayType>())
            ->AddField("item", &skir::reflection::ArrayType::item)
            ->AddField("key_extractor",
                       &skir::reflection::ArrayType::key_extractor);
    kParser->Parse(tokenizer, out);
    return;
  }
  tokenizer.mutable_state().PushUnexpectedTokenError("'{'");
}

void ReflectionFieldAdapter::Append(const skir::reflection::Field &input,
                                    ReadableJson &out) {
  AppendFieldOrVariant(input, out);
}

void ReflectionFieldAdapter::Parse(JsonTokenizer &tokenizer,
                                   skir::reflection::Field &out) {
  ParseFieldOrVariant(tokenizer, out);
}

void ReflectionVariantAdapter::Append(const skir::reflection::Variant &input,
                                      ReadableJson &out) {
  AppendFieldOrVariant(input, out);
}

void ReflectionVariantAdapter::Parse(JsonTokenizer &tokenizer,
                                     skir::reflection::Variant &out) {
  ParseFieldOrVariant(tokenizer, out);
}

void ReflectionRecordAdapter::Append(const skir::reflection::Record &input,
                                     ReadableJson &out) {
  struct visitor {
    ReadableJson &out;

    void operator()(const skir::reflection::Struct &record) const {
      static const std::string *kKindStr = new std::string("struct");
      JsonObjectWriter(&out)
          .Write("kind", *kKindStr)
          .Write("id", record.id)
          .Write("doc", record.doc)
          .Write("fields", record.fields)
          .Write("removed_numbers", record.removed_numbers);
    }

    void operator()(const skir::reflection::Enum &record) const {
      static const std::string *kKindStr = new std::string("enum");
      JsonObjectWriter(&out)
          .Write("kind", *kKindStr)
          .Write("id", record.id)
          .Write("doc", record.doc)
          .Write("variants", record.variants)
          .Write("removed_numbers", record.removed_numbers);
    }
  };
  std::visit(visitor{out}, input);
}

void ReflectionRecordAdapter::Parse(JsonTokenizer &tokenizer,
                                    skir::reflection::Record &out) {
  if (tokenizer.state().token_type == JsonTokenType::kLeftCurlyBracket) {
    static const auto *kParser =
        (new StructJsonObjectParser<::skir_internal::ReflectionStructOrEnum>())
            ->AddField("kind", &::skir_internal::ReflectionStructOrEnum::kind)
            ->AddField("id", &::skir_internal::ReflectionStructOrEnum::id)
            ->AddField("doc", &::skir_internal::ReflectionStructOrEnum::doc)
            ->AddField("fields",
                       &::skir_internal::ReflectionStructOrEnum::fields)
            ->AddField("variants",
                       &::skir_internal::ReflectionStructOrEnum::variants)
            ->AddField(
                "removed_numbers",
                &::skir_internal::ReflectionStructOrEnum::removed_numbers);
    ::skir_internal::ReflectionStructOrEnum struct_or_enum;
    kParser->Parse(tokenizer, struct_or_enum);
    if (struct_or_enum.kind == "struct") {
      skir::reflection::Struct record;
      record.id = std::move(struct_or_enum.id);
      record.doc = std::move(struct_or_enum.doc);
      record.fields = std::move(struct_or_enum.fields);
      record.removed_numbers = std::move(struct_or_enum.removed_numbers);
      out = std::move(record);
    } else {
      skir::reflection::Enum record;
      record.id = std::move(struct_or_enum.id);
      record.doc = std::move(struct_or_enum.doc);
      record.variants = std::move(struct_or_enum.variants);
      record.removed_numbers = std::move(struct_or_enum.removed_numbers);
      out = std::move(record);
    }
    return;
  }
  tokenizer.mutable_state().PushUnexpectedTokenError("'{'");
}

void ReflectionTypeDescriptorAdapter::Append(
    const skir::reflection::TypeDescriptor &input, ReadableJson &out) {
  JsonObjectWriter(&out)
      .Write("type", input.type)
      .WriteEvenIfDefault("records", input.records);
}

void ReflectionTypeDescriptorAdapter::Parse(
    JsonTokenizer &tokenizer, skir::reflection::TypeDescriptor &out) {
  if (tokenizer.state().token_type == JsonTokenType::kLeftCurlyBracket) {
    static const auto *kParser =
        (new StructJsonObjectParser<skir::reflection::TypeDescriptor>())
            ->AddField("type", &skir::reflection::TypeDescriptor::type)
            ->AddField("records", &skir::reflection::TypeDescriptor::records);
    kParser->Parse(tokenizer, out);
    return;
  }
  tokenizer.mutable_state().PushUnexpectedTokenError("'{'");
}

// =============================================================================
// END serialization of type descriptors
// =============================================================================

void StructJsonObjectParserImpl::Parse(JsonTokenizer &tokenizer,
                                       void *out) const {
  JsonObjectReader object_reader(&tokenizer);
  while (object_reader.NextEntry()) {
    const auto it = fields_.find(object_reader.name());
    if (it == fields_.end()) {
      SkipValue(tokenizer);
      continue;
    }
    const Field *field = it->second.get();
    field->Parse(tokenizer, out);
  }
}

void EnumJsonObjectParserImpl::Parse(JsonTokenizer &tokenizer,
                                     void *out) const {
  JsonObjectReader object_reader(&tokenizer);
  bool kind_seen = false;
  bool value_seen = false;
  const Variant *variant = nullptr;
  // In the unlikely event "value" is seen before "kind", we need to rewind the
  // tokenizer to parse the value.
  std::unique_ptr<JsonTokenizer::State> value_state;
  while (object_reader.NextEntry()) {
    if (!kind_seen && object_reader.name() == "kind") {
      kind_seen = true;
      std::string kind;
      ::skir_internal::Parse(tokenizer, kind);
      const auto it = variants_.find(kind);
      if (it == variants_.end()) {
        continue;
      }
      variant = it->second.get();
      if (value_state != nullptr) {
        // In this unlikely case, we need to rewind the tokenizer to parse the
        // value.
        if (!tokenizer.state().status.ok())
          return;
        JsonTokenizer::State tokenizer_state =
            std::move(tokenizer.mutable_state());
        tokenizer.mutable_state() = *std::move(value_state);
        variant->Parse(tokenizer, out);
        const absl::Status status = std::move(tokenizer.mutable_state().status);
        tokenizer.mutable_state() = std::move(tokenizer_state);
        if (!status.ok()) {
          tokenizer.mutable_state().status = status;
        }
      }
    } else if (!value_seen && object_reader.name() == "value") {
      value_seen = true;
      if (variant != nullptr) {
        variant->Parse(tokenizer, out);
      } else {
        if (!kind_seen) {
          value_state =
              std::make_unique<JsonTokenizer::State>(tokenizer.state());
        }
        SkipValue(tokenizer);
      }
    } else {
      SkipValue(tokenizer);
    }
  }
}

EnumJsonArrayParser::EnumJsonArrayParser(JsonTokenizer *tokenizer)
    : tokenizer_(*ABSL_DIE_IF_NULL(tokenizer)) {}

int EnumJsonArrayParser::ReadNumber() {
  int result = 0;
  switch (tokenizer_.Next()) {
  case JsonTokenType::kZero:
    break;
  case JsonTokenType::kUnsignedInteger:
    result = tokenizer_.state().uint_value;
    break;
  case JsonTokenType::kSignedInteger:
    result = tokenizer_.state().int_value;
    break;
  default:
    tokenizer_.mutable_state().PushUnexpectedTokenError("integer");
    return 0;
  }
  if (tokenizer_.Next() != JsonTokenType::kComma) {
    tokenizer_.mutable_state().PushUnexpectedTokenError("','");
  } else {
    tokenizer_.Next();
  }
  return result;
}

void EnumJsonArrayParser::Finish() {
  if (tokenizer_.state().token_type == JsonTokenType::kRightSquareBracket) {
    tokenizer_.Next();
  } else {
    tokenizer_.mutable_state().PushUnexpectedTokenError("']'");
  }
}

std::pair<bool, int32_t> ParseEnumPrefix(ByteSource &source) {
  const uint8_t wire = source.ReadWire();
  if (wire <= 238) {
    ::int32_t number = 0;
    ParseNumberWithWire(wire, source, number);
    return {false, number};
  }
  switch (static_cast<uint8_t>(wire - 248)) {
  case 0: {
    // 248
    ::int32_t number = 0;
    Int32Adapter::Parse(source, number);
    return {true, number};
  }
  case 2: {
    // 250
    uint32_t length = 0;
    ParseArrayPrefix(source, length);
    if (length != 2)
      break;
    ::int32_t number = 0;
    Int32Adapter::Parse(source, number);
    return {true, number};
  }
  case 3:
  case 4:
  case 5:
  case 6:
    // 251-254
    return {true, wire - 250};
  }
  source.RaiseError();
  return {false, 0};
}

void UnrecognizedValues::ParseFrom(JsonTokenizer &tokenizer) {
  // Each element in this stack is the index of an element in array_lengths_.
  std::vector<size_t> index_of_array_stack;
  while (true) {
    if (!index_of_array_stack.empty()) {
      uint32_t &array_length = array_lengths_[index_of_array_stack.back()];
      ++array_length;
    }
    switch (tokenizer.state().token_type) {
    case JsonTokenType::kTrue: {
      bytes_.Push(1);
      tokenizer.Next();
      break;
    }
    case JsonTokenType::kZero:
    case JsonTokenType::kFalse: {
      bytes_.Push(0);
      tokenizer.Next();
      break;
    }
    case JsonTokenType::kNull: {
      bytes_.Push(255);
      tokenizer.Next();
      break;
    }
    case JsonTokenType::kUnsignedInteger: {
      Hash64Adapter::Append(tokenizer.state().uint_value, bytes_);
      tokenizer.Next();
      break;
    }
    case JsonTokenType::kSignedInteger: {
      Int64Adapter::Append(tokenizer.state().int_value, bytes_);
      tokenizer.Next();
      break;
    }
    case JsonTokenType::kFloat: {
      Float64Adapter::Append(tokenizer.state().float_value, bytes_);
      tokenizer.Next();
      break;
    }
    case JsonTokenType::kString: {
      StringAdapter::Append(tokenizer.state().string_value, bytes_);
      tokenizer.Next();
      break;
    }
    case JsonTokenType::kLeftSquareBracket: {
      if (tokenizer.Next() == JsonTokenType::kRightSquareBracket) {
        bytes_.Push(246);
        tokenizer.Next();
        break;
      }
      bytes_.Push(250);
      const size_t index = array_lengths_.size();
      array_lengths_.push_back(0);
      index_of_array_stack.push_back(index);
      continue;
    }
    case JsonTokenType::kLeftCurlyBracket: {
      // Not supported.
      bytes_.Push(0);
      SkipValue(tokenizer);
      continue;
    }
    default: {
      tokenizer.mutable_state().PushUnexpectedTokenError("value");
      return;
    }
    }
    while (!index_of_array_stack.empty() &&
           tokenizer.state().token_type == JsonTokenType::kRightSquareBracket) {
      tokenizer.Next();
      index_of_array_stack.pop_back();
    }
    if (index_of_array_stack.empty())
      return;
    if (tokenizer.state().token_type == JsonTokenType::kComma) {
      tokenizer.Next();
    } else {
      tokenizer.mutable_state().PushUnexpectedTokenError("','");
      return;
    }
  }
}

void UnrecognizedValues::ParseFrom(ByteSource &source) {
  for (size_t num_values_left = 1; num_values_left > 0; --num_values_left) {
    const uint8_t wire = source.ReadWire();
    switch (static_cast<uint8_t>(wire - 232)) {
    case 3: {
      // 235
      if (source.num_bytes_left() < 1)
        return source.RaiseError();
      ++source.pos;
      bytes_.PushRange(source.pos - 2, source.pos);
      break;
    }
    case 0:
    case 4: {
      // 232, 236
      if (source.num_bytes_left() < 2)
        return source.RaiseError();
      source.pos += 2;
      bytes_.PushRange(source.pos - 3, source.pos);
      break;
    }
    case 1:
    case 5:
    case 8: {
      // 233, 237, 240
      if (source.num_bytes_left() < 4)
        return source.RaiseError();
      source.pos += 4;
      bytes_.PushRange(source.pos - 5, source.pos);
      break;
    }
    case 2:
    case 6:
    case 7:
    case 9: {
      // 234, 238, 239, 241
      if (source.num_bytes_left() < 8)
        return source.RaiseError();
      source.pos += 8;
      bytes_.PushRange(source.pos - 9, source.pos);
      break;
    }
    case 11:
    case 13: {
      // 243, 245
      const uint8_t *start = source.pos - 1;
      uint32_t length = 0;
      ParseNumber(source, length);
      if (source.num_bytes_left() < length)
        return source.RaiseError();
      bytes_.PushRange(start, source.pos += length);
      break;
    }
    case 15:
    case 16:
    case 17: {
      // 247-249
      num_values_left += wire - 246;
      bytes_.Push(wire);
      break;
    }
    case 18: {
      // 250
      uint32_t array_len = 0;
      ParseNumber(source, array_len);
      num_values_left += array_len;
      array_lengths_.push_back(array_len);
      bytes_.Push(wire);
      break;
    }
    case 19:
    case 20:
    case 21:
    case 22: {
      // 251-254
      ++num_values_left;
      bytes_.Push(wire);
      break;
    }
    default: {
      if (wire == 0) {
        source.CheckEnd();
        if (source.error)
          return;
      }
      bytes_.Push(wire);
    }
    }
  }
}

void UnrecognizedValues::AppendTo(DenseJson &out) const {
  size_t index_of_array = 0;
  ByteSource source(bytes_.data(), bytes_.length());
  std::vector<uint32_t> num_left_stack;
  for (;;) {
    if (!num_left_stack.empty()) {
      --num_left_stack.back();
    }
    if (source.pos == source.end)
      break;
    const uint8_t byte = *source.pos;
    if (byte <= 234) {
      uint64_t number = 0;
      Hash64Adapter::Parse(source, number);
      Hash64Adapter::Append(number, out);
    } else {
      switch (static_cast<uint8_t>(byte - 235)) {
      case 0:
      case 1:
      case 2:
      case 3:
      case 4: {
        // 235-239
        int64_t number = 0;
        Int64Adapter::Parse(source, number);
        Int64Adapter::Append(number, out);
        break;
      }
      case 5:
      case 6: {
        // 240-241
        double number = 0.0;
        Float64Adapter::Parse(source, number);
        Float64Adapter::Append(number, out);
        break;
      }
      case 7:
      case 9: {
        // 242, 244
        ++source.pos;
        out.out += {'"', '"'};
        break;
      }
      case 8: {
        // 243
        ++source.pos;
        uint32_t length = 0;
        ParseNumber(source, length);
        out.out += '"';
        const char *begin = cast(source.pos);
        EscapeJsonString<NullTerminated::kFalse>(
            begin, cast(source.pos += length), out.out);
        out.out += '"';
        break;
      }
      case 10: {
        // 245
        ++source.pos;
        uint32_t length = 0;
        ParseNumber(source, length);
        out.out += '"';
        out.out +=
            absl::Base64Escape(absl::string_view(cast(source.pos), length));
        out.out += '"';
        source.pos += length;
        break;
      }
      case 11:
      case 12:
      case 13:
      case 14: {
        // 246-249
        ++source.pos;
        const uint32_t length = byte - 246;
        num_left_stack.push_back(length);
        out.out += '[';
        break;
      }
      case 15: {
        // 250
        ++source.pos;
        const uint32_t length = array_lengths_[index_of_array++];
        num_left_stack.push_back(length);
        out.out += '[';
        break;
      }
      case 16:
      case 17:
      case 18:
      case 19: {
        // 251-254
        ++source.pos;
        const int number = byte - 250;
        num_left_stack.push_back(1);
        absl::StrAppend(&out.out, "[", number);
        break;
      }
      case 20: {
        // 255
        ++source.pos;
        out.out += "null";
        break;
      }
      }
    }
    while (!num_left_stack.empty() && num_left_stack.back() == 0) {
      num_left_stack.pop_back();
      out.out += ']';
    }
    if (out.out.back() != '[' && source.pos < source.end) {
      out.out += ',';
    }
  }
}

void UnrecognizedValues::AppendTo(ByteSink &out) const {
  {
    size_t total_bytes = bytes_.length();
    for (const uint32_t array_length : array_lengths_) {
      total_bytes += array_length < 4       ? 0
                     : array_length < 232   ? 1
                     : array_length < 65536 ? 3
                                            : 5;
    }
    out.Prepare(total_bytes);
  }
  size_t index_of_array = 0;
  ByteSource source(bytes_.data(), bytes_.length());
  while (true) {
    if (source.pos == source.end)
      break;
    const uint8_t byte = *source.pos;
    if (byte < 232) {
      ++source.pos;
      out.PushUnsafe(byte);
    } else {
      switch (static_cast<uint8_t>(byte - 232)) {
      case 0:
      case 4: {
        // 232, 236
        const uint8_t *start = source.pos;
        out.PushRangeUnsafe(start, source.pos += 3);
        break;
      }
      case 1:
      case 5:
      case 8: {
        // 233, 237, 240
        const uint8_t *start = source.pos;
        out.PushRangeUnsafe(start, source.pos += 5);
        break;
      }
      case 2:
      case 6:
      case 7:
      case 9: {
        // 234, 238, 239, 241
        const uint8_t *start = source.pos;
        out.PushRangeUnsafe(start, source.pos += 9);
        break;
      }
      case 3: {
        // 235
        const uint8_t *start = source.pos;
        out.PushRangeUnsafe(start, source.pos += 2);
        break;
      }
      case 10:
      case 12:
      case 14:
      case 15:
      case 16:
      case 17:
      case 19:
      case 20:
      case 21:
      case 22:
      case 23: {
        // 242, 244, 246, 247, 248, 249, 251, 252, 253, 254, 255
        ++source.pos;
        out.PushUnsafe(byte);
        break;
      }
      case 11:
      case 13: {
        // 243, 245
        const uint8_t *start = source.pos++;
        uint32_t length = 0;
        ParseNumber(source, length);
        out.PushRangeUnsafe(start, source.pos += length);
        break;
      }
      case 18: {
        ++source.pos;
        const uint32_t length = array_lengths_[index_of_array++];
        AppendArrayPrefix(length, out);
        break;
      }
      }
    }
  }
}

void AppendUnrecognizedVariant(const UnrecognizedVariant *input,
                               DenseJson &out) {
  if (input == nullptr || input->format != UnrecognizedFormat::kDenseJson) {
    out.out += '0';
  } else if (input->value == nullptr) {
    absl::StrAppend(&out.out, input->number);
  } else {
    absl::StrAppend(&out.out, "[", input->number, ",");
    input->value->AppendTo(out);
    out.out += ']';
  }
}

void AppendUnrecognizedVariant(const UnrecognizedVariant *input,
                               ByteSink &out) {
  if (input == nullptr || input->format != UnrecognizedFormat::kBytes) {
    out.Push(0);
  } else {
    const int32_t number = input->number;
    if (input->value == nullptr) {
      Int32Adapter::Append(number, out);
    } else {
      if (1 <= number && number <= 4) {
        out.Push(number + 250);
      } else {
        out.Push(248);
        Int32Adapter::Append(number, out);
      }
      input->value->AppendTo(out);
    }
  }
}

void ParseUnrecognizedFields(JsonArrayReader &array_reader, size_t num_slots,
                             size_t num_slots_incl_removed,
                             std::shared_ptr<UnrecognizedFieldsData> &out) {
  JsonTokenizer &tokenizer = array_reader.tokenizer();
  if (tokenizer.keep_unrecognized_values()) {
    const size_t num_trailing_removed = num_slots_incl_removed - num_slots;
    for (size_t i = 0; i < num_trailing_removed; ++i) {
      SkipValue(tokenizer);
      if (!array_reader.NextElement())
        return;
    }

    out = std::make_shared<UnrecognizedFieldsData>();
    out->format = UnrecognizedFormat::kDenseJson;
    out->array_len = num_slots_incl_removed;
    do {
      out->values.ParseFrom(tokenizer);
      ++(out->array_len);
    } while (array_reader.NextElement());
  } else {
    do {
      SkipValue(tokenizer);
    } while (array_reader.NextElement());
  }
}

void ParseUnrecognizedFields(ByteSource &source, size_t array_len,
                             size_t num_slots, size_t num_slots_incl_removed,
                             std::shared_ptr<UnrecognizedFieldsData> &out) {
  if (array_len > num_slots_incl_removed && source.keep_unrecognized_values) {
    const size_t num_trailing_removed = num_slots_incl_removed - num_slots;
    SkipValues(source, num_trailing_removed);

    out = std::make_shared<UnrecognizedFieldsData>();
    out->format = UnrecognizedFormat::kBytes;
    out->array_len = array_len;
    for (size_t i = num_slots_incl_removed; i < array_len; ++i) {
      if (source.error)
        return;
      out->values.ParseFrom(source);
    }
  } else {
    SkipValues(source, array_len - num_slots);
  }
}

absl::Status RequestBody::Parse(absl::string_view request_body) {
  if (const char first_char = (request_body.empty() ? '\0' : request_body[0]);
      first_char == '{' || first_char == ' ' || first_char == '\t' ||
      first_char == '\r' || first_char == '\n') {
    // A JSON object
    JsonTokenizer tokenizer(request_body.begin(), request_body.end(),
                            skir::UnrecognizedValuesPolicy::kDrop);
    if (tokenizer.Next() != JsonTokenType::kLeftCurlyBracket) {
      return absl::InvalidArgumentError("expected: JSON object");
    }
    JsonObjectReader object_reader(&tokenizer);
    while (object_reader.NextEntry()) {
      if (object_reader.name() == "method") {
        const JsonTokenType json_token_type = tokenizer.state().token_type;
        if (json_token_type == JsonTokenType::kString) {
          method_name = tokenizer.state().string_value;
        } else if (json_token_type == JsonTokenType::kUnsignedInteger ||
                   json_token_type == JsonTokenType::kSignedInteger) {
          method_number =
              tokenizer.state().token_type == JsonTokenType::kUnsignedInteger
                  ? tokenizer.state().uint_value
                  : tokenizer.state().int_value;
        } else {
          return absl::InvalidArgumentError(
              "'method' field must be a string or an integer");
        }
        tokenizer.Next();
      } else if (object_reader.name() == "request") {
        const char *absl_nullable request_data_begin =
            tokenizer.state().token_begin;
        SkipValue(tokenizer);
        const char *absl_nullable request_data_end =
            tokenizer.state().token_begin;
        request_data =
            request_data_begin != nullptr && request_data_end != nullptr
                ? absl::string_view(request_data_begin,
                                    request_data_end - request_data_begin)
                : absl::string_view();
      } else {
        SkipValue(tokenizer);
      }
    }
    return tokenizer.state().status;
  } else {
    const std::vector<absl::string_view> parts =
        absl::StrSplit(request_body, absl::MaxSplits(':', 3));
    if (parts.size() != 4) {
      return absl::InvalidArgumentError("invalid request format");
    }
    method_name = parts[0];
    if (!absl::SimpleAtoi(parts[1], &method_number.emplace())) {
      return absl::InvalidArgumentError("can't parse method number");
    }
    readable = parts[2] == "readable";
    request_data = parts[3];
    return absl::OkStatus();
  }
}

void MethodDescriptorAdapter::Append(const MethodDescriptor &input,
                                     ReadableJson &out) {
  JsonObjectWriter(&out)
      .Write("method", std::string(input.name))
      .WriteEvenIfDefault("number", input.number)
      .Write("request", input.request_descriptor_json)
      .Write("response", input.response_descriptor_json)
      .Write("doc", input.doc);
}

void MethodListAdapter::Append(const MethodList &input, ReadableJson &out) {
  JsonObjectWriter(&out).WriteEvenIfDefault("methods", input.methods);
}

} // namespace skir_internal

namespace skir {
namespace reflection {

std::string TypeDescriptor::AsJson() const {
  skir_internal::ReadableJson json;
  skir_internal::Append(*this, json);
  return std::move(json).out;
}

absl::StatusOr<TypeDescriptor>
TypeDescriptor::FromJson(absl::string_view json) {
  skir_internal::JsonTokenizer tokenizer(json.begin(), json.end(),
                                         UnrecognizedValuesPolicy::kDrop);
  tokenizer.Next();
  TypeDescriptor result;
  skir_internal::Parse(tokenizer, result);
  if (tokenizer.state().token_type != skir_internal::JsonTokenType::kStrEnd) {
    tokenizer.mutable_state().PushUnexpectedTokenError("end");
  }
  const absl::Status status = tokenizer.state().status;
  if (!status.ok())
    return status;
  return result;
}

} // namespace reflection

namespace service {

void HttpHeaders::Insert(absl::string_view name, absl::string_view value) {
  map_[absl::AsciiStrToLower(name)].emplace_back(value);
}

const std::vector<std::string> &HttpHeaders::Get(absl::string_view name) const {
  const auto it = map_.find(absl::AsciiStrToLower(name));
  if (it == map_.cend()) {
    static const auto *const kResult = new std::vector<std::string>();
    return *kResult;
  } else {
    return it->second;
  }
}

absl::string_view HttpHeaders::GetLast(absl::string_view name) const {
  const std::vector<std::string> &values = Get(name);
  if (values.empty()) {
    return "";
  } else {
    return values.back();
  }
}

absl::StatusOr<std::string>
DecodeUrlQueryString(absl::string_view encoded_query_string) {
  std::string result;
  result.reserve(encoded_query_string.length());

  for (size_t i = 0; i < encoded_query_string.length(); i++) {
    const char c = encoded_query_string[i];
    switch (c) {
    case '%': {
      if (i + 2 >= encoded_query_string.length()) {
        goto invalid_escape_sequence;
      }
      const int hi = skir_internal::HexDigitToInt(encoded_query_string[i + 1]);
      const int lo = skir_internal::HexDigitToInt(encoded_query_string[i + 2]);
      if (hi < 0 || lo < 0) {
        goto invalid_escape_sequence;
      }
      const uint8_t c = hi << 4 | lo;
      result += static_cast<char>(c);
      i += 2;
      break;
    }
    case '+':
      result += ' ';
      break;
    default:
      result += c;
      break;
    }
  }

  return result;

invalid_escape_sequence:
  return absl::InvalidArgumentError("Invalid escape sequence");
}

} // namespace service
} // namespace skir
