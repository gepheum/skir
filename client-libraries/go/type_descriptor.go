package skir_client

import (
	"fmt"
	"sort"
	"strconv"
	"strings"
	"sync"
)

// ─────────────────────────────────────────────────────────────────────────────
// PrimitiveType
// ─────────────────────────────────────────────────────────────────────────────

// PrimitiveType enumerates all primitive types supported by skir.
type PrimitiveType int

const (
	PrimitiveTypeBool PrimitiveType = iota
	PrimitiveTypeInt32
	PrimitiveTypeInt64
	PrimitiveTypeHash64
	PrimitiveTypeFloat32
	PrimitiveTypeFloat64
	PrimitiveTypeTimestamp
	PrimitiveTypeString
	PrimitiveTypeBytes
)

func (p PrimitiveType) String() string {
	switch p {
	case PrimitiveTypeBool:
		return "bool"
	case PrimitiveTypeInt32:
		return "int32"
	case PrimitiveTypeInt64:
		return "int64"
	case PrimitiveTypeHash64:
		return "hash64"
	case PrimitiveTypeFloat32:
		return "float32"
	case PrimitiveTypeFloat64:
		return "float64"
	case PrimitiveTypeTimestamp:
		return "timestamp"
	case PrimitiveTypeString:
		return "string"
	case PrimitiveTypeBytes:
		return "bytes"
	default:
		return fmt.Sprintf("PrimitiveType(%d)", int(p))
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// TypeDescriptor – sealed interface
// ─────────────────────────────────────────────────────────────────────────────

// TypeDescriptor describes a skir type.
//
// The concrete types that implement TypeDescriptor are:
//   - *PrimitiveDescriptor
//   - *OptionalDescriptor
//   - *ArrayDescriptor
//   - *StructDescriptor
//   - *EnumDescriptor
//
// The unexported method sealTypeDescriptor prevents implementations outside
// this package.
type TypeDescriptor interface {
	sealTypeDescriptor()

	// AsJson returns the complete, self-describing JSON representation of this
	// type descriptor as a compact JSON string.
	AsJson() string
}

// ─────────────────────────────────────────────────────────────────────────────
// PrimitiveDescriptor
// ─────────────────────────────────────────────────────────────────────────────

// PrimitiveDescriptor describes a primitive skir type.
type PrimitiveDescriptor struct {
	primitiveType PrimitiveType
}

// PrimitiveType returns the PrimitiveType value.
func (d *PrimitiveDescriptor) PrimitiveType() PrimitiveType { return d.primitiveType }

// Singleton instances – one per primitive type.
var (
	BoolDescriptor      = &PrimitiveDescriptor{primitiveType: PrimitiveTypeBool}
	Int32Descriptor     = &PrimitiveDescriptor{primitiveType: PrimitiveTypeInt32}
	Int64Descriptor     = &PrimitiveDescriptor{primitiveType: PrimitiveTypeInt64}
	Hash64Descriptor    = &PrimitiveDescriptor{primitiveType: PrimitiveTypeHash64}
	Float32Descriptor   = &PrimitiveDescriptor{primitiveType: PrimitiveTypeFloat32}
	Float64Descriptor   = &PrimitiveDescriptor{primitiveType: PrimitiveTypeFloat64}
	TimestampDescriptor = &PrimitiveDescriptor{primitiveType: PrimitiveTypeTimestamp}
	StringDescriptor    = &PrimitiveDescriptor{primitiveType: PrimitiveTypeString}
	BytesDescriptor     = &PrimitiveDescriptor{primitiveType: PrimitiveTypeBytes}
)

// primitiveDescriptorByType returns the singleton PrimitiveDescriptor for pt.
func primitiveDescriptorByType(pt PrimitiveType) *PrimitiveDescriptor {
	switch pt {
	case PrimitiveTypeBool:
		return BoolDescriptor
	case PrimitiveTypeInt32:
		return Int32Descriptor
	case PrimitiveTypeInt64:
		return Int64Descriptor
	case PrimitiveTypeHash64:
		return Hash64Descriptor
	case PrimitiveTypeFloat32:
		return Float32Descriptor
	case PrimitiveTypeFloat64:
		return Float64Descriptor
	case PrimitiveTypeTimestamp:
		return TimestampDescriptor
	case PrimitiveTypeString:
		return StringDescriptor
	case PrimitiveTypeBytes:
		return BytesDescriptor
	default:
		panic(fmt.Sprintf("unknown PrimitiveType %d", int(pt)))
	}
}

func (d *PrimitiveDescriptor) sealTypeDescriptor() {}
func (d *PrimitiveDescriptor) AsJson() string      { return typeDescriptorToJson(d) }

// ─────────────────────────────────────────────────────────────────────────────
// OptionalDescriptor
// ─────────────────────────────────────────────────────────────────────────────

// OptionalDescriptor describes an optional type that can hold either a value of
// the wrapped type or a null/zero value.
type OptionalDescriptor struct {
	otherType TypeDescriptor
}

// OtherType returns the type descriptor for the wrapped non-null type.
func (d *OptionalDescriptor) OtherType() TypeDescriptor { return d.otherType }

func (d *OptionalDescriptor) sealTypeDescriptor() {}
func (d *OptionalDescriptor) AsJson() string      { return typeDescriptorToJson(d) }

// ─────────────────────────────────────────────────────────────────────────────
// ArrayDescriptor
// ─────────────────────────────────────────────────────────────────────────────

// ArrayDescriptor describes an ordered collection of elements of a single type.
type ArrayDescriptor struct {
	itemType TypeDescriptor

	// keyExtractor, when non-empty, is the key chain specified in the '.skir'
	// file after the pipe character. It identifies a property of itemType that
	// can be used for fast keyed lookup.
	keyExtractor string
}

// ItemType returns the type descriptor for each array element.
func (d *ArrayDescriptor) ItemType() TypeDescriptor { return d.itemType }

// KeyExtractor returns the key chain string, or empty if none.
func (d *ArrayDescriptor) KeyExtractor() string { return d.keyExtractor }

func (d *ArrayDescriptor) sealTypeDescriptor() {}
func (d *ArrayDescriptor) AsJson() string      { return typeDescriptorToJson(d) }

// ─────────────────────────────────────────────────────────────────────────────
// StructField
// ─────────────────────────────────────────────────────────────────────────────

// StructField describes a single field of a skir struct.
type StructField struct {
	name      string
	number    int
	fieldType TypeDescriptor
	doc       string
}

func (f *StructField) Name() string         { return f.name }
func (f *StructField) Number() int          { return f.number }
func (f *StructField) Type() TypeDescriptor { return f.fieldType }
func (f *StructField) Doc() string          { return f.doc }

// ─────────────────────────────────────────────────────────────────────────────
// EnumVariant – sealed interface
// ─────────────────────────────────────────────────────────────────────────────

// EnumVariant is the common interface for skir enum variants.
// Concrete types: *EnumConstantVariant, *EnumWrapperVariant.
type EnumVariant interface {
	Name() string
	Number() int
	Doc() string
	sealEnumVariant()
}

// ─────────────────────────────────────────────────────────────────────────────
// EnumConstantVariant
// ─────────────────────────────────────────────────────────────────────────────

// EnumConstantVariant describes a constant (non-wrapping) enum variant.
type EnumConstantVariant struct {
	name   string
	number int
	doc    string
}

func (v *EnumConstantVariant) Name() string     { return v.name }
func (v *EnumConstantVariant) Number() int      { return v.number }
func (v *EnumConstantVariant) Doc() string      { return v.doc }
func (v *EnumConstantVariant) sealEnumVariant() {}

// ─────────────────────────────────────────────────────────────────────────────
// EnumWrapperVariant
// ─────────────────────────────────────────────────────────────────────────────

// EnumWrapperVariant describes an enum variant that wraps a value of another type.
type EnumWrapperVariant struct {
	name        string
	number      int
	variantType TypeDescriptor
	doc         string
}

func (v *EnumWrapperVariant) Name() string         { return v.name }
func (v *EnumWrapperVariant) Number() int          { return v.number }
func (v *EnumWrapperVariant) Type() TypeDescriptor { return v.variantType }
func (v *EnumWrapperVariant) Doc() string          { return v.doc }
func (v *EnumWrapperVariant) sealEnumVariant()     {}

// ─────────────────────────────────────────────────────────────────────────────
// RecordDescriptorBase
// ─────────────────────────────────────────────────────────────────────────────

// RecordDescriptorBase provides common metadata for struct and enum descriptors.
type RecordDescriptorBase interface {
	TypeDescriptor

	// Name of the record as specified in the '.skir' file.
	Name() string

	// QualifiedName contains all names in the hierarchical sequence, e.g.
	// "Foo.Bar" if Bar is nested within Foo, or simply "Bar" for top-level.
	QualifiedName() string

	// ModulePath is the path to the '.skir' file relative to the skir source root.
	ModulePath() string

	// Doc is the documentation extracted from doc comments in the '.skir' file.
	Doc() string

	// RemovedNumbers returns the set of field/variant numbers that have been
	// marked as removed (reserved).
	RemovedNumbers() map[int]struct{}

	// recordId returns "modulePath:qualifiedName".
	recordId() string
}

// ─────────────────────────────────────────────────────────────────────────────
// StructDescriptor
// ─────────────────────────────────────────────────────────────────────────────

// StructDescriptor describes a skir struct type.
type StructDescriptor struct {
	name           string
	qualifiedName  string
	modulePath     string
	doc            string
	removedNumbers map[int]struct{}
	fields         []*StructField

	// Lazy lookup maps, initialised on first use.
	once          sync.Once
	nameToField   map[string]*StructField
	numberToField map[int]*StructField
}

func newStructDescriptor(
	modulePath string,
	qualifiedName string,
	doc string,
	removedNumbers map[int]struct{},
	fields []*StructField,
) *StructDescriptor {
	name := qualifiedName
	if i := lastDotIndex(qualifiedName); i >= 0 {
		name = qualifiedName[i+1:]
	}
	return &StructDescriptor{
		name:           name,
		qualifiedName:  qualifiedName,
		modulePath:     modulePath,
		doc:            doc,
		removedNumbers: removedNumbers,
		fields:         fields,
	}
}

func (d *StructDescriptor) sealTypeDescriptor()              {}
func (d *StructDescriptor) Name() string                     { return d.name }
func (d *StructDescriptor) QualifiedName() string            { return d.qualifiedName }
func (d *StructDescriptor) ModulePath() string               { return d.modulePath }
func (d *StructDescriptor) Doc() string                      { return d.doc }
func (d *StructDescriptor) RemovedNumbers() map[int]struct{} { return d.removedNumbers }
func (d *StructDescriptor) Fields() []*StructField           { return d.fields }
func (d *StructDescriptor) recordId() string                 { return d.modulePath + ":" + d.qualifiedName }
func (d *StructDescriptor) AsJson() string                   { return typeDescriptorToJson(d) }

func (d *StructDescriptor) initLookups() {
	d.once.Do(func() {
		nm := make(map[string]*StructField, len(d.fields))
		num := make(map[int]*StructField, len(d.fields))
		for _, f := range d.fields {
			nm[f.name] = f
			num[f.number] = f
		}
		d.nameToField = nm
		d.numberToField = num
	})
}

// FieldByName returns the field with the given name, or nil if not found.
func (d *StructDescriptor) FieldByName(name string) *StructField {
	d.initLookups()
	return d.nameToField[name]
}

// FieldByNumber returns the field with the given number, or nil if not found.
func (d *StructDescriptor) FieldByNumber(number int) *StructField {
	d.initLookups()
	return d.numberToField[number]
}

// ─────────────────────────────────────────────────────────────────────────────
// EnumDescriptor
// ─────────────────────────────────────────────────────────────────────────────

// EnumDescriptor describes a skir enum type.
type EnumDescriptor struct {
	name           string
	qualifiedName  string
	modulePath     string
	doc            string
	removedNumbers map[int]struct{}
	variants       []EnumVariant

	// Lazy lookup maps, initialised on first use.
	once            sync.Once
	nameToVariant   map[string]EnumVariant
	numberToVariant map[int]EnumVariant
}

func newEnumDescriptor(
	modulePath string,
	qualifiedName string,
	doc string,
	removedNumbers map[int]struct{},
	variants []EnumVariant,
) *EnumDescriptor {
	name := qualifiedName
	if i := lastDotIndex(qualifiedName); i >= 0 {
		name = qualifiedName[i+1:]
	}
	return &EnumDescriptor{
		name:           name,
		qualifiedName:  qualifiedName,
		modulePath:     modulePath,
		doc:            doc,
		removedNumbers: removedNumbers,
		variants:       variants,
	}
}

func (d *EnumDescriptor) sealTypeDescriptor()              {}
func (d *EnumDescriptor) Name() string                     { return d.name }
func (d *EnumDescriptor) QualifiedName() string            { return d.qualifiedName }
func (d *EnumDescriptor) ModulePath() string               { return d.modulePath }
func (d *EnumDescriptor) Doc() string                      { return d.doc }
func (d *EnumDescriptor) RemovedNumbers() map[int]struct{} { return d.removedNumbers }
func (d *EnumDescriptor) Variants() []EnumVariant          { return d.variants }
func (d *EnumDescriptor) recordId() string                 { return d.modulePath + ":" + d.qualifiedName }
func (d *EnumDescriptor) AsJson() string                   { return typeDescriptorToJson(d) }

func (d *EnumDescriptor) initLookups() {
	d.once.Do(func() {
		nm := make(map[string]EnumVariant, len(d.variants))
		num := make(map[int]EnumVariant, len(d.variants))
		for _, v := range d.variants {
			nm[v.Name()] = v
			num[v.Number()] = v
		}
		d.nameToVariant = nm
		d.numberToVariant = num
	})
}

// VariantByName returns the variant with the given name, or nil if not found.
func (d *EnumDescriptor) VariantByName(name string) EnumVariant {
	d.initLookups()
	return d.nameToVariant[name]
}

// VariantByNumber returns the variant with the given number, or nil if not found.
func (d *EnumDescriptor) VariantByNumber(number int) EnumVariant {
	d.initLookups()
	return d.numberToVariant[number]
}

// ─────────────────────────────────────────────────────────────────────────────
// JSON serialization
// ─────────────────────────────────────────────────────────────────────────────

// typeDescriptorToJson serialises td to a self-describing JSON string with
// 2-space indentation:
//
//	{
//	  "type": <type-signature>,
//	  "records": [<record-definition>, ...]
//	}
func typeDescriptorToJson(td TypeDescriptor) string {
	var out strings.Builder

	var order []string
	recordIdToJson := map[string]string{}

	var addRecordDefinitions func(t TypeDescriptor)
	addRecordDefinitions = func(t TypeDescriptor) {
		switch v := t.(type) {
		case *PrimitiveDescriptor:
			// no record definitions
		case *OptionalDescriptor:
			addRecordDefinitions(v.otherType)
		case *ArrayDescriptor:
			addRecordDefinitions(v.itemType)
		case *StructDescriptor:
			rid := v.recordId()
			if _, seen := recordIdToJson[rid]; seen {
				return
			}
			recordIdToJson[rid] = "" // mark as in-progress to break cycles
			var sb strings.Builder
			writeStructRecordJson(v, "    ", &sb)
			recordIdToJson[rid] = sb.String()
			order = append(order, rid)
			for _, f := range v.fields {
				addRecordDefinitions(f.fieldType)
			}
		case *EnumDescriptor:
			rid := v.recordId()
			if _, seen := recordIdToJson[rid]; seen {
				return
			}
			recordIdToJson[rid] = "" // mark as in-progress to break cycles
			var sb strings.Builder
			writeEnumRecordJson(v, "    ", &sb)
			recordIdToJson[rid] = sb.String()
			order = append(order, rid)
			for _, variant := range v.variants {
				if w, ok := variant.(*EnumWrapperVariant); ok {
					addRecordDefinitions(w.variantType)
				}
			}
		}
	}

	addRecordDefinitions(td)

	out.WriteString("{\n  \"type\": ")
	typeSignatureToJson(td, "  ", &out)
	out.WriteString(",\n  \"records\": [")
	for i, id := range order {
		if i > 0 {
			out.WriteByte(',')
		}
		out.WriteString("\n    ")
		out.WriteString(recordIdToJson[id])
	}
	if len(order) > 0 {
		out.WriteString("\n  ")
	}
	out.WriteString("]\n}")
	return out.String()
}

// writeStructRecordJson writes a pretty-printed JSON object for a struct record
// definition to out. indent is the indentation level of the closing `}`.
func writeStructRecordJson(v *StructDescriptor, indent string, out *strings.Builder) {
	inner := indent + "  "
	fieldIndent := inner + "  "
	fieldBody := fieldIndent + "  "
	out.WriteString("{\n")
	out.WriteString(inner + "\"kind\": \"struct\",\n")
	out.WriteString(inner + "\"id\": ")
	writeJsonEscapedString(v.recordId(), out)
	if v.doc != "" {
		out.WriteString(",\n")
		out.WriteString(inner + "\"doc\": ")
		writeJsonEscapedString(v.doc, out)
	}
	out.WriteString(",\n")
	out.WriteString(inner + "\"fields\": [")
	for i, f := range v.fields {
		if i > 0 {
			out.WriteByte(',')
		}
		out.WriteString("\n")
		out.WriteString(fieldIndent + "{\n")
		out.WriteString(fieldBody + "\"name\": ")
		writeJsonEscapedString(f.name, out)
		out.WriteString(",\n")
		out.WriteString(fieldBody + "\"number\": ")
		out.WriteString(strconv.Itoa(f.number))
		out.WriteString(",\n")
		out.WriteString(fieldBody + "\"type\": ")
		typeSignatureToJson(f.fieldType, fieldBody, out)
		if f.doc != "" {
			out.WriteString(",\n")
			out.WriteString(fieldBody + "\"doc\": ")
			writeJsonEscapedString(f.doc, out)
		}
		out.WriteString("\n")
		out.WriteString(fieldIndent + "}")
	}
	if len(v.fields) > 0 {
		out.WriteString("\n")
		out.WriteString(inner)
	}
	out.WriteString("]")
	removedSlice := removedNumbersToSortedSlice(v.removedNumbers)
	if len(removedSlice) > 0 {
		out.WriteString(",\n")
		out.WriteString(inner + "\"removed_numbers\": [")
		for i, n := range removedSlice {
			if i > 0 {
				out.WriteByte(',')
			}
			out.WriteString("\n")
			out.WriteString(fieldIndent)
			out.WriteString(strconv.Itoa(n))
		}
		out.WriteString("\n")
		out.WriteString(inner + "]")
	}
	out.WriteString("\n")
	out.WriteString(indent + "}")
}

// writeEnumRecordJson writes a pretty-printed JSON object for an enum record
// definition to out. indent is the indentation level of the closing `}`.
// Variants are emitted sorted by number for deterministic output.
func writeEnumRecordJson(v *EnumDescriptor, indent string, out *strings.Builder) {
	inner := indent + "  "
	variantIndent := inner + "  "
	variantBody := variantIndent + "  "
	out.WriteString("{\n")
	out.WriteString(inner + "\"kind\": \"enum\",\n")
	out.WriteString(inner + "\"id\": ")
	writeJsonEscapedString(v.recordId(), out)
	if v.doc != "" {
		out.WriteString(",\n")
		out.WriteString(inner + "\"doc\": ")
		writeJsonEscapedString(v.doc, out)
	}
	out.WriteString(",\n")
	out.WriteString(inner + "\"variants\": [")
	sorted := make([]EnumVariant, len(v.variants))
	copy(sorted, v.variants)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Number() < sorted[j].Number()
	})
	for i, variant := range sorted {
		if i > 0 {
			out.WriteByte(',')
		}
		out.WriteString("\n")
		out.WriteString(variantIndent + "{\n")
		out.WriteString(variantBody + "\"name\": ")
		writeJsonEscapedString(variant.Name(), out)
		out.WriteString(",\n")
		out.WriteString(variantBody + "\"number\": ")
		out.WriteString(strconv.Itoa(variant.Number()))
		if w, ok := variant.(*EnumWrapperVariant); ok {
			out.WriteString(",\n")
			out.WriteString(variantBody + "\"type\": ")
			typeSignatureToJson(w.variantType, variantBody, out)
		}
		if variant.Doc() != "" {
			out.WriteString(",\n")
			out.WriteString(variantBody + "\"doc\": ")
			writeJsonEscapedString(variant.Doc(), out)
		}
		out.WriteString("\n")
		out.WriteString(variantIndent + "}")
	}
	if len(sorted) > 0 {
		out.WriteString("\n")
		out.WriteString(inner)
	}
	out.WriteString("]")
	removedSlice := removedNumbersToSortedSlice(v.removedNumbers)
	if len(removedSlice) > 0 {
		out.WriteString(",\n")
		out.WriteString(inner + "\"removed_numbers\": [")
		for i, n := range removedSlice {
			if i > 0 {
				out.WriteByte(',')
			}
			out.WriteString("\n")
			out.WriteString(variantIndent)
			out.WriteString(strconv.Itoa(n))
		}
		out.WriteString("\n")
		out.WriteString(inner + "]")
	}
	out.WriteString("\n")
	out.WriteString(indent + "}")
}

// typeSignatureToJson writes a pretty-printed JSON type-signature value for td
// to out. indent is the indentation of the enclosing context: `{` is written
// first (on the current line), the closing `}` is at the indent level.
func typeSignatureToJson(td TypeDescriptor, indent string, out *strings.Builder) {
	inner := indent + "  "
	switch v := td.(type) {
	case *PrimitiveDescriptor:
		out.WriteString("{\n")
		out.WriteString(inner + "\"kind\": \"primitive\",\n")
		out.WriteString(inner + "\"value\": \"")
		out.WriteString(v.primitiveType.String())
		out.WriteString("\"\n")
		out.WriteString(indent + "}")
	case *OptionalDescriptor:
		out.WriteString("{\n")
		out.WriteString(inner + "\"kind\": \"optional\",\n")
		out.WriteString(inner + "\"value\": ")
		typeSignatureToJson(v.otherType, inner, out)
		out.WriteString("\n")
		out.WriteString(indent + "}")
	case *ArrayDescriptor:
		valueIndent := inner + "  "
		out.WriteString("{\n")
		out.WriteString(inner + "\"kind\": \"array\",\n")
		out.WriteString(inner + "\"value\": {\n")
		out.WriteString(valueIndent + "\"item\": ")
		typeSignatureToJson(v.itemType, valueIndent, out)
		if v.keyExtractor != "" {
			out.WriteString(",\n")
			out.WriteString(valueIndent + "\"key_extractor\": ")
			writeJsonEscapedString(v.keyExtractor, out)
		}
		out.WriteString("\n")
		out.WriteString(inner + "}\n")
		out.WriteString(indent + "}")
	case *StructDescriptor:
		out.WriteString("{\n")
		out.WriteString(inner + "\"kind\": \"record\",\n")
		out.WriteString(inner + "\"value\": ")
		writeJsonEscapedString(v.recordId(), out)
		out.WriteString("\n")
		out.WriteString(indent + "}")
	case *EnumDescriptor:
		out.WriteString("{\n")
		out.WriteString(inner + "\"kind\": \"record\",\n")
		out.WriteString(inner + "\"value\": ")
		writeJsonEscapedString(v.recordId(), out)
		out.WriteString("\n")
		out.WriteString(indent + "}")
	default:
		panic(fmt.Sprintf("skir_client: typeSignatureToJson: unknown TypeDescriptor %T", td))
	}
}

// removedNumbersToSortedSlice converts the set to a sorted int slice.
func removedNumbersToSortedSlice(m map[int]struct{}) []int {
	if len(m) == 0 {
		return nil
	}
	s := make([]int, 0, len(m))
	for n := range m {
		s = append(s, n)
	}
	sort.Ints(s)
	return s
}

// lastDotIndex returns the index of the last '.' in s, or -1 if absent.
func lastDotIndex(s string) int {
	for i := len(s) - 1; i >= 0; i-- {
		if s[i] == '.' {
			return i
		}
	}
	return -1
}
