package skir_client

import (
	"fmt"

	"github.com/valyala/fastjson"
)

// ParseTypeDescriptorFromJson parses a TypeDescriptor from its JSON string
// representation (as produced by TypeDescriptor.AsJson).
func ParseTypeDescriptorFromJson(jsonCode string) (TypeDescriptor, error) {
	var p fastjson.Parser
	v, err := p.Parse(jsonCode)
	if err != nil {
		return nil, fmt.Errorf("skir_client.ParseTypeDescriptorFromJson: %w", err)
	}
	return parseTypeDescriptorFromValue(v)
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal parsing
// ─────────────────────────────────────────────────────────────────────────────

// recordBundle holds a partially-constructed record descriptor together with
// the raw JSON array of its fields/variants. The two-pass approach allows
// forward references between mutually-referencing record types.
type recordBundle struct {
	descriptor       RecordDescriptorBase
	fieldsOrVariants []*fastjson.Value
}

func parseTypeDescriptorFromValue(root *fastjson.Value) (TypeDescriptor, error) {
	// ── Pass 1: create all record descriptors (without fields/variants) ──────
	recordIdToBundle := map[string]*recordBundle{}

	for _, rec := range root.GetArray("records") {
		partial, err := parseRecordDescriptorPartial(rec)
		if err != nil {
			return nil, err
		}
		rid := partial.recordId()

		// Prefer "fields" (structs); fall back to "variants" (enums).
		fieldsOrVariants := rec.GetArray("fields")
		if fieldsOrVariants == nil {
			fieldsOrVariants = rec.GetArray("variants")
		}

		recordIdToBundle[rid] = &recordBundle{
			descriptor:       partial,
			fieldsOrVariants: fieldsOrVariants,
		}
	}

	// ── Pass 2: fill in fields / variants ────────────────────────────────────
	for _, bundle := range recordIdToBundle {
		switch d := bundle.descriptor.(type) {
		case *StructDescriptor:
			fields := make([]*StructField, 0, len(bundle.fieldsOrVariants))
			for _, fv := range bundle.fieldsOrVariants {
				name := string(fv.GetStringBytes("name"))
				number := fv.GetInt("number")
				typeVal := fv.Get("type")
				if typeVal == nil {
					return nil, fmt.Errorf("skir_client: struct field %q is missing 'type'", name)
				}
				t, err := parseTypeSignature(typeVal, recordIdToBundle)
				if err != nil {
					return nil, err
				}
				doc := string(fv.GetStringBytes("doc"))
				fields = append(fields, &StructField{
					name:      name,
					number:    number,
					fieldType: t,
					doc:       doc,
				})
			}
			d.fields = fields

		case *EnumDescriptor:
			variants := make([]EnumVariant, 0, len(bundle.fieldsOrVariants))
			for _, vv := range bundle.fieldsOrVariants {
				name := string(vv.GetStringBytes("name"))
				number := vv.GetInt("number")
				doc := string(vv.GetStringBytes("doc"))
				typeVal := vv.Get("type")
				if typeVal != nil {
					t, err := parseTypeSignature(typeVal, recordIdToBundle)
					if err != nil {
						return nil, err
					}
					variants = append(variants, &EnumWrapperVariant{
						name:        name,
						number:      number,
						variantType: t,
						doc:         doc,
					})
				} else {
					variants = append(variants, &EnumConstantVariant{
						name:   name,
						number: number,
						doc:    doc,
					})
				}
			}
			d.variants = variants
		}
	}

	// ── Resolve the root type ─────────────────────────────────────────────────
	typeVal := root.Get("type")
	if typeVal == nil {
		return nil, fmt.Errorf("skir_client: type descriptor JSON is missing 'type'")
	}
	return parseTypeSignature(typeVal, recordIdToBundle)
}

// parseRecordDescriptorPartial constructs a StructDescriptor or EnumDescriptor
// from a record JSON object without populating its fields/variants.
func parseRecordDescriptorPartial(v *fastjson.Value) (RecordDescriptorBase, error) {
	kind := string(v.GetStringBytes("kind"))
	idStr := string(v.GetStringBytes("id"))
	doc := string(v.GetStringBytes("doc"))

	modulePath, qualifiedName, err := splitRecordId(idStr)
	if err != nil {
		return nil, err
	}

	removedNumbers := map[int]struct{}{}
	for _, rn := range v.GetArray("removed_numbers") {
		n, err := rn.Int()
		if err != nil {
			return nil, fmt.Errorf("skir_client: invalid removed_number value: %w", err)
		}
		removedNumbers[n] = struct{}{}
	}

	switch kind {
	case "struct":
		return newStructDescriptor(modulePath, qualifiedName, doc, removedNumbers, nil), nil
	case "enum":
		return newEnumDescriptor(modulePath, qualifiedName, doc, removedNumbers, nil), nil
	default:
		return nil, fmt.Errorf("skir_client: unknown record kind %q", kind)
	}
}

// parseTypeSignature reconstructs a TypeDescriptor from a type-signature JSON
// object (the compact representation stored under the "type" key of fields and
// of the root document).
func parseTypeSignature(v *fastjson.Value, recordIdToBundle map[string]*recordBundle) (TypeDescriptor, error) {
	kind := string(v.GetStringBytes("kind"))
	val := v.Get("value")
	if val == nil {
		return nil, fmt.Errorf("skir_client: type signature missing 'value' (kind=%q)", kind)
	}

	switch kind {
	case "primitive":
		switch string(val.GetStringBytes()) {
		case "bool":
			return BoolDescriptor, nil
		case "int32":
			return Int32Descriptor, nil
		case "int64":
			return Int64Descriptor, nil
		case "hash64":
			return Hash64Descriptor, nil
		case "float32":
			return Float32Descriptor, nil
		case "float64":
			return Float64Descriptor, nil
		case "timestamp":
			return TimestampDescriptor, nil
		case "string":
			return StringDescriptor, nil
		case "bytes":
			return BytesDescriptor, nil
		default:
			return nil, fmt.Errorf("skir_client: unknown primitive type %q", string(val.GetStringBytes()))
		}

	case "optional":
		inner, err := parseTypeSignature(val, recordIdToBundle)
		if err != nil {
			return nil, err
		}
		return &OptionalDescriptor{otherType: inner}, nil

	case "array":
		itemVal := val.Get("item")
		if itemVal == nil {
			return nil, fmt.Errorf("skir_client: array type signature missing 'item'")
		}
		itemType, err := parseTypeSignature(itemVal, recordIdToBundle)
		if err != nil {
			return nil, err
		}
		keyExtractor := string(val.GetStringBytes("key_extractor"))
		return &ArrayDescriptor{itemType: itemType, keyExtractor: keyExtractor}, nil

	case "record":
		recordId := string(val.GetStringBytes())
		bundle, ok := recordIdToBundle[recordId]
		if !ok {
			return nil, fmt.Errorf("skir_client: unknown record id %q", recordId)
		}
		return bundle.descriptor, nil

	default:
		return nil, fmt.Errorf("skir_client: unknown type kind %q", kind)
	}
}

// splitRecordId splits a record id of the form "modulePath:qualifiedName"
// into its two components.
func splitRecordId(id string) (modulePath, qualifiedName string, err error) {
	for i := 0; i < len(id); i++ {
		if id[i] == ':' {
			return id[:i], id[i+1:], nil
		}
	}
	return "", "", fmt.Errorf("skir_client: malformed record id %q (expected 'modulePath:qualifiedName')", id)
}
