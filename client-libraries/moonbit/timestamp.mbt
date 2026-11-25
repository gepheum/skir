///|
/// Represents a point in time.
pub struct Timestamp {
  priv unix_millis : Int64
}

///|
/// Creates a Timestamp from Unix milliseconds.
pub fn Timestamp::from_unix_millis(ms : Int64) -> Timestamp {
  { unix_millis: clamp_timestamp_millis(ms), }
}

///|
/// Creates a Timestamp from Unix seconds.
pub fn Timestamp::from_unix_seconds(seconds : Double) -> Timestamp {
  Timestamp::from_unix_millis((seconds * 1000.0).round().to_int64())
}

///|
/// Returns the current Timestamp.
pub fn Timestamp::now() -> Timestamp {
  Timestamp::from_unix_millis(@env.now().reinterpret_as_int64())
}

///|
/// Returns the Unix epoch Timestamp.
pub fn Timestamp::unix_epoch() -> Timestamp {
  timestamp_unix_epoch
}

///|
/// Returns the minimum representable Timestamp.
pub fn Timestamp::min() -> Timestamp {
  timestamp_min
}

///|
/// Returns the maximum representable Timestamp.
pub fn Timestamp::max() -> Timestamp {
  timestamp_max
}

///|
/// Returns the Unix milliseconds representation.
pub fn Timestamp::unix_millis(self : Timestamp) -> Int64 {
  self.unix_millis
}

///|
/// Returns the Unix seconds representation.
pub fn Timestamp::unix_seconds(self : Timestamp) -> Double {
  self.unix_millis.to_double() / 1000.0
}

///|
/// Formats the Timestamp as ISO8601 string.
pub fn Timestamp::to_iso8601(self : Timestamp) -> String {
  let ms = clamp_timestamp_millis(self.unix_millis)
  let millis_part = int64_rem_euclid(ms, 1000L).to_int()
  let secs = int64_div_euclid(ms, 1000L)
  let time_of_day = int64_rem_euclid(secs, 86400L)
  let h = (time_of_day / 3600L).to_int()
  let mi = (time_of_day % 3600L / 60L).to_int()
  let s = (time_of_day % 60L).to_int()

  let days = int64_div_euclid(secs, 86400L)
  let z = days + 719468L
  let era = int64_div_euclid(z, 146097L)
  let doe = z - era * 146097L
  let yoe = int64_div_euclid(
    doe -
    int64_div_euclid(doe, 1460L) +
    int64_div_euclid(doe, 36524L) -
    int64_div_euclid(doe, 146096L),
    365L,
  )
  let y = yoe + era * 400L
  let doy = doe -
    (365L * yoe + int64_div_euclid(yoe, 4L) - int64_div_euclid(yoe, 100L))
  let mp = int64_div_euclid(5L * doy + 2L, 153L)
  let d = (doy - int64_div_euclid(153L * mp + 2L, 5L) + 1L).to_int()
  let m = if mp < 10L { (mp + 3L).to_int() } else { (mp - 9L).to_int() }
  let y_final = if m <= 2 { y + 1L } else { y }

  let y_str = if y_final >= 0L {
    zero_pad(y_final.to_int(), 4)
  } else {
    y_final.to_string()
  }

  y_str +
  "-" +
  zero_pad(m, 2) +
  "-" +
  zero_pad(d, 2) +
  "T" +
  zero_pad(h, 2) +
  ":" +
  zero_pad(mi, 2) +
  ":" +
  zero_pad(s, 2) +
  "." +
  zero_pad(millis_part, 3) +
  "Z"
}

///|
pub impl Eq for Timestamp with fn equal(self, other) {
  self.unix_millis == other.unix_millis
}

///|
pub impl Hash for Timestamp with fn hash_combine(self, hasher) {
  Hash::hash_combine(self.unix_millis, hasher)
}

///|
pub impl Compare for Timestamp with fn compare(self, other) {
  self.unix_millis.compare(other.unix_millis)
}

///|
pub impl Debug for Timestamp with fn to_repr(self) {
  Debug::to_repr(self.unix_millis)
}

///|
let min_timestamp_millis : Int64 = -8640000000000000L

///|
let max_timestamp_millis : Int64 = 8640000000000000L

///|
let timestamp_unix_epoch : Timestamp = { unix_millis: 0L, }

///|
let timestamp_min : Timestamp = { unix_millis: min_timestamp_millis, }

///|
let timestamp_max : Timestamp = { unix_millis: max_timestamp_millis, }

///|
fn clamp_timestamp_millis(ms : Int64) -> Int64 {
  if ms < min_timestamp_millis {
    min_timestamp_millis
  } else if ms > max_timestamp_millis {
    max_timestamp_millis
  } else {
    ms
  }
}

///|
fn int64_div_euclid(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  let r = a % b
  if r < 0L {
    if b > 0L {
      q - 1L
    } else {
      q + 1L
    }
  } else {
    q
  }
}

///|
fn int64_rem_euclid(a : Int64, b : Int64) -> Int64 {
  a - int64_div_euclid(a, b) * b
}

///|
fn zero_pad(n : Int32, width : Int32) -> String {
  let s = n.to_string()
  if s.length() >= width {
    s
  } else {
    let mut out = ""
    for _ in 0..<(width - s.length()) {
      out += "0"
    }
    out + s
  }
}

///|
fn[T : Eq] assert_eq_ts(lhs : T, rhs : T) -> Unit {
  if lhs != rhs {
    panic()
  }
}

///|
test "from_unix_millis_clamps_low" {
  let ts = Timestamp::from_unix_millis(-9000000000000000L)
  assert_eq_ts(ts.unix_millis(), Timestamp::min().unix_millis())
}

///|
test "from_unix_millis_clamps_high" {
  let ts = Timestamp::from_unix_millis(9000000000000000L)
  assert_eq_ts(ts.unix_millis(), Timestamp::max().unix_millis())
}

///|
test "from_unix_seconds_rounds_to_millis" {
  let ts = Timestamp::from_unix_seconds(1.6)
  assert_eq_ts(ts.unix_millis(), 1600L)
}

///|
test "unix_epoch_is_zero" {
  assert_eq_ts(Timestamp::unix_epoch().unix_millis(), 0L)
}

///|
test "to_iso8601_formats_expected_value" {
  let ts = Timestamp::from_unix_millis(1234567890000L)
  assert_eq_ts(ts.to_iso8601(), "2009-02-13T23:31:30.000Z")
}

///|
test "timestamp_comparison_operators" {
  let a = Timestamp::from_unix_millis(1000L)
  let b = Timestamp::from_unix_millis(2000L)
  let c = Timestamp::from_unix_millis(1000L)

  assert_eq_ts(a == c, true)
  assert_eq_ts(a < b, true)
  assert_eq_ts(a <= c, true)
  assert_eq_ts(b > a, true)
  assert_eq_ts(b >= c, true)
}
