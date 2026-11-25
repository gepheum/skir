package build.skir.service

/**
 * If this error is thrown from a method implementation, the specified status
 * code and message will be returned in the HTTP response.
 *
 * If any other type of exception is thrown, the response status code will be
 * 500 (Internal Server Error).
 */
class ServiceException(
    val statusCode: HttpErrorCode,
    override val message: String = statusCode.defaultMessage,
) : RuntimeException(message) {
    fun toRawResponse(): Service.RawResponse {
        return Service.RawResponse.serverError(message, statusCode.statusCode)
    }

    override fun toString(): String = message
}
