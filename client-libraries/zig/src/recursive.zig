// Wraps a recursive struct field value.
//
// You should treat `default_value` the same as the default value of `T`.
pub fn Recursive(comptime T: type) type {
    return union(enum) {
        /// Treat this like the default value of `T`.
        default_value,
        value: *const T,
    };
}
