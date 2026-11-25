package build.skir.service

import build.skir.Serializer

/**
 * Identifies one method in a SkirRPC service, both on the server side and the client side.
 *
 * @param Request The type of the request parameter
 * @param Response The type of the response returned by this method
 * @param name The name of the method
 * @param number The unique number identifying this method in the service
 * @param requestSerializer Serializer for the request type
 * @param responseSerializer Serializer for the response type
 */
class Method<Request, Response>(
    @get:JvmName("name")
    val name: String,
    @get:JvmName("number")
    val number: Long,
    @get:JvmName("requestSerializer")
    val requestSerializer: Serializer<Request>,
    @get:JvmName("responseSerializer")
    val responseSerializer: Serializer<Response>,
    @get:JvmName("doc")
    val doc: String,
)
