package skir_client

import "github.com/valyala/fastjson"

// Internal__UnrecognizedFields holds field data from a newer schema version
// that this client does not recognise. It preserves the data in whichever
// form it was received (JSON or binary) so it can be round-tripped.
//
// Exactly one of jsonElements or bytes is non-nil.
type Internal__UnrecognizedFields struct {
	// totalSlotCount is the total number of slots in the encoded struct,
	// including both recognised and unrecognised fields.
	totalSlotCount int

	// jsonElements holds the unrecognised slots as raw JSON values.
	// Set when the struct was decoded from JSON.
	jsonElements []*fastjson.Value

	// bytes holds the unrecognised slots in binary wire format.
	// Set when the struct was decoded from binary.
	bytes []byte
}

// Internal__NewUnrecognizedFieldsFromJson constructs an
// Internal__UnrecognizedFields from JSON data.
func Internal__NewUnrecognizedFieldsFromJson(totalSlotCount int, jsonElements []*fastjson.Value) *Internal__UnrecognizedFields {
	return &Internal__UnrecognizedFields{
		totalSlotCount: totalSlotCount,
		jsonElements:   jsonElements,
	}
}

// Internal__NewUnrecognizedFieldsFromBytes constructs an
// Internal__UnrecognizedFields from binary wire data.
func Internal__NewUnrecognizedFieldsFromBytes(totalSlotCount int, bytes []byte) *Internal__UnrecognizedFields {
	return &Internal__UnrecognizedFields{
		totalSlotCount: totalSlotCount,
		bytes:          bytes,
	}
}

// Internal__UnrecognizedVariant holds the value of an enum variant from a
// newer schema version that this client does not recognise. It preserves the
// data in whichever form it was received (JSON or binary) so it can be
// round-tripped.
//
// Exactly one of jsonElement or bytes is non-nil.
type Internal__UnrecognizedVariant struct {
	// jsonElement holds the unrecognised variant value as a raw JSON value.
	// Set when the enum was decoded from JSON.
	jsonElement *fastjson.Value

	// bytes holds the unrecognised variant value in binary wire format.
	// Set when the enum was decoded from binary.
	bytes []byte
}

// Internal__NewUnrecognizedVariantFromJson constructs an
// Internal__UnrecognizedVariant from JSON data.
func Internal__NewUnrecognizedVariantFromJson(jsonElement *fastjson.Value) *Internal__UnrecognizedVariant {
	return &Internal__UnrecognizedVariant{jsonElement: jsonElement}
}

// Internal__NewUnrecognizedVariantFromBytes constructs an
// Internal__UnrecognizedVariant from binary wire data.
func Internal__NewUnrecognizedVariantFromBytes(bytes []byte) *Internal__UnrecognizedVariant {
	return &Internal__UnrecognizedVariant{bytes: bytes}
}
