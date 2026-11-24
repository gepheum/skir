import gleam/time/timestamp as gleam_timestamp

/// A timestamp represented as milliseconds since the Unix epoch
/// (1970-01-01T00:00:00Z).
pub type Timestamp {
  Timestamp(unix_millis: Int)
}

/// The default Timestamp: the Unix epoch (1970-01-01T00:00:00Z).
pub const unix_epoch = Timestamp(unix_millis: 0)

/// Converts a Skir Timestamp to a Gleam Timestamp.
pub fn to_gleam_timestamp(t: Timestamp) -> gleam_timestamp.Timestamp {
  gleam_timestamp.from_unix_seconds_and_nanoseconds(
    seconds: t.unix_millis / 1000,
    nanoseconds: t.unix_millis % 1000 * 1_000_000,
  )
}

/// Converts a Gleam Timestamp to a Skir Timestamp.
pub fn from_gleam_timestamp(t: gleam_timestamp.Timestamp) -> Timestamp {
  let #(s, ns) = gleam_timestamp.to_unix_seconds_and_nanoseconds(t)
  Timestamp(unix_millis: s * 1000 + ns / 1_000_000)
}
