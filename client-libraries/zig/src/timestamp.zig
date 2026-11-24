/// An instant in time, represented as milliseconds since the Unix epoch.
pub const Timestamp = struct {
    unix_millis: i64 = 0,

    /// The Unix epoch (1970-01-01T00:00:00Z).
    pub const epoch: Timestamp = .{};
};
