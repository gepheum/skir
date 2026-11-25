package build.skir.service

/** HTTP status codes for errors. */
enum class HttpErrorCode(val statusCode: Int) {
    BAD_REQUEST(400),
    UNAUTHORIZED(401),
    PAYMENT_REQUIRED(402),
    FORBIDDEN(403),
    NOT_FOUND(404),
    METHOD_NOT_ALLOWED(405),
    NOT_ACCEPTABLE(406),
    PROXY_AUTHENTICATION_REQUIRED(407),
    REQUEST_TIMEOUT(408),
    CONFLICT(409),
    GONE(410),
    LENGTH_REQUIRED(411),
    PRECONDITION_FAILED(412),
    CONTENT_TOO_LARGE(413),
    URI_TOO_LONG(414),
    UNSUPPORTED_MEDIA_TYPE(415),
    RANGE_NOT_SATISFIABLE(416),
    EXPECTATION_FAILED(417),
    IM_A_TEAPOT(418),
    MISDIRECTED_REQUEST(421),
    UNPROCESSABLE_CONTENT(422),
    LOCKED(423),
    FAILED_DEPENDENCY(424),
    TOO_EARLY(425),
    UPGRADE_REQUIRED(426),
    PRECONDITION_REQUIRED(428),
    TOO_MANY_REQUESTS(429),
    REQUEST_HEADER_FIELDS_TOO_LARGE(431),
    UNAVAILABLE_FOR_LEGAL_REASONS(451),
    INTERNAL_SERVER_ERROR(500),
    NOT_IMPLEMENTED(501),
    BAD_GATEWAY(502),
    SERVICE_UNAVAILABLE(503),
    GATEWAY_TIMEOUT(504),
    HTTP_VERSION_NOT_SUPPORTED(505),
    VARIANT_ALSO_NEGOTIATES(506),
    INSUFFICIENT_STORAGE(507),
    LOOP_DETECTED(508),
    NOT_EXTENDED(510),
    NETWORK_AUTHENTICATION_REQUIRED(511),
    ;

    internal val defaultMessage: String
        get() =
            when (this) {
                BAD_REQUEST -> "Bad Request"
                UNAUTHORIZED -> "Unauthorized"
                PAYMENT_REQUIRED -> "Payment Required"
                FORBIDDEN -> "Forbidden"
                NOT_FOUND -> "Not Found"
                METHOD_NOT_ALLOWED -> "Method Not Allowed"
                NOT_ACCEPTABLE -> "Not Acceptable"
                PROXY_AUTHENTICATION_REQUIRED -> "Proxy Authentication Required"
                REQUEST_TIMEOUT -> "Request Timeout"
                CONFLICT -> "Conflict"
                GONE -> "Gone"
                LENGTH_REQUIRED -> "Length Required"
                PRECONDITION_FAILED -> "Precondition Failed"
                CONTENT_TOO_LARGE -> "Content Too Large"
                URI_TOO_LONG -> "URI Too Long"
                UNSUPPORTED_MEDIA_TYPE -> "Unsupported Media Type"
                RANGE_NOT_SATISFIABLE -> "Range Not Satisfiable"
                EXPECTATION_FAILED -> "Expectation Failed"
                IM_A_TEAPOT -> "I'm a teapot"
                MISDIRECTED_REQUEST -> "Misdirected Request"
                UNPROCESSABLE_CONTENT -> "Unprocessable Content"
                LOCKED -> "Locked"
                FAILED_DEPENDENCY -> "Failed Dependency"
                TOO_EARLY -> "Too Early"
                UPGRADE_REQUIRED -> "Upgrade Required"
                PRECONDITION_REQUIRED -> "Precondition Required"
                TOO_MANY_REQUESTS -> "Too Many Requests"
                REQUEST_HEADER_FIELDS_TOO_LARGE -> "Request Header Fields Too Large"
                UNAVAILABLE_FOR_LEGAL_REASONS -> "Unavailable For Legal Reasons"
                INTERNAL_SERVER_ERROR -> "Internal Server Error"
                NOT_IMPLEMENTED -> "Not Implemented"
                BAD_GATEWAY -> "Bad Gateway"
                SERVICE_UNAVAILABLE -> "Service Unavailable"
                GATEWAY_TIMEOUT -> "Gateway Timeout"
                HTTP_VERSION_NOT_SUPPORTED -> "HTTP Version Not Supported"
                VARIANT_ALSO_NEGOTIATES -> "Variant Also Negotiates"
                INSUFFICIENT_STORAGE -> "Insufficient Storage"
                LOOP_DETECTED -> "Loop Detected"
                NOT_EXTENDED -> "Not Extended"
                NETWORK_AUTHENTICATION_REQUIRED -> "Network Authentication Required"
            }
}
