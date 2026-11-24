pub mod internal {

    use std::collections::{HashMap, HashSet};
    use std::sync::Arc;

    use super::super::reflection::{
        EnumConstantVariant, EnumDescriptor, EnumVariant, EnumWrapperVariant, TypeDescriptor,
    };
    use super::super::serializer::{Serializer, TypeAdapter};
    use super::super::serializers::{
        decode_number, decode_number_body, encode_uint32, read_u8, skip_value,
        write_json_escaped_string,
    };
    use super::super::unrecognized::{
        UnrecognizedFormat, UnrecognizedVariant, UnrecognizedVariantData,
    };

    // =============================================================================
    // AnyEntry – maps a variant number to how it should be handled
    // =============================================================================

    enum AnyEntry {
        Removed,
        Constant(usize), // kind_ordinal
        Wrapper(usize),  // kind_ordinal
    }

    // =============================================================================
    // VariantEntry – type-erased per-variant adapter
    // =============================================================================

    trait VariantEntry<T>: Send + Sync {
        fn number(&self) -> i32;
        /// Returns `Some(value)` for a constant variant, `None` for a wrapper variant.
        fn constant(&self) -> Option<T>;
        fn to_json(&self, frozen: &T, eol_indent: Option<&str>, out: &mut String);
        fn encode_value(&self, frozen: &T, out: &mut Vec<u8>);
        fn wrap_from_json(&self, v: &serde_json::Value, keep: bool) -> Result<T, String>;
        fn wrap_decode(&self, input: &mut &[u8], keep: bool) -> Result<T, String>;
        fn wrap_default(&self) -> Option<T> {
            None
        }
    }

    // =============================================================================
    // ConstantEntry
    // =============================================================================

    struct ConstantEntry<T: 'static + Clone + Send + Sync> {
        name: String,
        number: i32,
        instance: T,
    }

    impl<T: 'static + Clone + Send + Sync> VariantEntry<T> for ConstantEntry<T> {
        fn number(&self) -> i32 {
            self.number
        }
        fn constant(&self) -> Option<T> {
            Some(self.instance.clone())
        }

        fn to_json(&self, _frozen: &T, eol_indent: Option<&str>, out: &mut String) {
            if eol_indent.is_some() {
                // Readable: emit the variant name as a JSON string.
                write_json_escaped_string(&self.name, out);
            } else {
                // Dense: emit the variant number as a decimal string.
                out.push_str(&self.number.to_string());
            }
        }

        fn encode_value(&self, _frozen: &T, out: &mut Vec<u8>) {
            encode_uint32(self.number as u32, out);
        }

        fn wrap_from_json(&self, _v: &serde_json::Value, _keep: bool) -> Result<T, String> {
            Err(format!(
                "variant '{}' is a constant, not a wrapper",
                self.name
            ))
        }

        fn wrap_decode(&self, _input: &mut &[u8], _keep: bool) -> Result<T, String> {
            Err(format!(
                "variant '{}' is a constant, not a wrapper",
                self.name
            ))
        }
    }

    // =============================================================================
    // WrapperEntry
    // =============================================================================

    struct WrapperEntry<T: 'static, V: 'static> {
        name: String,
        number: i32,
        ser: Serializer<V>,
        wrap: fn(V) -> T,
        get_value: fn(&T) -> &V,
    }

    impl<T: 'static, V: 'static> VariantEntry<T> for WrapperEntry<T, V> {
        fn number(&self) -> i32 {
            self.number
        }
        fn constant(&self) -> Option<T> {
            None
        }

        fn to_json(&self, frozen: &T, eol_indent: Option<&str>, out: &mut String) {
            let v = (self.get_value)(frozen);
            if let Some(indent) = eol_indent {
                // Readable: {"kind": "NAME", "value": <value>}
                let child_indent = format!("{indent}  ");
                out.push('{');
                out.push_str(&child_indent);
                out.push_str("\"kind\": ");
                write_json_escaped_string(&self.name, out);
                out.push(',');
                out.push_str(&child_indent);
                out.push_str("\"value\": ");
                self.ser.adapter().to_json(v, Some(&child_indent), out);
                out.push_str(indent);
                out.push('}');
            } else {
                // Dense: [number, value_json]
                out.push('[');
                out.push_str(&self.number.to_string());
                out.push(',');
                self.ser.adapter().to_json(v, None, out);
                out.push(']');
            }
        }

        fn encode_value(&self, frozen: &T, out: &mut Vec<u8>) {
            let v = (self.get_value)(frozen);
            self.ser.adapter().encode(v, out);
        }

        fn wrap_from_json(&self, v: &serde_json::Value, keep: bool) -> Result<T, String> {
            let inner = self.ser.adapter().from_json(v, keep)?;
            Ok((self.wrap)(inner))
        }

        fn wrap_decode(&self, input: &mut &[u8], keep: bool) -> Result<T, String> {
            let inner = self.ser.adapter().decode(input, keep)?;
            Ok((self.wrap)(inner))
        }

        fn wrap_default(&self) -> Option<T> {
            self.ser
                .adapter()
                .from_json(&serde_json::Value::from(0), false)
                .ok()
                .map(self.wrap)
        }
    }

    // =============================================================================
    // EnumAdapter
    // =============================================================================

    /// Implements [`TypeAdapter<T>`] for a Skir enum type.
    ///
    /// For use only by code generated by the Skir Rust code generator.
    ///
    /// - `T` is the enum type.
    ///
    /// Usage: call [`EnumAdapter::new`], then register variants with
    /// [`EnumAdapter::add_constant_variant`] / [`EnumAdapter::add_wrapper_variant`] /
    /// [`EnumAdapter::add_removed_number`], then call
    /// [`EnumAdapter::finalize`].
    pub struct EnumAdapter<T: 'static + Default> {
        get_kind_ordinal: fn(&T) -> usize,
        wrap_unrecognized: fn(UnrecognizedVariant<T>) -> T,
        get_unrecognized: fn(&T) -> Option<&UnrecognizedVariantData<T>>,
        /// Maps variant number → how to handle it (removed / constant / wrapper).
        number_to_entry: HashMap<i32, AnyEntry>,
        /// Accumulates removed numbers to pass to the descriptor on finalize.
        removed_numbers: HashSet<i32>,
        /// Maps variant name → kind_ordinal (for known, non-removed variants).
        name_to_kind_ordinal: HashMap<String, usize>,
        /// Indexed by kind_ordinal. Index 0 is always None (UNKNOWN pseudo-entry).
        kind_ordinal_to_entry: Vec<Option<Box<dyn VariantEntry<T>>>>,
        /// Accumulates variants to pass to the descriptor on finalize.
        desc_variants: Vec<EnumVariant>,
        /// Pre-allocated descriptor so [`descriptor()`] is valid before finalization.
        desc: Arc<EnumDescriptor>,
    }

    impl<T: 'static + Default> EnumAdapter<T> {
        /// Creates a new `EnumAdapter`.
        pub fn new(
            get_kind_ordinal: fn(&T) -> usize,
            wrap_unrecognized: fn(UnrecognizedVariant<T>) -> T,
            get_unrecognized: fn(&T) -> Option<&UnrecognizedVariantData<T>>,
            module_path: &str,
            qualified_name: &str,
            doc: &str,
        ) -> Self {
            let desc = Arc::new(EnumDescriptor::new(
                module_path.to_string(),
                qualified_name.to_string(),
                doc.to_string(),
            ));
            // Slot 0 is reserved for UNKNOWN (kind_ordinal 0 → no variant entry).
            let kind_ordinal_to_entry = vec![None];
            EnumAdapter {
                get_kind_ordinal,
                wrap_unrecognized,
                get_unrecognized,
                number_to_entry: HashMap::new(),
                removed_numbers: HashSet::new(),
                name_to_kind_ordinal: HashMap::new(),
                kind_ordinal_to_entry,
                desc_variants: Vec::new(),
                desc,
            }
        }

        /// Registers a constant (non-wrapping) enum variant.
        pub fn add_constant_variant(
            &mut self,
            name: &str,
            number: i32,
            kind_ordinal: usize,
            doc: &str,
            instance: T,
        ) where
            T: Clone + Send + Sync,
        {
            self.number_to_entry
                .insert(number, AnyEntry::Constant(kind_ordinal));
            self.name_to_kind_ordinal
                .insert(name.to_string(), kind_ordinal);
            let name_upper = name.to_uppercase();
            if name_upper != name {
                self.name_to_kind_ordinal.insert(name_upper, kind_ordinal);
            }
            let name_lower = name.to_lowercase();
            if name_lower != name {
                self.name_to_kind_ordinal.insert(name_lower, kind_ordinal);
            }
            let entry: Box<dyn VariantEntry<T>> = Box::new(ConstantEntry {
                name: name.to_string(),
                number,
                instance,
            });
            self.set_kind_ordinal_entry(kind_ordinal, entry);
            self.desc_variants
                .push(EnumVariant::Constant(EnumConstantVariant::new(
                    name.to_string(),
                    number,
                    doc.to_string(),
                )));
        }

        /// Registers a wrapper enum variant.
        pub fn add_wrapper_variant<V: 'static>(
            &mut self,
            name: &str,
            number: i32,
            kind_ordinal: usize,
            ser: Serializer<V>,
            doc: &str,
            wrap: fn(V) -> T,
            get_value: fn(&T) -> &V,
        ) {
            let type_desc = ser.adapter().type_descriptor();
            self.number_to_entry
                .insert(number, AnyEntry::Wrapper(kind_ordinal));
            self.name_to_kind_ordinal
                .insert(name.to_string(), kind_ordinal);
            let entry: Box<dyn VariantEntry<T>> = Box::new(WrapperEntry {
                name: name.to_string(),
                number,
                ser,
                wrap,
                get_value,
            });
            self.set_kind_ordinal_entry(kind_ordinal, entry);
            self.desc_variants
                .push(EnumVariant::Wrapper(EnumWrapperVariant::new(
                    name.to_string(),
                    number,
                    type_desc,
                    doc.to_string(),
                )));
        }

        /// Registers a variant number that was removed from the schema.
        pub fn add_removed_number(&mut self, number: i32) {
            self.number_to_entry.insert(number, AnyEntry::Removed);
            self.removed_numbers.insert(number);
        }

        fn set_kind_ordinal_entry(&mut self, kind_ordinal: usize, entry: Box<dyn VariantEntry<T>>) {
            if kind_ordinal >= self.kind_ordinal_to_entry.len() {
                self.kind_ordinal_to_entry
                    .resize_with(kind_ordinal + 1, || None);
            }
            self.kind_ordinal_to_entry[kind_ordinal] = Some(entry);
        }

        pub fn finalize(&mut self) {
            self.name_to_kind_ordinal.insert("UNKNOWN".to_string(), 0);
            self.name_to_kind_ordinal.insert("unknown".to_string(), 0);
            self.desc_variants.sort_by_key(|v| v.number());
            let variants = std::mem::take(&mut self.desc_variants);
            self.desc.set_variants(variants);
            self.desc
                .set_removed_numbers(std::mem::take(&mut self.removed_numbers));
        }

        /// Returns a reference to the pre-allocated [`EnumDescriptor`] for this
        /// adapter. Valid even before it is finalized, which is necessary for
        /// recursive enum variant types.
        pub fn descriptor(&self) -> Arc<EnumDescriptor> {
            Arc::clone(&self.desc)
        }

        // -----------------------------------------------------------------------
        // TypeAdapter implementation helpers
        // -----------------------------------------------------------------------

        fn is_default_impl(&self, input: &T) -> bool {
            (self.get_kind_ordinal)(input) == 0
        }

        fn to_json_impl(&self, input: &T, eol_indent: Option<&str>, out: &mut String) {
            let ko = (self.get_kind_ordinal)(input);
            if ko == 0 {
                self.unknown_to_json(input, eol_indent, out);
                return;
            }
            if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(ko) {
                entry.to_json(input, eol_indent, out);
            } else {
                // Fallback: shouldn't happen with well-formed generated code.
                if eol_indent.is_some() {
                    out.push_str("\"unknown\"");
                } else {
                    out.push('0');
                }
            }
        }

        fn unknown_to_json(&self, input: &T, eol_indent: Option<&str>, out: &mut String) {
            if eol_indent.is_some() {
                out.push_str("\"unknown\"");
                return;
            }
            // Dense: emit stored JSON if available. For byte-preserved unknown
            // enum variants, emit the stored variant number.
            if let Some(u) = (self.get_unrecognized)(input) {
                if u.format == UnrecognizedFormat::DenseJson && !u.value.is_empty() {
                    out.push_str(std::str::from_utf8(&u.value).unwrap_or("0"));
                    return;
                }
                if u.format == UnrecognizedFormat::Bytes
                    && self.number_to_entry.contains_key(&u.number)
                {
                    out.push_str(&u.number.to_string());
                    return;
                }
            }
            out.push('0');
        }

        fn from_json_impl(&self, v: &serde_json::Value, keep: bool) -> Result<T, String> {
            match v {
                serde_json::Value::Number(n) => {
                    let num = n.as_i64().unwrap_or(0) as i32;
                    Ok(self.resolve_constant_lookup(num, keep, Some(v)))
                }
                serde_json::Value::Bool(b) => {
                    let num = if *b { 1 } else { 0 };
                    Ok(self.resolve_constant_lookup(num, keep, Some(v)))
                }
                serde_json::Value::String(s) => match self.name_to_kind_ordinal.get(s.as_str()) {
                    None => Ok(T::default()),
                    Some(&ko) => {
                        if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(ko) {
                            match entry.constant() {
                                None => Err(format!(
                                    "variant '{}' is a wrapper, expected a constant",
                                    s
                                )),
                                Some(v) => Ok(v),
                            }
                        } else {
                            Ok(T::default())
                        }
                    }
                },
                serde_json::Value::Array(arr) if arr.len() == 2 => {
                    let num = arr[0].as_i64().unwrap_or(0) as i32;
                    match self.number_to_entry.get(&num) {
                        None => {
                            if keep {
                                let bytes = serde_json::to_vec(v).unwrap_or_default();
                                let ud = UnrecognizedVariantData::new_from_json(num, bytes);
                                Ok((self.wrap_unrecognized)(ud))
                            } else {
                                Ok(T::default())
                            }
                        }
                        Some(AnyEntry::Removed) => Ok(T::default()),
                        Some(AnyEntry::Constant(ko)) => {
                            if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(*ko) {
                                Ok(entry.constant().unwrap_or_default())
                            } else {
                                Ok(T::default())
                            }
                        }
                        Some(AnyEntry::Wrapper(ko)) => {
                            let ko = *ko;
                            if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(ko) {
                                entry.wrap_from_json(&arr[1], keep)
                            } else {
                                Ok(T::default())
                            }
                        }
                    }
                }
                serde_json::Value::Object(obj) => {
                    let name = obj.get("kind").and_then(|v| v.as_str()).unwrap_or("");
                    let val_json = obj.get("value").unwrap_or(&serde_json::Value::Null);
                    match self.name_to_kind_ordinal.get(name) {
                        None => Ok(T::default()),
                        Some(&ko) => {
                            if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(ko) {
                                if entry.constant().is_some() {
                                    return Ok(entry.constant().unwrap_or_default());
                                }
                                entry.wrap_from_json(val_json, keep)
                            } else {
                                Ok(T::default())
                            }
                        }
                    }
                }
                _ => Ok(T::default()),
            }
        }

        /// Resolves a variant number seen in a constant context (JSON number or
        /// binary wire < 242).  If unrecognized and `keep` is true, wraps the raw
        /// representation; otherwise returns UNKNOWN.
        fn resolve_constant_lookup(
            &self,
            number: i32,
            keep: bool,
            raw_json: Option<&serde_json::Value>,
        ) -> T {
            match self.number_to_entry.get(&number) {
                None => {
                    if keep {
                        let ud = if let Some(v) = raw_json {
                            let bytes = serde_json::to_vec(v).unwrap_or_default();
                            UnrecognizedVariantData::new_from_json(number, bytes)
                        } else {
                            let mut bytes = Vec::new();
                            encode_uint32(number as u32, &mut bytes);
                            UnrecognizedVariantData::new_from_bytes(number, bytes)
                        };
                        (self.wrap_unrecognized)(ud)
                    } else {
                        T::default()
                    }
                }
                Some(AnyEntry::Removed) => T::default(),
                // A wrapper variant encountered in a constant context is decoded
                // as the wrapper's default payload value.
                Some(AnyEntry::Wrapper(ko)) => {
                    let ko = *ko;
                    if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(ko) {
                        entry.wrap_default().unwrap_or_default()
                    } else {
                        T::default()
                    }
                }
                Some(AnyEntry::Constant(ko)) => {
                    let ko = *ko;
                    if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(ko) {
                        entry.constant().unwrap_or_default()
                    } else {
                        T::default()
                    }
                }
            }
        }

        fn encode_impl(&self, input: &T, out: &mut Vec<u8>) {
            let ko = (self.get_kind_ordinal)(input);
            if ko == 0 {
                // UNKNOWN: carry through raw wire bytes if available.
                if let Some(u) = (self.get_unrecognized)(input) {
                    if u.format == UnrecognizedFormat::Bytes && !u.value.is_empty() {
                        out.extend_from_slice(&u.value);
                        return;
                    }
                }
                out.push(0);
                return;
            }
            if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(ko) {
                if entry.constant().is_some() {
                    entry.encode_value(input, out);
                } else {
                    // Wrapper variant: header byte(s) followed by the wrapped value.
                    let n = entry.number();
                    if (1..=4).contains(&n) {
                        out.push(250 + n as u8);
                    } else {
                        out.push(248);
                        encode_uint32(n as u32, out);
                    }
                    entry.encode_value(input, out);
                }
            } else {
                out.push(0); // fallback
            }
        }

        fn decode_impl(&self, input: &mut &[u8], keep: bool) -> Result<T, String> {
            let wire = read_u8(input)?;

            if wire < 242 {
                // Constant variant: decode the number from the wire byte.
                let n = decode_number_body(wire, input)? as i32;
                return Ok(self.resolve_constant_lookup(n, keep, None));
            }

            // Wrapper variant: determine the variant number.
            let number: i32 = if wire == 248 {
                decode_number(input)? as i32
            } else if (251..=254).contains(&wire) {
                (wire - 250) as i32
            } else {
                // Unknown wire byte (e.g. 242..247, 249, 250, 255): skip nothing and
                // return UNKNOWN.
                return Ok(T::default());
            };

            match self.number_to_entry.get(&number) {
                Some(AnyEntry::Wrapper(ko)) => {
                    let ko = *ko;
                    if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(ko) {
                        entry.wrap_decode(input, keep)
                    } else {
                        skip_value(input)?;
                        Ok(T::default())
                    }
                }
                Some(AnyEntry::Removed) => {
                    skip_value(input)?;
                    Ok(T::default())
                }
                // Not found: treat as an unrecognized wrapper number.
                None => {
                    if keep {
                        // Re-encode the header we already consumed so the full wire
                        // representation can be round-tripped.
                        let mut header = Vec::new();
                        if (1..=4).contains(&number) {
                            header.push(250 + number as u8);
                        } else {
                            header.push(248);
                            encode_uint32(number as u32, &mut header);
                        }
                        let before = *input;
                        let before_len = before.len();
                        skip_value(input)?;
                        let consumed = before_len - input.len();
                        let mut all_bytes = header;
                        all_bytes.extend_from_slice(&before[..consumed]);
                        Ok((self.wrap_unrecognized)(
                            UnrecognizedVariantData::new_from_bytes(number, all_bytes),
                        ))
                    } else {
                        skip_value(input)?;
                        Ok(T::default())
                    }
                }
                Some(AnyEntry::Constant(ko)) => {
                    let ko = *ko;
                    if let Some(Some(entry)) = self.kind_ordinal_to_entry.get(ko) {
                        skip_value(input)?;
                        Ok(entry.constant().unwrap_or_default())
                    } else {
                        skip_value(input)?;
                        Ok(T::default())
                    }
                }
            }
        }

        fn type_descriptor_impl(&self) -> TypeDescriptor {
            TypeDescriptor::Enum(Arc::clone(&self.desc))
        }
    }

    impl<T: 'static + Default> TypeAdapter<T> for EnumAdapter<T> {
        fn is_default(&self, input: &T) -> bool {
            self.is_default_impl(input)
        }

        fn to_json(&self, input: &T, eol_indent: Option<&str>, out: &mut String) {
            self.to_json_impl(input, eol_indent, out);
        }

        fn from_json(
            &self,
            json: &serde_json::Value,
            keep_unrecognized: bool,
        ) -> Result<T, String> {
            self.from_json_impl(json, keep_unrecognized)
        }

        fn encode(&self, input: &T, out: &mut Vec<u8>) {
            self.encode_impl(input, out);
        }

        fn decode(&self, input: &mut &[u8], keep_unrecognized: bool) -> Result<T, String> {
            self.decode_impl(input, keep_unrecognized)
        }

        fn type_descriptor(&self) -> TypeDescriptor {
            self.type_descriptor_impl()
        }

        fn clone_box(&self) -> Box<dyn TypeAdapter<T>> {
            unreachable!("EnumAdapter is always accessed through a &'static reference")
        }
    }

    /// Creates a [`Serializer`] backed by the given `'static` [`EnumAdapter`]
    /// reference. For use only by generated code.
    pub fn enum_serializer_from_static<T: 'static + Default>(
        adapter: &'static EnumAdapter<T>,
    ) -> Serializer<T> {
        Serializer::new_borrowed(adapter)
    }
} // pub mod internal

#[cfg(test)]
mod tests {
    use super::super::serializer::TypeAdapter;
    use super::super::unrecognized::UnrecognizedVariant;
    use super::internal::EnumAdapter;

    // ─── Test enum type ───────────────────────────────────────────────────────

    #[derive(Clone, Debug, PartialEq)]
    enum Color {
        Unknown(Option<UnrecognizedVariant<Color>>),
        Red,
        Green,
        Blue,
    }

    impl Default for Color {
        fn default() -> Self {
            Color::Unknown(None)
        }
    }

    fn make_color_adapter() -> EnumAdapter<Color> {
        let mut adapter = EnumAdapter::new(
            |x: &Color| match x {
                Color::Unknown(_) => 0,
                Color::Red => 1,
                Color::Green => 2,
                Color::Blue => 3,
            },
            |u| Color::Unknown(Some(u)),
            |x: &Color| match x {
                Color::Unknown(Some(u)) => Some(u.as_ref()),
                _ => None,
            },
            "test.skir",
            "Color",
            "",
        );
        adapter.add_constant_variant("red", 1, 1, "", Color::Red);
        adapter.add_constant_variant("green", 2, 2, "", Color::Green);
        adapter.add_constant_variant("blue", 3, 3, "", Color::Blue);
        adapter.finalize();
        adapter
    }

    // ─── Condition 1: serialise using the registered (lower_case) name ────────

    #[test]
    fn serialises_lowercase_constant_to_lower_case_readable_json() {
        let adapter = make_color_adapter();
        let mut out = String::new();
        adapter.to_json(&Color::Red, Some(""), &mut out);
        assert_eq!(out, "\"red\"");
    }

    // ─── Condition 2: parse both UPPER_CASE and lower_case names ─────────────

    #[test]
    fn parses_upper_case_constant_name() {
        let adapter = make_color_adapter();
        let json = serde_json::Value::String("RED".to_string());
        let result = adapter.from_json(&json, false).unwrap();
        assert_eq!(result, Color::Red);
    }

    #[test]
    fn parses_lower_case_constant_name() {
        let adapter = make_color_adapter();
        let json = serde_json::Value::String("green".to_string());
        let result = adapter.from_json(&json, false).unwrap();
        assert_eq!(result, Color::Green);
    }

    #[test]
    fn upper_case_and_lower_case_constant_names_yield_same_result() {
        let adapter = make_color_adapter();
        let from_upper = adapter
            .from_json(&serde_json::Value::String("RED".to_string()), false)
            .unwrap();
        let from_lower = adapter
            .from_json(&serde_json::Value::String("red".to_string()), false)
            .unwrap();
        assert_eq!(from_upper, from_lower);
        assert_eq!(from_upper, Color::Red);
    }

    #[test]
    fn unknown_upper_and_lower_yield_same_unknown_result() {
        let adapter = make_color_adapter();
        let from_upper = adapter
            .from_json(&serde_json::Value::String("UNKNOWN".to_string()), false)
            .unwrap();
        let from_lower = adapter
            .from_json(&serde_json::Value::String("unknown".to_string()), false)
            .unwrap();
        assert_eq!(from_upper, from_lower);
        assert_eq!(from_lower, Color::Unknown(None));
    }
}
