const std = @import("std");
const serializer_mod = @import("serializer.zig");
const type_descriptor = @import("type_descriptor.zig");

const SerializeFormat = serializer_mod.SerializeFormat;
const Method = serializer_mod.Method;

/// The raw HTTP response returned by `Service.handleRequest`.
///
/// Pass these fields directly to your HTTP framework's response writer.
pub const RawResponse = struct {
    /// Response body to write as-is in your HTTP handler.
    data: []const u8,
    /// HTTP status code (for example: 200, 400, 500).
    status_code: u16,
    /// Full HTTP status line to write as-is when speaking raw HTTP.
    status_line: []const u8,
    /// Value to use for the `Content-Type` response header.
    content_type: []const u8,

    fn okJson(data: []const u8) RawResponse {
        return .{
            .data = data,
            .status_code = 200,
            .status_line = statusLine(200),
            .content_type = "application/json",
        };
    }

    fn okHtml(data: []const u8) RawResponse {
        return .{
            .data = data,
            .status_code = 200,
            .status_line = statusLine(200),
            .content_type = "text/html; charset=utf-8",
        };
    }

    fn badRequest(msg: []const u8) RawResponse {
        return .{
            .data = msg,
            .status_code = 400,
            .status_line = statusLine(400),
            .content_type = "text/plain; charset=utf-8",
        };
    }

    fn serverError(msg: []const u8, status_code: u16) RawResponse {
        return .{
            .data = msg,
            .status_code = status_code,
            .status_line = statusLine(status_code),
            .content_type = "text/plain; charset=utf-8",
        };
    }
};

/// An HTTP error status code (4xx or 5xx).
pub const HttpErrorCode = enum(u16) {
    _400_BadRequest = 400,
    _401_Unauthorized = 401,
    _402_PaymentRequired = 402,
    _403_Forbidden = 403,
    _404_NotFound = 404,
    _405_MethodNotAllowed = 405,
    _406_NotAcceptable = 406,
    _407_ProxyAuthenticationRequired = 407,
    _408_RequestTimeout = 408,
    _409_Conflict = 409,
    _410_Gone = 410,
    _411_LengthRequired = 411,
    _412_PreconditionFailed = 412,
    _413_ContentTooLarge = 413,
    _414_UriTooLong = 414,
    _415_UnsupportedMediaType = 415,
    _416_RangeNotSatisfiable = 416,
    _417_ExpectationFailed = 417,
    _418_ImATeapot = 418,
    _421_MisdirectedRequest = 421,
    _422_UnprocessableContent = 422,
    _423_Locked = 423,
    _424_FailedDependency = 424,
    _425_TooEarly = 425,
    _426_UpgradeRequired = 426,
    _428_PreconditionRequired = 428,
    _429_TooManyRequests = 429,
    _431_RequestHeaderFieldsTooLarge = 431,
    _451_UnavailableForLegalReasons = 451,
    _500_InternalServerError = 500,
    _501_NotImplemented = 501,
    _502_BadGateway = 502,
    _503_ServiceUnavailable = 503,
    _504_GatewayTimeout = 504,
    _505_HttpVersionNotSupported = 505,
    _506_VariantAlsoNegotiates = 506,
    _507_InsufficientStorage = 507,
    _508_LoopDetected = 508,
    _510_NotExtended = 510,
    _511_NetworkAuthenticationRequired = 511,

    /// Returns the numeric HTTP status code.
    pub fn asU16(self: HttpErrorCode) u16 {
        return @intFromEnum(self);
    }
};

// =============================================================================
// ServiceError
// =============================================================================

/// Result returned by your method implementation.
///
/// - `.ok`: successful method result.
/// - `.service_error`: intentional client-facing error with explicit status.
/// - `.unknown_error`: unexpected error; returned as 500.
pub fn MethodResult(comptime T: type) type {
    return union(enum) {
        ok: T,
        service_error: ServiceError,
        unknown_error: []const u8,
    };
}

/// Return this from a method implementation to control the HTTP error response
/// sent to the client.
///
/// Any method result returned as `.unknown_error` is treated as an internal
/// server error (HTTP 500). The message from unknown errors is only exposed to
/// the client when `setCanSendUnknownErrorMessage` or
/// `setCanSendUnknownErrorMessageFn` allows it.
pub const ServiceError = struct {
    /// HTTP status code to send to the client.
    status_code: HttpErrorCode,
    /// Message to send in the response body.
    ///
    /// If this is empty, the runtime falls back to the standard status text
    /// for `status_code`.
    message: []const u8,
};

/// Context passed to Service error hooks.
///
/// See `Service` for documentation on the `Meta` type parameter.
pub fn MethodErrorInfo(comptime Meta: type) type {
    return struct {
        /// Name of the method being invoked.
        method_name: []const u8,
        /// The `Meta` value supplied to `handleRequest` for this invocation.
        meta: Meta,
        /// Error message returned by the method or runtime.
        error_message: []const u8,
        /// Present only when the error is a structured `ServiceError`.
        service_error: ?ServiceError,
    };
}

const DEFAULT_STUDIO_APP_JS_URL = "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js";

fn InvokeOutcome(comptime Meta: type) type {
    _ = Meta;
    return union(enum) {
        ok_json: []const u8,
        service_error: ServiceError,
        unknown_error: []const u8,
    };
}

fn MethodEntry(comptime Meta: type) type {
    return struct {
        name: []const u8,
        number: i64,
        doc: []const u8,
        request_type_descriptor_json: []const u8,
        response_type_descriptor_json: []const u8,
        invoke_fn: *const fn (std.mem.Allocator, []const u8, bool, bool, Meta) anyerror!InvokeOutcome(Meta),
    };
}

/// Dispatches RPC requests to registered method implementations.
///
/// `Meta` is your application context type, passed unchanged to every method
/// implementation. It typically holds:
/// - a pointer to your application state (or the slice of it visible to the
///   service layer), and
/// - per-request data extracted by your HTTP framework, such as authentication
///   credentials, client IP, or request IDs.
///
/// Build one `Meta` value per incoming HTTP request and pass it to
/// `handleRequest`. Use `void` when no context is needed.
///
/// Example:
/// ```zig
/// const AppMeta = struct {
///     app: *MyApp,
///     auth_token: []const u8,
/// };
/// ```
///
/// Typical setup:
/// ```zig
/// var service = try skir_client.Service(AppMeta).init(allocator);
/// _ = try service.addMethod(service_mod.get_user_method(), get_user_impl);
/// _ = try service.addMethod(service_mod.add_user_method(), add_user_impl);
/// defer service.deinit();
/// ```
pub fn Service(comptime Meta: type) type {
    return struct {
        const Self = @This();
        const Entry = MethodEntry(Meta);
        const ErrorInfo = MethodErrorInfo(Meta);

        allocator: std.mem.Allocator,
        keep_unrecognized_values: bool,
        can_send_unknown_error_message_fn: *const fn (*const ErrorInfo) bool,
        error_logger_fn: *const fn (*const ErrorInfo) void,
        studio_app_js_url: []const u8,
        by_num: std.AutoHashMap(i64, Entry),
        by_name: std.StringHashMap(i64),

        /// Creates a service instance with safe defaults.
        ///
        /// Defaults:
        /// - unknown error messages are not exposed to clients.
        /// - unknown fields are not kept while decoding requests.
        /// - the built-in Studio page uses the CDN-hosted JavaScript bundle.
        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
                .keep_unrecognized_values = false,
                .can_send_unknown_error_message_fn = defaultCanSendUnknownErrorMessage(Meta),
                .error_logger_fn = defaultErrorLogger(Meta),
                .studio_app_js_url = try allocator.dupe(u8, DEFAULT_STUDIO_APP_JS_URL),
                .by_num = std.AutoHashMap(i64, Entry).init(allocator),
                .by_name = std.StringHashMap(i64).init(allocator),
            };
        }

        /// Controls whether request decoding keeps unrecognized values.
        ///
        /// Keep this disabled for untrusted input. Enable only when you need
        /// forward-compatibility behavior and trust the request source.
        pub fn setKeepUnrecognizedValues(self: *Self, keep: bool) *Self {
            self.keep_unrecognized_values = keep;
            return self;
        }

        /// Sets a fixed policy for exposing unknown error messages.
        ///
        /// `false` (default) avoids leaking internal details in HTTP 500
        /// responses.
        pub fn setCanSendUnknownErrorMessage(self: *Self, can: bool) *Self {
            if (can) {
                self.can_send_unknown_error_message_fn = alwaysTrueCanSend(Meta);
            } else {
                self.can_send_unknown_error_message_fn = alwaysFalseCanSend(Meta);
            }
            return self;
        }

        /// Sets a per-request policy for exposing unknown error messages.
        ///
        /// Use this when exposure depends on request context.
        pub fn setCanSendUnknownErrorMessageFn(self: *Self, f: *const fn (*const ErrorInfo) bool) *Self {
            self.can_send_unknown_error_message_fn = f;
            return self;
        }

        /// Installs an error logger callback.
        ///
        /// Called for both `service_error` and `unknown_error` outcomes.
        ///
        /// The default logger prints a one-line message to stderr.
        pub fn setErrorLogger(self: *Self, logger: *const fn (*const ErrorInfo) void) *Self {
            self.error_logger_fn = logger;
            return self;
        }

        /// Overrides the JavaScript URL used by the built-in `studio` endpoint.
        ///
        /// Skir Studio is a browser UI for exploring and testing the service.
        /// The default value points to the CDN-hosted bundle.
        pub fn setStudioAppJsUrl(self: *Self, url: []const u8) !*Self {
            self.allocator.free(self.studio_app_js_url);
            self.studio_app_js_url = try self.allocator.dupe(u8, url);
            return self;
        }

        /// Registers one method implementation.
        ///
        /// `method` must be a `skir_client.Method(Req, Resp)` value, typically
        /// returned by a generated method accessor.
        ///
        /// `impl_fn` receives three arguments:
        /// - the allocator for request-scoped allocations,
        /// - the deserialized request value,
        /// - the `Meta` value passed to `handleRequest`.
        ///
        /// Returns `error.DuplicateMethodNumber` if the method number is
        /// already registered.
        pub fn addMethod(
            self: *Self,
            comptime method: anytype,
            comptime impl_fn: *const fn (
                std.mem.Allocator,
                @TypeOf(method).Req,
                Meta,
            ) MethodResult(@TypeOf(method).Resp),
        ) !*Self {
            const Req = @TypeOf(method).Req;
            const number: i64 = method.number;
            if (self.by_num.contains(number)) {
                return error.DuplicateMethodNumber;
            }

            // Perform all fallible allocations before touching the maps so
            // that a failure leaves the service in a consistent state.
            const req_td = method.request_serializer.typeDescriptor();
            const req_td_json = try type_descriptor.typeDescriptorToJson(self.allocator, req_td);
            errdefer self.allocator.free(req_td_json);
            const resp_td = method.response_serializer.typeDescriptor();
            const resp_td_json = try type_descriptor.typeDescriptorToJson(self.allocator, resp_td);
            errdefer self.allocator.free(resp_td_json);
            const name_copy = try self.allocator.dupe(u8, method.name);
            errdefer self.allocator.free(name_copy);
            const doc_copy = try self.allocator.dupe(u8, method.doc);
            errdefer self.allocator.free(doc_copy);
            const by_name_key = try self.allocator.dupe(u8, method.name);
            errdefer self.allocator.free(by_name_key);

            const entry: Entry = .{
                .name = name_copy,
                .number = number,
                .doc = doc_copy,
                .request_type_descriptor_json = req_td_json,
                .response_type_descriptor_json = resp_td_json,
                .invoke_fn = struct {
                    fn invoke(allocator: std.mem.Allocator, request_json: []const u8, keep_unrecognized: bool, readable: bool, meta: Meta) anyerror!InvokeOutcome(Meta) {
                        const req = serializerDeserialize(Req, method.request_serializer, allocator, request_json, keep_unrecognized) catch |err| {
                            const msg = try std.fmt.allocPrint(allocator, "bad request: can't parse JSON: {s}", .{@errorName(err)});
                            return .{ .service_error = .{
                                .status_code = ._400_BadRequest,
                                .message = msg,
                            } };
                        };

                        switch (impl_fn(allocator, req, meta)) {
                            .ok => |resp| {
                                const fmt: SerializeFormat = if (readable) .readableJson else .denseJson;
                                const response_json = try method.response_serializer.serialize(allocator, resp, .{ .format = fmt });
                                return .{ .ok_json = response_json };
                            },
                            .service_error => |svc| return .{ .service_error = svc },
                            .unknown_error => |m| return .{ .unknown_error = m },
                        }
                    }
                }.invoke,
            };

            // Both map inserts must succeed before we commit. If by_num.put
            // fails the by_name entry is removed so no dangling reference exists.
            try self.by_name.put(by_name_key, number);
            self.by_num.put(number, entry) catch |err| {
                _ = self.by_name.remove(by_name_key);
                return err;
            };
            return self;
        }

        /// Releases service-owned resources.
        ///
        /// Call once when the service is no longer used.
        pub fn deinit(self: *Self) void {
            var by_num_it = self.by_num.iterator();
            while (by_num_it.next()) |kv| {
                const e = kv.value_ptr.*;
                self.allocator.free(e.name);
                self.allocator.free(e.doc);
                self.allocator.free(e.request_type_descriptor_json);
                self.allocator.free(e.response_type_descriptor_json);
            }
            self.by_num.deinit();

            var by_name_it = self.by_name.iterator();
            while (by_name_it.next()) |kv| {
                self.allocator.free(kv.key_ptr.*);
            }
            self.by_name.deinit();
            self.allocator.free(self.studio_app_js_url);
        }

        /// Parses and dispatches a raw RPC request body.
        ///
        /// `meta` is the `Meta` value for this specific HTTP request. Build it
        /// from your framework request object before calling into the Skir runtime.
        ///
        /// The value passed to `body` must depend on the request type:
        /// - For POST requests, pass the raw request body text.
        /// - For GET requests, pass the decoded query payload (use
        ///   `getPercentDecodedQueryFromUrl` to extract it from the request
        ///   target).
        ///
        /// Integration pattern:
        /// ```zig
        /// var request_arena = std.heap.ArenaAllocator.init(allocator);
        /// defer request_arena.deinit();
        /// const request_allocator = request_arena.allocator();
        ///
        /// const raw_response = try service.handleRequest(request_allocator, body_for_service, {});
        ///
        /// // Copy `raw_response` into your framework response object:
        /// //   status: raw_response.status_code
        /// //   header("Content-Type"): raw_response.content_type
        /// //   body: raw_response.data
        /// ```
        pub fn handleRequest(
            self: *const Self,
            allocator: std.mem.Allocator,
            body: []const u8,
            meta: Meta,
        ) !RawResponse {
            if (std.mem.eql(u8, body, "") or std.mem.eql(u8, body, "studio")) {
                return serveStudio(allocator, self.studio_app_js_url);
            }
            if (std.mem.eql(u8, body, "list")) {
                return self.serveList(allocator);
            }

            const first = if (body.len > 0) body[0] else ' ';
            if (first == '{' or std.ascii.isWhitespace(first)) {
                return self.handleJsonRequest(allocator, body, meta);
            }
            return self.handleColonRequest(allocator, body, meta);
        }

        fn serveList(self: *const Self, allocator: std.mem.Allocator) !RawResponse {
            const entries = try allocator.alloc(Entry, self.by_num.count());
            defer allocator.free(entries);

            var i: usize = 0;
            var it = self.by_num.valueIterator();
            while (it.next()) |entry_ptr| : (i += 1) {
                entries[i] = entry_ptr.*;
            }
            std.sort.pdq(Entry, entries, {}, struct {
                fn lessThan(_: void, lhs: Entry, rhs: Entry) bool {
                    return lhs.number < rhs.number;
                }
            }.lessThan);

            var out = std.ArrayList(u8).empty;
            defer out.deinit(allocator);

            try out.appendSlice(allocator, "{\"methods\":[");
            for (entries, 0..) |e, idx| {
                if (idx != 0) try out.append(allocator, ',');
                try out.appendSlice(allocator, "{\"method\":");
                try appendJsonString(&out, allocator, e.name);
                try out.appendSlice(allocator, ",\"number\":");
                try std.fmt.format(out.writer(allocator), "{d}", .{e.number});
                try out.appendSlice(allocator, ",\"request\":");
                try appendRawJsonOrNull(&out, allocator, e.request_type_descriptor_json);
                try out.appendSlice(allocator, ",\"response\":");
                try appendRawJsonOrNull(&out, allocator, e.response_type_descriptor_json);
                if (e.doc.len > 0) {
                    try out.appendSlice(allocator, ",\"doc\":");
                    try appendJsonString(&out, allocator, e.doc);
                }
                try out.append(allocator, '}');
            }
            try out.appendSlice(allocator, "]}");

            // Re-serialize with pretty-print so the whole response is uniformly
            // indented (the type-descriptor sub-blobs are already pretty JSON).
            const compact = try out.toOwnedSlice(allocator);
            defer allocator.free(compact);
            const parsed = try std.json.parseFromSlice(std.json.Value, allocator, compact, .{});
            defer parsed.deinit();
            const pretty = try std.json.Stringify.valueAlloc(allocator, parsed.value, .{ .whitespace = .indent_2 });

            return RawResponse.okJson(pretty);
        }

        fn handleJsonRequest(self: *const Self, allocator: std.mem.Allocator, body: []const u8, meta: Meta) !RawResponse {
            const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch {
                return RawResponse.badRequest("bad request: invalid JSON");
            };
            defer parsed.deinit();

            const obj = if (parsed.value == .object) parsed.value.object else {
                return RawResponse.badRequest("bad request: expected JSON object");
            };

            const method_val = obj.get("method") orelse {
                return RawResponse.badRequest("bad request: missing 'method' field in JSON");
            };

            const entry = switch (method_val) {
                .integer => |n| self.by_num.get(@intCast(n)) orelse {
                    const msg = try std.fmt.allocPrint(allocator, "bad request: method not found: {d}", .{n});
                    return RawResponse.badRequest(msg);
                },
                .string => |name| blk: {
                    const number = self.by_name.get(name) orelse {
                        const msg = try std.fmt.allocPrint(allocator, "bad request: method not found: {s}", .{name});
                        return RawResponse.badRequest(msg);
                    };
                    break :blk self.by_num.get(number).?;
                },
                else => return RawResponse.badRequest("bad request: 'method' field must be a string or integer"),
            };

            const request_val = obj.get("request") orelse {
                return RawResponse.badRequest("bad request: missing 'request' field in JSON");
            };
            const request_json = try std.json.Stringify.valueAlloc(allocator, request_val, .{});
            defer allocator.free(request_json);

            return self.invokeEntry(allocator, entry, request_json, self.keep_unrecognized_values, true, meta);
        }

        fn handleColonRequest(self: *const Self, allocator: std.mem.Allocator, body: []const u8, meta: Meta) !RawResponse {
            var it = std.mem.splitScalar(u8, body, ':');
            const name_str = it.next() orelse return RawResponse.badRequest("bad request: invalid request format");
            const number_str = it.next() orelse return RawResponse.badRequest("bad request: invalid request format");
            const format_str = it.next() orelse return RawResponse.badRequest("bad request: invalid request format");
            const request_json_raw = it.rest();

            const request_json = if (request_json_raw.len == 0) "{}" else request_json_raw;
            const entry = if (number_str.len == 0) blk: {
                const number = self.by_name.get(name_str) orelse {
                    const msg = try std.fmt.allocPrint(allocator, "bad request: method not found: {s}", .{name_str});
                    return RawResponse.badRequest(msg);
                };
                break :blk self.by_num.get(number).?;
            } else blk: {
                const number = std.fmt.parseInt(i64, number_str, 10) catch {
                    return RawResponse.badRequest("bad request: can't parse method number");
                };
                break :blk self.by_num.get(number) orelse {
                    const msg = try std.fmt.allocPrint(allocator, "bad request: method not found: {s}; number: {d}", .{ name_str, number });
                    return RawResponse.badRequest(msg);
                };
            };

            const readable = std.mem.eql(u8, format_str, "readable");
            return self.invokeEntry(allocator, entry, request_json, self.keep_unrecognized_values, readable, meta);
        }

        fn invokeEntry(
            self: *const Self,
            allocator: std.mem.Allocator,
            entry: Entry,
            request_json: []const u8,
            keep_unrecognized: bool,
            readable: bool,
            meta: Meta,
        ) !RawResponse {
            const outcome = entry.invoke_fn(allocator, request_json, keep_unrecognized, readable, meta) catch |err| {
                const msg = try std.fmt.allocPrint(allocator, "{s}", .{@errorName(err)});
                defer allocator.free(msg);
                const info: ErrorInfo = .{
                    .method_name = entry.name,
                    .meta = meta,
                    .error_message = msg,
                    .service_error = null,
                };
                self.error_logger_fn(&info);

                const out_msg = if (self.can_send_unknown_error_message_fn(&info))
                    try std.fmt.allocPrint(allocator, "server error: {s}", .{msg})
                else
                    try allocator.dupe(u8, "server error");
                return RawResponse.serverError(out_msg, 500);
            };

            switch (outcome) {
                .ok_json => |response_json| return RawResponse.okJson(response_json),
                .service_error => |svc| {
                    const info: ErrorInfo = .{
                        .method_name = entry.name,
                        .meta = meta,
                        .error_message = svc.message,
                        .service_error = svc,
                    };
                    self.error_logger_fn(&info);
                    const msg = if (svc.message.len == 0)
                        try allocator.dupe(u8, httpStatusText(svc.status_code))
                    else
                        try allocator.dupe(u8, svc.message);
                    return RawResponse.serverError(msg, svc.status_code.asU16());
                },
                .unknown_error => |err_msg| {
                    const info: ErrorInfo = .{
                        .method_name = entry.name,
                        .meta = meta,
                        .error_message = err_msg,
                        .service_error = null,
                    };
                    self.error_logger_fn(&info);
                    const msg = if (self.can_send_unknown_error_message_fn(&info))
                        try std.fmt.allocPrint(allocator, "server error: {s}", .{err_msg})
                    else
                        try allocator.dupe(u8, "server error");
                    return RawResponse.serverError(msg, 500);
                },
            }
        }
    };
}

fn serializerDeserialize(
    comptime Req: type,
    ser: serializer_mod.Serializer(Req),
    allocator: std.mem.Allocator,
    request_json: []const u8,
    keep_unrecognized: bool,
) !Req {
    return ser.deserialize(allocator, request_json, .{ .keepUnrecognizedValues = keep_unrecognized });
}

fn appendRawJsonOrNull(out: *std.ArrayList(u8), allocator: std.mem.Allocator, source: []const u8) !void {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{}) catch {
        try out.appendSlice(allocator, "null");
        return;
    };
    parsed.deinit();
    try out.appendSlice(allocator, source);
}

fn appendJsonString(out: *std.ArrayList(u8), allocator: std.mem.Allocator, s: []const u8) !void {
    try out.append(allocator, '"');
    for (s) |c| {
        switch (c) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            else => if (c < 0x20) {
                try std.fmt.format(out.writer(allocator), "\\u{X:0>4}", .{c});
            } else {
                try out.append(allocator, c);
            },
        }
    }
    try out.append(allocator, '"');
}

fn serveStudio(allocator: std.mem.Allocator, js_url: []const u8) !RawResponse {
    return RawResponse.okHtml(try studioHtml(allocator, js_url));
}

fn studioHtml(allocator: std.mem.Allocator, js_url: []const u8) ![]u8 {
    const safe = try htmlEscapeAttr(allocator, js_url);
    defer allocator.free(safe);
    return std.fmt.allocPrint(
        allocator,
        "<!DOCTYPE html><html>  <head>    <meta charset=\"utf-8\" />    <title>RPC Studio</title>    <link rel=\"icon\" href=\"data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🐙</text></svg>\">    <script src=\"{s}\"></script>  </head>  <body style=\"margin: 0; padding: 0;\">    <skir-studio-app></skir-studio-app>  </body></html>",
        .{safe},
    );
}

fn htmlEscapeAttr(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    for (s) |c| {
        switch (c) {
            '&' => try out.appendSlice(allocator, "&amp;"),
            '"' => try out.appendSlice(allocator, "&#34;"),
            '<' => try out.appendSlice(allocator, "&lt;"),
            '>' => try out.appendSlice(allocator, "&gt;"),
            else => try out.append(allocator, c),
        }
    }
    return out.toOwnedSlice(allocator);
}

fn statusLine(code: u16) []const u8 {
    return switch (code) {
        200 => "HTTP/1.1 200 OK\r\n",
        else => switch (@as(HttpErrorCode, @enumFromInt(code))) {
            ._400_BadRequest => "HTTP/1.1 400 Bad Request\r\n",
            ._401_Unauthorized => "HTTP/1.1 401 Unauthorized\r\n",
            ._402_PaymentRequired => "HTTP/1.1 402 Payment Required\r\n",
            ._403_Forbidden => "HTTP/1.1 403 Forbidden\r\n",
            ._404_NotFound => "HTTP/1.1 404 Not Found\r\n",
            ._405_MethodNotAllowed => "HTTP/1.1 405 Method Not Allowed\r\n",
            ._406_NotAcceptable => "HTTP/1.1 406 Not Acceptable\r\n",
            ._407_ProxyAuthenticationRequired => "HTTP/1.1 407 Proxy Authentication Required\r\n",
            ._408_RequestTimeout => "HTTP/1.1 408 Request Timeout\r\n",
            ._409_Conflict => "HTTP/1.1 409 Conflict\r\n",
            ._410_Gone => "HTTP/1.1 410 Gone\r\n",
            ._411_LengthRequired => "HTTP/1.1 411 Length Required\r\n",
            ._412_PreconditionFailed => "HTTP/1.1 412 Precondition Failed\r\n",
            ._413_ContentTooLarge => "HTTP/1.1 413 Content Too Large\r\n",
            ._414_UriTooLong => "HTTP/1.1 414 URI Too Long\r\n",
            ._415_UnsupportedMediaType => "HTTP/1.1 415 Unsupported Media Type\r\n",
            ._416_RangeNotSatisfiable => "HTTP/1.1 416 Range Not Satisfiable\r\n",
            ._417_ExpectationFailed => "HTTP/1.1 417 Expectation Failed\r\n",
            ._418_ImATeapot => "HTTP/1.1 418 I'm a Teapot\r\n",
            ._421_MisdirectedRequest => "HTTP/1.1 421 Misdirected Request\r\n",
            ._422_UnprocessableContent => "HTTP/1.1 422 Unprocessable Content\r\n",
            ._423_Locked => "HTTP/1.1 423 Locked\r\n",
            ._424_FailedDependency => "HTTP/1.1 424 Failed Dependency\r\n",
            ._425_TooEarly => "HTTP/1.1 425 Too Early\r\n",
            ._426_UpgradeRequired => "HTTP/1.1 426 Upgrade Required\r\n",
            ._428_PreconditionRequired => "HTTP/1.1 428 Precondition Required\r\n",
            ._429_TooManyRequests => "HTTP/1.1 429 Too Many Requests\r\n",
            ._431_RequestHeaderFieldsTooLarge => "HTTP/1.1 431 Request Header Fields Too Large\r\n",
            ._451_UnavailableForLegalReasons => "HTTP/1.1 451 Unavailable For Legal Reasons\r\n",
            ._500_InternalServerError => "HTTP/1.1 500 Internal Server Error\r\n",
            ._501_NotImplemented => "HTTP/1.1 501 Not Implemented\r\n",
            ._502_BadGateway => "HTTP/1.1 502 Bad Gateway\r\n",
            ._503_ServiceUnavailable => "HTTP/1.1 503 Service Unavailable\r\n",
            ._504_GatewayTimeout => "HTTP/1.1 504 Gateway Timeout\r\n",
            ._505_HttpVersionNotSupported => "HTTP/1.1 505 HTTP Version Not Supported\r\n",
            ._506_VariantAlsoNegotiates => "HTTP/1.1 506 Variant Also Negotiates\r\n",
            ._507_InsufficientStorage => "HTTP/1.1 507 Insufficient Storage\r\n",
            ._508_LoopDetected => "HTTP/1.1 508 Loop Detected\r\n",
            ._510_NotExtended => "HTTP/1.1 510 Not Extended\r\n",
            ._511_NetworkAuthenticationRequired => "HTTP/1.1 511 Network Authentication Required\r\n",
        },
    };
}

fn httpStatusText(code: HttpErrorCode) []const u8 {
    return switch (code) {
        ._400_BadRequest => "Bad Request",
        ._401_Unauthorized => "Unauthorized",
        ._402_PaymentRequired => "Payment Required",
        ._403_Forbidden => "Forbidden",
        ._404_NotFound => "Not Found",
        ._405_MethodNotAllowed => "Method Not Allowed",
        ._406_NotAcceptable => "Not Acceptable",
        ._407_ProxyAuthenticationRequired => "Proxy Authentication Required",
        ._408_RequestTimeout => "Request Timeout",
        ._409_Conflict => "Conflict",
        ._410_Gone => "Gone",
        ._411_LengthRequired => "Length Required",
        ._412_PreconditionFailed => "Precondition Failed",
        ._413_ContentTooLarge => "Content Too Large",
        ._414_UriTooLong => "URI Too Long",
        ._415_UnsupportedMediaType => "Unsupported Media Type",
        ._416_RangeNotSatisfiable => "Range Not Satisfiable",
        ._417_ExpectationFailed => "Expectation Failed",
        ._418_ImATeapot => "I'm a Teapot",
        ._421_MisdirectedRequest => "Misdirected Request",
        ._422_UnprocessableContent => "Unprocessable Content",
        ._423_Locked => "Locked",
        ._424_FailedDependency => "Failed Dependency",
        ._425_TooEarly => "Too Early",
        ._426_UpgradeRequired => "Upgrade Required",
        ._428_PreconditionRequired => "Precondition Required",
        ._429_TooManyRequests => "Too Many Requests",
        ._431_RequestHeaderFieldsTooLarge => "Request Header Fields Too Large",
        ._451_UnavailableForLegalReasons => "Unavailable For Legal Reasons",
        ._500_InternalServerError => "Internal Server Error",
        ._501_NotImplemented => "Not Implemented",
        ._502_BadGateway => "Bad Gateway",
        ._503_ServiceUnavailable => "Service Unavailable",
        ._504_GatewayTimeout => "Gateway Timeout",
        ._505_HttpVersionNotSupported => "HTTP Version Not Supported",
        ._506_VariantAlsoNegotiates => "Variant Also Negotiates",
        ._507_InsufficientStorage => "Insufficient Storage",
        ._508_LoopDetected => "Loop Detected",
        ._510_NotExtended => "Not Extended",
        ._511_NetworkAuthenticationRequired => "Network Authentication Required",
    };
}

/// Extracts and percent-decodes the query string from a URL.
///
/// Pass the full HTTP request target (e.g. `/myapi?list` or
/// `/myapi?{"method":"GetUser",...}`). The `?` and everything before it are
/// stripped; the remainder is percent-decoded and returned as an owned slice.
///
/// Returns an empty owned slice when the URL has no `?` component. Invalid
/// `%xx` escape sequences are passed through as-is rather than causing an
/// error.
///
/// The caller owns the returned slice and must free it.
///
/// Typical GET request handling:
/// ```zig
/// const body = try skir_client.getPercentDecodedQueryFromUrl(allocator, req.target);
/// defer allocator.free(body);
/// const raw_response = try service.handleRequest(allocator, body, meta);
/// ```
pub fn getPercentDecodedQueryFromUrl(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    const query_start = std.mem.indexOfScalar(u8, url, '?') orelse {
        return allocator.dupe(u8, "");
    };
    const raw_query = url[query_start + 1 ..];
    return percentDecodeQuery(allocator, raw_query);
}

fn percentDecodeQuery(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        if (c == '%' and i + 2 < input.len) {
            const hi = std.fmt.charToDigit(input[i + 1], 16) catch {
                try out.append(allocator, c);
                continue;
            };
            const lo = std.fmt.charToDigit(input[i + 2], 16) catch {
                try out.append(allocator, c);
                continue;
            };
            try out.append(allocator, @as(u8, @intCast((hi << 4) | lo)));
            i += 2;
        } else if (c == '+') {
            try out.append(allocator, ' ');
        } else {
            try out.append(allocator, c);
        }
    }

    return out.toOwnedSlice(allocator);
}

fn defaultCanSendUnknownErrorMessage(comptime Meta: type) fn (*const MethodErrorInfo(Meta)) bool {
    return struct {
        fn f(_: *const MethodErrorInfo(Meta)) bool {
            return false;
        }
    }.f;
}

fn alwaysTrueCanSend(comptime Meta: type) fn (*const MethodErrorInfo(Meta)) bool {
    return struct {
        fn f(_: *const MethodErrorInfo(Meta)) bool {
            return true;
        }
    }.f;
}

fn alwaysFalseCanSend(comptime Meta: type) fn (*const MethodErrorInfo(Meta)) bool {
    return struct {
        fn f(_: *const MethodErrorInfo(Meta)) bool {
            return false;
        }
    }.f;
}

fn defaultErrorLogger(comptime Meta: type) fn (*const MethodErrorInfo(Meta)) void {
    return struct {
        fn f(info: *const MethodErrorInfo(Meta)) void {
            std.debug.print("skir: error in method {s}: {s}\n", .{ info.method_name, info.error_message });
        }
    }.f;
}

fn apiGuardImpl(_: std.mem.Allocator, req: i32, _: void) MethodResult(i32) {
    return .{ .ok = req };
}

fn compileGuardAddMethod() void {
    const M = Method(i32, i32);
    const method: M = undefined;
    // Verify that Req/Resp aliases work and impl_fn type is correctly inferred.
    _ = @as(
        *const fn (std.mem.Allocator, @TypeOf(method).Req, void) MethodResult(@TypeOf(method).Resp),
        apiGuardImpl,
    );
    // Verify addMethod is present on Service.
    if (!@hasDecl(Service(void), "addMethod")) @compileError("Service.addMethod is missing");
}

test "Service API addMethod compile guard" {
    comptime {
        compileGuardAddMethod();
    }
}
