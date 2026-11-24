package skir_client

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/valyala/fastjson"
)

// ─────────────────────────────────────────────────────────────────────────────
// Type-erased interfaces for variant entries
// ─────────────────────────────────────────────────────────────────────────────

// enumAnyEntry is stored in the number→entry map: either a removed marker or
// an active variant.
type enumAnyEntry[T any] interface {
	anyEntryNumber() int
	anyEntryIsRemoved() bool
}

// enumVariantEntry is an active (non-removed) enum variant.
type enumVariantEntry[T any] interface {
	enumAnyEntry[T]
	variantEntryName() string
	variantEntryKindOrdinal() int
	// variantEntryConstant returns the singleton instance. Panics for wrapper variants.
	variantEntryConstant() T
	variantEntryToJson(input T, eolIndent *string, out *strings.Builder)
	variantEntryEncode(input T, out *binaryOutput)
	variantEntryIsWrapper() bool
	// wrapFromJson decodes the value part of a wrapper variant from JSON.
	// Must not be called on non-wrapper variants.
	wrapFromJson(v *fastjson.Value, keepUnrecognized bool) (T, error)
	// wrapDecode decodes the value part of a wrapper variant from binary.
	// Must not be called on non-wrapper variants.
	wrapDecode(in *binaryInput, keepUnrecognized bool) T
}

// ─────────────────────────────────────────────────────────────────────────────
// enumRemovedEntry – marks a removed variant number
// ─────────────────────────────────────────────────────────────────────────────

type enumRemovedEntry[T any] struct{ n int }

func (e *enumRemovedEntry[T]) anyEntryNumber() int     { return e.n }
func (e *enumRemovedEntry[T]) anyEntryIsRemoved() bool { return true }

// ─────────────────────────────────────────────────────────────────────────────
// enumUnknownEntry – the UNKNOWN variant (number=0, kindOrdinal=0)
// ─────────────────────────────────────────────────────────────────────────────

type enumUnknownEntry[T any] struct {
	inst             T
	wrapUnrecognized func(*Internal__UnrecognizedVariant) T
	getUnrecognized  func(T) *Internal__UnrecognizedVariant
}

func (e *enumUnknownEntry[T]) anyEntryNumber() int     { return 0 }
func (e *enumUnknownEntry[T]) anyEntryIsRemoved() bool { return false }

func (e *enumUnknownEntry[T]) variantEntryName() string     { return "UNKNOWN" }
func (e *enumUnknownEntry[T]) variantEntryKindOrdinal() int { return 0 }
func (e *enumUnknownEntry[T]) variantEntryConstant() T      { return e.inst }
func (e *enumUnknownEntry[T]) variantEntryIsWrapper() bool  { return false }

func (e *enumUnknownEntry[T]) variantEntryToJson(input T, eolIndent *string, out *strings.Builder) {
	if eolIndent != nil {
		out.WriteString(`"unknown"`)
		return
	}
	unrecognized := e.getUnrecognized(input)
	if unrecognized != nil && unrecognized.jsonElement != nil {
		out.Write(unrecognized.jsonElement.MarshalTo(nil))
		return
	}
	out.WriteByte('0')
}

func (e *enumUnknownEntry[T]) variantEntryEncode(input T, out *binaryOutput) {
	unrecognized := e.getUnrecognized(input)
	if unrecognized != nil && unrecognized.bytes != nil {
		out.out.Write(unrecognized.bytes)
	} else {
		out.writeUint8(0)
	}
}

func (e *enumUnknownEntry[T]) wrapFromJson(_ *fastjson.Value, _ bool) (T, error) {
	panic("skir_client: wrapFromJson called on UNKNOWN variant")
}

func (e *enumUnknownEntry[T]) wrapDecode(_ *binaryInput, _ bool) T {
	panic("skir_client: wrapDecode called on UNKNOWN variant")
}

// ─────────────────────────────────────────────────────────────────────────────
// enumConstantEntry – a named constant variant (no wrapped value)
// ─────────────────────────────────────────────────────────────────────────────

type enumConstantEntry[T any] struct {
	n       int
	varName string
	kindOrd int
	inst    T
}

func (e *enumConstantEntry[T]) anyEntryNumber() int     { return e.n }
func (e *enumConstantEntry[T]) anyEntryIsRemoved() bool { return false }

func (e *enumConstantEntry[T]) variantEntryName() string     { return e.varName }
func (e *enumConstantEntry[T]) variantEntryKindOrdinal() int { return e.kindOrd }
func (e *enumConstantEntry[T]) variantEntryConstant() T      { return e.inst }
func (e *enumConstantEntry[T]) variantEntryIsWrapper() bool  { return false }

func (e *enumConstantEntry[T]) variantEntryToJson(input T, eolIndent *string, out *strings.Builder) {
	if eolIndent != nil {
		writeJsonEscapedString(e.varName, out)
		return
	}
	out.WriteString(strconv.Itoa(e.n))
}

func (e *enumConstantEntry[T]) variantEntryEncode(input T, out *binaryOutput) {
	encodeUint32(uint32(e.n), out)
}

func (e *enumConstantEntry[T]) wrapFromJson(_ *fastjson.Value, _ bool) (T, error) {
	panic("skir_client: wrapFromJson called on constant variant " + e.varName)
}

func (e *enumConstantEntry[T]) wrapDecode(_ *binaryInput, _ bool) T {
	panic("skir_client: wrapDecode called on constant variant " + e.varName)
}

// ─────────────────────────────────────────────────────────────────────────────
// enumWrapperEntry[T, V] – a variant that wraps a typed value
// ─────────────────────────────────────────────────────────────────────────────

type enumWrapperEntry[T, V any] struct {
	n        int
	varName  string
	kindOrd  int
	adapter  typeAdapter[V]
	wrap     func(V) T
	getValue func(T) V
}

func (e *enumWrapperEntry[T, V]) anyEntryNumber() int     { return e.n }
func (e *enumWrapperEntry[T, V]) anyEntryIsRemoved() bool { return false }

func (e *enumWrapperEntry[T, V]) variantEntryName() string     { return e.varName }
func (e *enumWrapperEntry[T, V]) variantEntryKindOrdinal() int { return e.kindOrd }
func (e *enumWrapperEntry[T, V]) variantEntryConstant() T {
	panic("skir_client: variantEntryConstant called on wrapper variant " + e.varName)
}
func (e *enumWrapperEntry[T, V]) variantEntryIsWrapper() bool { return true }

func (e *enumWrapperEntry[T, V]) variantEntryToJson(input T, eolIndent *string, out *strings.Builder) {
	value := e.getValue(input)
	if eolIndent != nil {
		childIndent := *eolIndent + "  "
		out.WriteByte('{')
		out.WriteString(childIndent)
		out.WriteString(`"kind": `)
		writeJsonEscapedString(e.varName, out)
		out.WriteByte(',')
		out.WriteString(childIndent)
		out.WriteString(`"value": `)
		e.adapter.toJson(value, &childIndent, out)
		out.WriteString(*eolIndent)
		out.WriteByte('}')
	} else {
		out.WriteByte('[')
		out.WriteString(strconv.Itoa(e.n))
		out.WriteByte(',')
		e.adapter.toJson(value, nil, out)
		out.WriteByte(']')
	}
}

func (e *enumWrapperEntry[T, V]) variantEntryEncode(input T, out *binaryOutput) {
	value := e.getValue(input)
	if e.n >= 1 && e.n <= 4 {
		out.writeUint8(uint8(250 + e.n))
	} else {
		out.writeUint8(248)
		encodeUint32(uint32(e.n), out)
	}
	e.adapter.encode(value, out)
}

func (e *enumWrapperEntry[T, V]) wrapFromJson(v *fastjson.Value, keepUnrecognized bool) (T, error) {
	value, err := e.adapter.fromJson(*v, keepUnrecognized)
	if err != nil {
		var zero T
		return zero, err
	}
	return e.wrap(value), nil
}

func (e *enumWrapperEntry[T, V]) wrapDecode(in *binaryInput, keepUnrecognized bool) T {
	value, _ := e.adapter.decode(in, keepUnrecognized)
	return e.wrap(value)
}

func (e *enumWrapperEntry[T, V]) wrapDefault() (T, error) {
	var p fastjson.Parser
	v, err := p.Parse("0")
	if err != nil {
		var zero T
		return zero, err
	}
	value, err := e.adapter.fromJson(*v, false)
	if err != nil {
		var zero T
		return zero, err
	}
	return e.wrap(value), nil
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal__EnumAdapter[T]
// ─────────────────────────────────────────────────────────────────────────────

// Internal__EnumAdapter implements typeAdapter[T] for a skir enum type.
// For use only by code generated by the skir Go generator.
//
//   - T is the frozen enum type.
//
// Usage: call NewEnumAdapter, then AddConstantVariant / AddWrapperVariant /
// AddRemovedNumber for each variant, then Finalize before using the adapter.
type Internal__EnumAdapter[T any] struct {
	modulePath     string
	qualifiedName  string
	docString      string
	getKindOrdinal func(T) int
	unknownEntry   *enumUnknownEntry[T]

	// Built incrementally before Finalize.
	numberToEntry      map[int]enumAnyEntry[T]
	nameToVariantEntry map[string]enumVariantEntry[T]
	// kindOrdinalToEntry is indexed by kind ordinal (0 = UNKNOWN).
	// Allocated at construction time with length = kindCount.
	kindOrdinalToEntry []enumVariantEntry[T]
	removedNumbers     map[int]struct{}

	// descVariants accumulates non-UNKNOWN variants for the descriptor.
	descVariants []EnumVariant

	desc      *EnumDescriptor
	finalized bool
}

// NewEnumAdapter creates a new Internal__EnumAdapter.
//
// kindCount is the total number of kind values including UNKNOWN.
// Call AddConstantVariant, AddWrapperVariant, AddRemovedNumber, then Finalize.
func NewEnumAdapter[T any](
	modulePath, qualifiedName, doc string,
	getKindOrdinal func(T) int,
	kindCount int,
	unknownInstance T,
	wrapUnrecognized func(*Internal__UnrecognizedVariant) T,
	getUnrecognized func(T) *Internal__UnrecognizedVariant,
) *Internal__EnumAdapter[T] {
	a := &Internal__EnumAdapter[T]{
		modulePath:     modulePath,
		qualifiedName:  qualifiedName,
		docString:      doc,
		getKindOrdinal: getKindOrdinal,
		unknownEntry: &enumUnknownEntry[T]{
			inst:             unknownInstance,
			wrapUnrecognized: wrapUnrecognized,
			getUnrecognized:  getUnrecognized,
		},
		numberToEntry:      make(map[int]enumAnyEntry[T]),
		nameToVariantEntry: make(map[string]enumVariantEntry[T]),
		kindOrdinalToEntry: make([]enumVariantEntry[T], kindCount),
		removedNumbers:     make(map[int]struct{}),
	}
	// Initialize the descriptor immediately so typeDescriptor() returns a valid
	// non-nil pointer even before Finalize is called. This lets recursive wrapper
	// variants capture the live pointer; Variants is populated by Finalize.
	a.desc = newEnumDescriptor(modulePath, qualifiedName, doc, a.removedNumbers, nil)
	return a
}

// AddConstantVariant registers a constant (non-wrapping) variant.
// Must be called before Finalize.
func (a *Internal__EnumAdapter[T]) AddConstantVariant(
	number int,
	name string,
	kindOrdinal int,
	doc string,
	instance T,
) {
	if a.finalized {
		panic("skir_client: AddConstantVariant called after Finalize")
	}
	e := &enumConstantEntry[T]{
		n:       number,
		varName: name,
		kindOrd: kindOrdinal,
		inst:    instance,
	}
	a.numberToEntry[number] = e
	a.nameToVariantEntry[name] = e
	{
		upper := strings.ToUpper(name)
		if upper != name {
			a.nameToVariantEntry[upper] = e
		}
	}
	{
		lower := strings.ToLower(name)
		if lower != name {
			a.nameToVariantEntry[lower] = e
		}
	}
	a.kindOrdinalToEntry[kindOrdinal] = e
	a.descVariants = append(a.descVariants, &EnumConstantVariant{name: name, number: number, doc: doc})
}

// Internal__AddWrapperVariant registers a wrapper variant on an in-progress
// Internal__EnumAdapter. Must be called before Finalize.
//
// This is a package-level function (not a method) because Go does not permit
// additional type parameters on methods.
func Internal__AddWrapperVariant[T, V any](
	a *Internal__EnumAdapter[T],
	number int,
	name string,
	kindOrdinal int,
	ser Serializer[V],
	doc string,
	wrap func(V) T,
	getValue func(T) V,
) {
	if a.finalized {
		panic("skir_client: AddWrapperVariant called after Finalize")
	}
	e := &enumWrapperEntry[T, V]{
		n:        number,
		varName:  name,
		kindOrd:  kindOrdinal,
		adapter:  ser.adapter,
		wrap:     wrap,
		getValue: getValue,
	}
	a.numberToEntry[number] = e
	a.nameToVariantEntry[name] = e
	a.kindOrdinalToEntry[kindOrdinal] = e
	a.descVariants = append(a.descVariants, &EnumWrapperVariant{
		name:        name,
		number:      number,
		variantType: ser.adapter.typeDescriptor(),
		doc:         doc,
	})
}

// AddRemovedNumber marks a variant number as having been removed from the schema.
// Must be called before Finalize.
func (a *Internal__EnumAdapter[T]) AddRemovedNumber(number int) {
	if a.finalized {
		panic("skir_client: AddRemovedNumber called after Finalize")
	}
	a.numberToEntry[number] = &enumRemovedEntry[T]{n: number}
	a.removedNumbers[number] = struct{}{}
}

// Finalize prepares the adapter for serialization.
// Must be called once, after all Add* calls.
func (a *Internal__EnumAdapter[T]) Finalize() {
	if a.finalized {
		panic("skir_client: Finalize called more than once on EnumAdapter")
	}
	a.finalized = true
	// Register the unknown entry in all lookup structures.
	a.numberToEntry[0] = a.unknownEntry
	a.nameToVariantEntry["UNKNOWN"] = a.unknownEntry
	a.nameToVariantEntry["unknown"] = a.unknownEntry
	a.kindOrdinalToEntry[0] = a.unknownEntry
	// Populate Variants on the descriptor pre-allocated in NewEnumAdapter
	// (UNKNOWN is excluded from the descriptor variants).
	a.desc.variants = a.descVariants
}

// ─────────────────────────────────────────────────────────────────────────────
// typeAdapter[T] implementation
// ─────────────────────────────────────────────────────────────────────────────

func (a *Internal__EnumAdapter[T]) isDefault(input T) bool {
	return a.getKindOrdinal(input) == 0
}

func (a *Internal__EnumAdapter[T]) toJson(input T, eolIndent *string, out *strings.Builder) {
	kindOrd := a.getKindOrdinal(input)
	a.kindOrdinalToEntry[kindOrd].variantEntryToJson(input, eolIndent, out)
}

func (a *Internal__EnumAdapter[T]) fromJson(v fastjson.Value, keepUnrecognized bool) (T, error) {
	unknown := a.unknownEntry.inst
	switch v.Type() {
	case fastjson.TypeNumber:
		number, err := v.Int()
		if err != nil {
			return unknown, err
		}
		return a.resolveConstantLookup(number, keepUnrecognized, &v)

	case fastjson.TypeTrue:
		return a.resolveConstantLookup(1, keepUnrecognized, nil)

	case fastjson.TypeFalse:
		return a.resolveConstantLookup(0, keepUnrecognized, nil)

	case fastjson.TypeString:
		name := string(v.GetStringBytes())
		entry := a.nameToVariantEntry[name]
		if entry == nil {
			return unknown, nil
		}
		if entry.variantEntryIsWrapper() {
			return unknown, fmt.Errorf("skir: enum name %q refers to a wrapper variant in primitive context", name)
		}
		return entry.variantEntryConstant(), nil

	case fastjson.TypeArray:
		items, err := v.Array()
		if err != nil || len(items) < 2 {
			return unknown, err
		}
		number, err := items[0].Int()
		if err != nil {
			return unknown, nil
		}
		entry := a.numberToEntry[number]
		if entry == nil {
			if keepUnrecognized {
				vcopy := v
				return a.unknownEntry.wrapUnrecognized(Internal__NewUnrecognizedVariantFromJson(&vcopy)), nil
			}
			return unknown, nil
		}
		if entry.anyEntryIsRemoved() {
			return unknown, nil
		}
		varEntry := entry.(enumVariantEntry[T])
		if !varEntry.variantEntryIsWrapper() {
			return varEntry.variantEntryConstant(), nil
		}
		return varEntry.wrapFromJson(items[1], keepUnrecognized)

	case fastjson.TypeObject:
		obj, err := v.Object()
		if err != nil {
			return unknown, err
		}
		kindVal := obj.Get("kind")
		valueVal := obj.Get("value")
		if kindVal == nil || valueVal == nil {
			return unknown, nil
		}
		name := string(kindVal.GetStringBytes())
		entry := a.nameToVariantEntry[name]
		if entry == nil {
			return unknown, nil
		}
		if !entry.variantEntryIsWrapper() {
			return entry.variantEntryConstant(), nil
		}
		return entry.wrapFromJson(valueVal, keepUnrecognized)
	}
	return unknown, nil
}

// resolveConstantLookup handles a decoded integer number for constant-style
// lookups (TypeNumber/bool in JSON, or wire < 242 in binary).
// raw is the original JSON value; it may be nil (binary path).
func (a *Internal__EnumAdapter[T]) resolveConstantLookup(number int, keepUnrecognized bool, raw *fastjson.Value) (T, error) {
	unknown := a.unknownEntry.inst
	entry := a.numberToEntry[number]
	if entry == nil {
		if keepUnrecognized {
			if raw != nil {
				// JSON path: heap-copy the value so the pointer outlives this call.
				vcopy := *raw
				return a.unknownEntry.wrapUnrecognized(Internal__NewUnrecognizedVariantFromJson(&vcopy)), nil
			}
			// Binary path: re-encode the number as wire bytes.
			var out binaryOutput
			encodeUint32(uint32(number), &out)
			return a.unknownEntry.wrapUnrecognized(Internal__NewUnrecognizedVariantFromBytes(out.out.Bytes())), nil
		}
		return unknown, nil
	}
	if entry.anyEntryIsRemoved() {
		return unknown, nil
	}
	varEntry := entry.(enumVariantEntry[T])
	if varEntry.variantEntryIsWrapper() {
		wrapperEntry := varEntry.(interface{ wrapDefault() (T, error) })
		return wrapperEntry.wrapDefault()
	}
	return varEntry.variantEntryConstant(), nil
}

func (a *Internal__EnumAdapter[T]) encode(input T, out *binaryOutput) {
	kindOrd := a.getKindOrdinal(input)
	a.kindOrdinalToEntry[kindOrd].variantEntryEncode(input, out)
}

func (a *Internal__EnumAdapter[T]) decode(in *binaryInput, keepUnrecognized bool) (T, error) {
	unknown := a.unknownEntry.inst
	wire := in.readUint8()

	if wire < 242 {
		// Constant variant path: wire byte is the start of an integer encoding.
		number := int(decodeNumberBody(wire, in))
		return a.resolveConstantLookup(number, keepUnrecognized, nil)
	}

	// Wrapper variant path: decode the variant number.
	var number int
	if wire == 248 {
		number = int(decodeNumber(in))
	} else {
		number = int(wire) - 250
	}

	entry := a.numberToEntry[number]
	if entry == nil {
		// Unrecognized wrapper variant.
		if keepUnrecognized {
			allBytes := readUnrecognizedWrapperBytes(number, wire, in)
			return a.unknownEntry.wrapUnrecognized(Internal__NewUnrecognizedVariantFromBytes(allBytes)), nil
		}
		skipValue(in)
		return unknown, nil
	}
	if entry.anyEntryIsRemoved() {
		skipValue(in)
		return unknown, nil
	}
	varEntry := entry.(enumVariantEntry[T])
	if !varEntry.variantEntryIsWrapper() {
		skipValue(in)
		return varEntry.variantEntryConstant(), nil
	}
	return varEntry.wrapDecode(in, keepUnrecognized), nil
}

func readUnrecognizedWrapperBytes(number int, wire uint8, in *binaryInput) []byte {
	var header binaryOutput
	if number >= 1 && number <= 4 {
		header.writeUint8(wire)
	} else {
		header.writeUint8(248)
		encodeUint32(uint32(number), &header)
	}
	start := in.offset
	skipValue(in)
	valueBytes := make([]byte, in.offset-start)
	copy(valueBytes, in.data[start:in.offset])
	return append(header.out.Bytes(), valueBytes...)
}

func (a *Internal__EnumAdapter[T]) typeDescriptor() TypeDescriptor {
	return a.desc
}

// Serializer returns a Serializer[T] backed by this adapter.
func (a *Internal__EnumAdapter[T]) Serializer() Serializer[T] {
	return newSerializer[T](a)
}
