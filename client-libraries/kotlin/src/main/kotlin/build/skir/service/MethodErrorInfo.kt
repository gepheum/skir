package build.skir.service

/**
 * Information about an error thrown during the execution of a method on the
 * server side.
 */
data class MethodErrorInfo<out RequestMeta, Request>(
    /** The exception that was thrown. */
    @get:JvmName("error")
    val error: Throwable,
    /** The method that was being executed when the error occurred. */
    @get:JvmName("method")
    val method: Method<Request, *>,
    /** Parsed request passed to the method's implementation. */
    @get:JvmName("request")
    val request: Request,
    /** Metadata coming from the HTTP headers of the request. */
    @get:JvmName("requestMeta")
    val requestMeta: RequestMeta,
)
