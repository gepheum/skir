package skir_client

// Method identifies one method in a SkirRPC service, both on the server side
// and the client side.
//
//   - Request is the type of the request parameter.
//   - Response is the type of the response returned by this method.
type Method[Request, Response any] struct {
	// name is the name of the method.
	name string
	// number is the unique number identifying this method within the service.
	number int64
	// requestSerializer serializes and deserializes the request type.
	requestSerializer Serializer[Request]
	// responseSerializer serializes and deserializes the response type.
	responseSerializer Serializer[Response]
	// doc is the documentation string for this method.
	doc string
}

// NewMethod creates an immutable Method.
func NewMethod[Request, Response any](
	name string,
	number int64,
	requestSerializer Serializer[Request],
	responseSerializer Serializer[Response],
	doc string,
) Method[Request, Response] {
	return Method[Request, Response]{
		name:               name,
		number:             number,
		requestSerializer:  requestSerializer,
		responseSerializer: responseSerializer,
		doc:                doc,
	}
}

// Name returns the name of the method.
func (m Method[Request, Response]) Name() string { return m.name }

// Number returns the unique number identifying this method within the service.
func (m Method[Request, Response]) Number() int64 { return m.number }

// RequestSerializer returns the serializer for the request type.
func (m Method[Request, Response]) RequestSerializer() Serializer[Request] {
	return m.requestSerializer
}

// ResponseSerializer returns the serializer for the response type.
func (m Method[Request, Response]) ResponseSerializer() Serializer[Response] {
	return m.responseSerializer
}

// Doc returns the documentation string for this method.
func (m Method[Request, Response]) Doc() string { return m.doc }
