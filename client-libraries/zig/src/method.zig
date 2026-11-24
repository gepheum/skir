const std = @import("std");
const serializer = @import("serializer.zig");

/// Signature of a SkirRPC method.
pub fn Method(comptime Request: type, comptime Response: type) type {
    return struct {
        pub const Req = Request;
        pub const Resp = Response;

        /// The method name as declared in the .skir file.
        name: []const u8,
        /// The stable numeric identifier of the method.
        number: i32,
        /// The documentation comment from the .skir file.
        doc: []const u8,
        /// Serializer for request values.
        request_serializer: serializer.Serializer(Request),
        /// Serializer for response values.
        response_serializer: serializer.Serializer(Response),
    };
}
