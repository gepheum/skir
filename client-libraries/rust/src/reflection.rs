use std::collections::{HashMap, HashSet};
use std::sync::{Arc, OnceLock};

// =============================================================================
// PrimitiveType
// =============================================================================

/// Enumerates all primitive types supported by Skir.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrimitiveType {
    Bool,
    Int32,
    Int64,
    Hash64,
    Float32,
    Float64,
    Timestamp,
    String,
    Bytes,
}

impl PrimitiveType {
    pub fn as_str(self) -> &'static str {
        match self {
            PrimitiveType::Bool => "bool",
            PrimitiveType::Int32 => "int32",
            PrimitiveType::Int64 => "int64",
            PrimitiveType::Hash64 => "hash64",
            PrimitiveType::Float32 => "float32",
            PrimitiveType::Float64 => "float64",
            PrimitiveType::Timestamp => "timestamp",
            PrimitiveType::String => "string",
            PrimitiveType::Bytes => "bytes",
        }
    }
}

impl std::fmt::Display for PrimitiveType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

// =============================================================================
// TypeDescriptor
// =============================================================================

/// Describes a Skir type.
///
/// Variants:
/// - [`TypeDescriptor::Primitive`]
/// - [`TypeDescriptor::Optional`]
/// - [`TypeDescriptor::Array`]
/// - [`TypeDescriptor::Struct`]
/// - [`TypeDescriptor::Enum`]
#[derive(Clone)]
pub enum TypeDescriptor {
    Primitive(PrimitiveType),
    Optional(Box<TypeDescriptor>),
    Array(Box<ArrayDescriptor>),
    Struct(Arc<StructDescriptor>),
    Enum(Arc<EnumDescriptor>),
}

impl TypeDescriptor {
    /// Returns the complete, self-describing JSON representation of this type
    /// descriptor, as produced and consumed by [`TypeDescriptor::parse_from_json`].
    pub fn as_json(&self) -> String {
        type_descriptor_to_json(self)
    }

    /// Parses a [`TypeDescriptor`] from its JSON string representation, as
    /// produced by [`TypeDescriptor::as_json`].
    ///
    /// The format uses a two-pass self-describing JSON: a top-level `"type"` key
    /// holds the root type signature, and `"records"` holds all referenced
    /// struct/enum definitions so that forward references and mutual recursion
    /// are supported.
    pub fn parse_from_json(json_code: &str) -> Result<TypeDescriptor, String> {
        let root: serde_json::Value = serde_json::from_str(json_code)
            .map_err(|e| format!("TypeDescriptor::parse_from_json: {}", e))?;
        parse_type_descriptor_from_value(&root)
    }
}

/// Debug delegates to `as_json()` so that recursive struct/enum types never
/// cause infinite output (the serialiser already has cycle detection).
impl std::fmt::Debug for TypeDescriptor {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.as_json())
    }
}

// =============================================================================
// ArrayDescriptor
// =============================================================================

/// Describes an ordered collection of elements of a single type.
#[derive(Clone)]
pub struct ArrayDescriptor {
    item_type: TypeDescriptor,
    key_extractor: String,
}

impl ArrayDescriptor {
    pub(super) fn new(item_type: TypeDescriptor, key_extractor: String) -> Self {
        Self {
            item_type,
            key_extractor,
        }
    }

    /// The type descriptor for each array element.
    pub fn item_type(&self) -> &TypeDescriptor {
        &self.item_type
    }
    /// The key chain string (e.g. `"id"` or `"address.zip"`), or empty if none.
    pub fn key_extractor(&self) -> &str {
        &self.key_extractor
    }
}

impl std::fmt::Debug for ArrayDescriptor {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ArrayDescriptor")
            .field("item_type", &self.item_type)
            .field("key_extractor", &self.key_extractor)
            .finish()
    }
}

// =============================================================================
// StructField
// =============================================================================

/// Describes a single field of a Skir struct.
#[derive(Clone)]
pub struct StructField {
    name: String,
    number: i32,
    field_type: TypeDescriptor,
    doc: String,
}

impl StructField {
    pub(super) fn new(name: String, number: i32, field_type: TypeDescriptor, doc: String) -> Self {
        StructField {
            name,
            number,
            field_type,
            doc,
        }
    }

    pub fn name(&self) -> &str {
        &self.name
    }
    pub fn number(&self) -> i32 {
        self.number
    }
    pub fn field_type(&self) -> &TypeDescriptor {
        &self.field_type
    }
    pub fn doc(&self) -> &str {
        &self.doc
    }
}

impl std::fmt::Debug for StructField {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("StructField")
            .field("name", &self.name)
            .field("number", &self.number)
            .field("doc", &self.doc)
            .finish()
    }
}

// =============================================================================
// EnumVariant
// =============================================================================

/// A constant (non-wrapping) enum variant.
#[derive(Debug, Clone)]
pub struct EnumConstantVariant {
    name: String,
    number: i32,
    doc: String,
}

impl EnumConstantVariant {
    pub(super) fn new(name: String, number: i32, doc: String) -> Self {
        EnumConstantVariant { name, number, doc }
    }

    pub fn name(&self) -> &str {
        &self.name
    }
    pub fn number(&self) -> i32 {
        self.number
    }
    pub fn doc(&self) -> &str {
        &self.doc
    }
}

/// An enum variant that wraps a value of another type.
#[derive(Clone)]
pub struct EnumWrapperVariant {
    name: String,
    number: i32,
    variant_type: TypeDescriptor,
    doc: String,
}

impl EnumWrapperVariant {
    pub(super) fn new(
        name: String,
        number: i32,
        variant_type: TypeDescriptor,
        doc: String,
    ) -> Self {
        EnumWrapperVariant {
            name,
            number,
            variant_type,
            doc,
        }
    }

    pub fn name(&self) -> &str {
        &self.name
    }
    pub fn number(&self) -> i32 {
        self.number
    }
    pub fn variant_type(&self) -> &TypeDescriptor {
        &self.variant_type
    }
    pub fn doc(&self) -> &str {
        &self.doc
    }
}

impl std::fmt::Debug for EnumWrapperVariant {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("EnumWrapperVariant")
            .field("name", &self.name)
            .field("number", &self.number)
            .field("doc", &self.doc)
            .finish()
    }
}

/// The common type for Skir enum variants.
#[derive(Debug, Clone)]
pub enum EnumVariant {
    Constant(EnumConstantVariant),
    Wrapper(EnumWrapperVariant),
}

impl EnumVariant {
    pub fn name(&self) -> &str {
        match self {
            Self::Constant(v) => &v.name,
            Self::Wrapper(v) => &v.name,
        }
    }
    pub fn number(&self) -> i32 {
        match self {
            Self::Constant(v) => v.number,
            Self::Wrapper(v) => v.number,
        }
    }
    pub fn doc(&self) -> &str {
        match self {
            Self::Constant(v) => &v.doc,
            Self::Wrapper(v) => &v.doc,
        }
    }
    /// Returns the wrapped type for a wrapper variant, or `None` for a constant.
    pub fn variant_type(&self) -> Option<&TypeDescriptor> {
        match self {
            Self::Constant(_) => None,
            Self::Wrapper(v) => Some(&v.variant_type),
        }
    }
}

// =============================================================================
// StructDescriptor
// =============================================================================

/// Describes a Skir struct type.
pub struct StructDescriptor {
    name: String,
    qualified_name: String,
    module_path: String,
    doc: String,
    removed_numbers: OnceLock<HashSet<i32>>,
    /// Set once by the parser in pass 2.
    fields: OnceLock<Vec<StructField>>,
    /// Lazily-built lookup tables (name → index, number → index).
    lookups: OnceLock<(HashMap<String, usize>, HashMap<i32, usize>)>,
}

impl StructDescriptor {
    pub(super) fn new(module_path: String, qualified_name: String, doc: String) -> Self {
        let name = qualified_name.rfind('.').map_or_else(
            || qualified_name.clone(),
            |i| qualified_name[i + 1..].to_string(),
        );
        StructDescriptor {
            name,
            qualified_name,
            module_path,
            doc,
            removed_numbers: OnceLock::new(),
            fields: OnceLock::new(),
            lookups: OnceLock::new(),
        }
    }

    pub fn name(&self) -> &str {
        &self.name
    }
    pub fn qualified_name(&self) -> &str {
        &self.qualified_name
    }
    pub fn module_path(&self) -> &str {
        &self.module_path
    }
    pub fn doc(&self) -> &str {
        &self.doc
    }
    pub fn removed_numbers(&self) -> &HashSet<i32> {
        self.removed_numbers.get_or_init(HashSet::new)
    }
    pub fn fields(&self) -> &[StructField] {
        self.fields
            .get()
            .expect("StructDescriptor fields not yet initialized")
    }

    /// Called once by [`struct_adapter::StructAdapter::finalize`] after all
    /// fields have been registered. Silently ignored if called more than once.
    pub(super) fn set_fields(&self, fields: Vec<StructField>) {
        self.fields.set(fields).ok();
    }

    /// Called once by [`struct_adapter::StructAdapter::finalize`] after all
    /// removed numbers have been registered. Silently ignored if called more than once.
    pub(super) fn set_removed_numbers(&self, nums: HashSet<i32>) {
        self.removed_numbers.set(nums).ok();
    }

    fn record_id(&self) -> String {
        format!("{}:{}", self.module_path, self.qualified_name)
    }

    fn ensure_lookups(&self) -> &(HashMap<String, usize>, HashMap<i32, usize>) {
        self.lookups.get_or_init(|| {
            let fields = self.fields();
            let by_name = fields
                .iter()
                .enumerate()
                .map(|(i, f)| (f.name.clone(), i))
                .collect();
            let by_number = fields
                .iter()
                .enumerate()
                .map(|(i, f)| (f.number, i))
                .collect();
            (by_name, by_number)
        })
    }

    /// Returns the field with the given name, or `None` if not found.
    pub fn field_by_name(&self, name: &str) -> Option<&StructField> {
        let idx = *self.ensure_lookups().0.get(name)?;
        Some(&self.fields()[idx])
    }

    /// Returns the field with the given number, or `None` if not found.
    pub fn field_by_number(&self, number: i32) -> Option<&StructField> {
        let idx = *self.ensure_lookups().1.get(&number)?;
        Some(&self.fields()[idx])
    }
}

impl std::fmt::Debug for StructDescriptor {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "StructDescriptor({})", self.record_id())
    }
}

// =============================================================================
// EnumDescriptor
// =============================================================================

/// Describes a Skir enum type.
pub struct EnumDescriptor {
    name: String,
    qualified_name: String,
    module_path: String,
    doc: String,
    removed_numbers: OnceLock<HashSet<i32>>,
    /// Set once by the parser in pass 2.
    variants: OnceLock<Vec<EnumVariant>>,
    /// Lazily-built lookup tables (name → index, number → index).
    lookups: OnceLock<(HashMap<String, usize>, HashMap<i32, usize>)>,
}

impl EnumDescriptor {
    pub(super) fn new(module_path: String, qualified_name: String, doc: String) -> Self {
        let name = qualified_name.rfind('.').map_or_else(
            || qualified_name.clone(),
            |i| qualified_name[i + 1..].to_string(),
        );
        EnumDescriptor {
            name,
            qualified_name,
            module_path,
            doc,
            removed_numbers: OnceLock::new(),
            variants: OnceLock::new(),
            lookups: OnceLock::new(),
        }
    }

    pub fn name(&self) -> &str {
        &self.name
    }
    pub fn qualified_name(&self) -> &str {
        &self.qualified_name
    }
    pub fn module_path(&self) -> &str {
        &self.module_path
    }
    pub fn doc(&self) -> &str {
        &self.doc
    }
    pub fn removed_numbers(&self) -> &HashSet<i32> {
        self.removed_numbers.get_or_init(HashSet::new)
    }
    pub fn variants(&self) -> &[EnumVariant] {
        self.variants
            .get()
            .expect("EnumDescriptor variants not yet initialized")
    }

    /// Called once by [`enum_adapter::EnumAdapter::finalize`] after all
    /// variants have been registered. Silently ignored if called more than once.
    pub(super) fn set_variants(&self, variants: Vec<EnumVariant>) {
        self.variants.set(variants).ok();
    }

    /// Called once by [`enum_adapter::EnumAdapter::finalize`] after all
    /// removed numbers have been registered. Silently ignored if called more than once.
    pub(super) fn set_removed_numbers(&self, nums: HashSet<i32>) {
        self.removed_numbers.set(nums).ok();
    }

    fn record_id(&self) -> String {
        format!("{}:{}", self.module_path, self.qualified_name)
    }

    fn ensure_lookups(&self) -> &(HashMap<String, usize>, HashMap<i32, usize>) {
        self.lookups.get_or_init(|| {
            let variants = self.variants();
            let by_name = variants
                .iter()
                .enumerate()
                .map(|(i, v)| (v.name().to_string(), i))
                .collect();
            let by_number = variants
                .iter()
                .enumerate()
                .map(|(i, v)| (v.number(), i))
                .collect();
            (by_name, by_number)
        })
    }

    /// Returns the variant with the given name, or `None` if not found.
    pub fn variant_by_name(&self, name: &str) -> Option<&EnumVariant> {
        let idx = *self.ensure_lookups().0.get(name)?;
        Some(&self.variants()[idx])
    }

    /// Returns the variant with the given number, or `None` if not found.
    pub fn variant_by_number(&self, number: i32) -> Option<&EnumVariant> {
        let idx = *self.ensure_lookups().1.get(&number)?;
        Some(&self.variants()[idx])
    }
}

impl std::fmt::Debug for EnumDescriptor {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "EnumDescriptor({})", self.record_id())
    }
}

// =============================================================================
// JSON serialization
// =============================================================================

fn type_descriptor_to_json(td: &TypeDescriptor) -> String {
    let records = collect_record_values(td);
    let mut root = serde_json::Map::new();
    root.insert("type".into(), type_signature_to_value(td));
    root.insert("records".into(), records.into());
    serde_json::to_string_pretty(&serde_json::Value::Object(root)).unwrap()
}

fn collect_record_values(td: &TypeDescriptor) -> Vec<serde_json::Value> {
    let mut order: Vec<String> = Vec::new();
    let mut record_id_to_value: HashMap<String, serde_json::Value> = HashMap::new();
    add_record_values(td, &mut order, &mut record_id_to_value);
    order
        .into_iter()
        .map(|id| record_id_to_value.remove(&id).unwrap())
        .collect()
}

fn add_record_values(
    td: &TypeDescriptor,
    order: &mut Vec<String>,
    record_id_to_value: &mut HashMap<String, serde_json::Value>,
) {
    match td {
        TypeDescriptor::Primitive(_) => {}
        TypeDescriptor::Optional(inner) => {
            add_record_values(inner, order, record_id_to_value);
        }
        TypeDescriptor::Array(arr) => {
            add_record_values(&arr.item_type, order, record_id_to_value);
        }
        TypeDescriptor::Struct(s) => {
            let rid = s.record_id();
            if record_id_to_value.contains_key(&rid) {
                return; // cycle guard
            }
            record_id_to_value.insert(rid.clone(), serde_json::Value::Null); // placeholder
            let value = struct_record_to_value(s);
            *record_id_to_value.get_mut(&rid).unwrap() = value;
            order.push(rid);
            for f in s.fields() {
                add_record_values(&f.field_type, order, record_id_to_value);
            }
        }
        TypeDescriptor::Enum(e) => {
            let rid = e.record_id();
            if record_id_to_value.contains_key(&rid) {
                return; // cycle guard
            }
            record_id_to_value.insert(rid.clone(), serde_json::Value::Null); // placeholder
            let value = enum_record_to_value(e);
            *record_id_to_value.get_mut(&rid).unwrap() = value;
            order.push(rid);
            for v in e.variants() {
                if let EnumVariant::Wrapper(w) = v {
                    add_record_values(&w.variant_type, order, record_id_to_value);
                }
            }
        }
    }
}

fn struct_record_to_value(s: &StructDescriptor) -> serde_json::Value {
    let fields: Vec<serde_json::Value> = s
        .fields()
        .iter()
        .map(|f| {
            let mut obj = serde_json::Map::new();
            obj.insert("name".into(), f.name.clone().into());
            obj.insert("number".into(), f.number.into());
            obj.insert("type".into(), type_signature_to_value(&f.field_type));
            if !f.doc.is_empty() {
                obj.insert("doc".into(), f.doc.clone().into());
            }
            serde_json::Value::Object(obj)
        })
        .collect();

    let mut obj = serde_json::Map::new();
    obj.insert("kind".into(), "struct".into());
    obj.insert("id".into(), s.record_id().into());
    if !s.doc.is_empty() {
        obj.insert("doc".into(), s.doc.clone().into());
    }
    obj.insert("fields".into(), fields.into());
    let removed = removed_numbers_to_sorted_slice(s.removed_numbers());
    if !removed.is_empty() {
        let removed_json: Vec<serde_json::Value> = removed.iter().map(|&n| n.into()).collect();
        obj.insert("removed_numbers".into(), removed_json.into());
    }
    serde_json::Value::Object(obj)
}

fn enum_record_to_value(e: &EnumDescriptor) -> serde_json::Value {
    let mut sorted: Vec<&EnumVariant> = e.variants().iter().collect();
    sorted.sort_by_key(|v| v.number());

    let variants: Vec<serde_json::Value> = sorted
        .iter()
        .map(|v| {
            let mut obj = serde_json::Map::new();
            obj.insert("name".into(), v.name().to_string().into());
            obj.insert("number".into(), v.number().into());
            if let EnumVariant::Wrapper(w) = v {
                obj.insert("type".into(), type_signature_to_value(&w.variant_type));
            }
            if !v.doc().is_empty() {
                obj.insert("doc".into(), v.doc().to_string().into());
            }
            serde_json::Value::Object(obj)
        })
        .collect();

    let mut obj = serde_json::Map::new();
    obj.insert("kind".into(), "enum".into());
    obj.insert("id".into(), e.record_id().into());
    if !e.doc.is_empty() {
        obj.insert("doc".into(), e.doc.clone().into());
    }
    obj.insert("variants".into(), variants.into());
    let removed = removed_numbers_to_sorted_slice(e.removed_numbers());
    if !removed.is_empty() {
        let removed_json: Vec<serde_json::Value> = removed.iter().map(|&n| n.into()).collect();
        obj.insert("removed_numbers".into(), removed_json.into());
    }
    serde_json::Value::Object(obj)
}

fn type_signature_to_value(td: &TypeDescriptor) -> serde_json::Value {
    match td {
        TypeDescriptor::Primitive(p) => {
            let mut obj = serde_json::Map::new();
            obj.insert("kind".into(), "primitive".into());
            obj.insert("value".into(), p.as_str().into());
            serde_json::Value::Object(obj)
        }
        TypeDescriptor::Optional(inner) => {
            let mut obj = serde_json::Map::new();
            obj.insert("kind".into(), "optional".into());
            obj.insert("value".into(), type_signature_to_value(inner));
            serde_json::Value::Object(obj)
        }
        TypeDescriptor::Array(arr) => {
            let mut value_obj = serde_json::Map::new();
            value_obj.insert("item".into(), type_signature_to_value(&arr.item_type));
            if !arr.key_extractor.is_empty() {
                value_obj.insert("key_extractor".into(), arr.key_extractor.clone().into());
            }
            let mut obj = serde_json::Map::new();
            obj.insert("kind".into(), "array".into());
            obj.insert("value".into(), serde_json::Value::Object(value_obj));
            serde_json::Value::Object(obj)
        }
        TypeDescriptor::Struct(s) => {
            let mut obj = serde_json::Map::new();
            obj.insert("kind".into(), "record".into());
            obj.insert("value".into(), s.record_id().into());
            serde_json::Value::Object(obj)
        }
        TypeDescriptor::Enum(e) => {
            let mut obj = serde_json::Map::new();
            obj.insert("kind".into(), "record".into());
            obj.insert("value".into(), e.record_id().into());
            serde_json::Value::Object(obj)
        }
    }
}

fn removed_numbers_to_sorted_slice(set: &HashSet<i32>) -> Vec<i32> {
    let mut v: Vec<i32> = set.iter().copied().collect();
    v.sort_unstable();
    v
}

// =============================================================================
// JSON parsing
// =============================================================================

/// An enum/struct descriptor that is cheap to clone (Arc inside).
enum RecordDescriptorInner {
    Struct(Arc<StructDescriptor>),
    Enum(Arc<EnumDescriptor>),
}

impl RecordDescriptorInner {
    fn record_id(&self) -> String {
        match self {
            Self::Struct(s) => s.record_id(),
            Self::Enum(e) => e.record_id(),
        }
    }

    fn as_type_descriptor(&self) -> TypeDescriptor {
        match self {
            Self::Struct(s) => TypeDescriptor::Struct(Arc::clone(s)),
            Self::Enum(e) => TypeDescriptor::Enum(Arc::clone(e)),
        }
    }

    fn clone_inner(&self) -> Self {
        match self {
            Self::Struct(s) => Self::Struct(Arc::clone(s)),
            Self::Enum(e) => Self::Enum(Arc::clone(e)),
        }
    }
}

struct RecordBundle {
    descriptor: RecordDescriptorInner,
    fields_or_variants: Vec<serde_json::Value>,
}

fn parse_type_descriptor_from_value(root: &serde_json::Value) -> Result<TypeDescriptor, String> {
    // ── Pass 1: create all record descriptors (without fields/variants) ───────
    let mut record_id_to_bundle: HashMap<String, RecordBundle> = HashMap::new();

    for rec in root
        .get("records")
        .and_then(|v| v.as_array())
        .map(Vec::as_slice)
        .unwrap_or(&[])
    {
        let descriptor = parse_record_descriptor_partial(rec)?;
        let rid = descriptor.record_id();
        let fields_or_variants = rec
            .get("fields")
            .or_else(|| rec.get("variants"))
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        record_id_to_bundle.insert(
            rid,
            RecordBundle {
                descriptor,
                fields_or_variants,
            },
        );
    }

    // ── Pass 2: fill in fields / variants ─────────────────────────────────────
    // Collect ids up-front so we can reborrow `record_id_to_bundle` immutably
    // when calling `parse_type_signature` inside the loop.
    let ids: Vec<String> = record_id_to_bundle.keys().cloned().collect();
    for id in &ids {
        // Clone both the descriptor Arc and the raw JSON array so the immutable
        // borrow on `record_id_to_bundle` is released before we call
        // `parse_type_signature` (which also borrows the map).
        let fields_or_variants = record_id_to_bundle[id].fields_or_variants.clone();
        let desc = record_id_to_bundle[id].descriptor.clone_inner();

        match desc {
            RecordDescriptorInner::Struct(s) => {
                let mut fields = Vec::with_capacity(fields_or_variants.len());
                for fv in &fields_or_variants {
                    let name = get_json_str(fv, "name").to_string();
                    let number = get_json_i32(fv, "number");
                    let type_val = fv
                        .get("type")
                        .ok_or_else(|| format!("struct field {:?} is missing 'type'", name))?;
                    let field_type = parse_type_signature(type_val, &record_id_to_bundle)?;
                    let doc = get_json_str(fv, "doc").to_string();
                    fields.push(StructField {
                        name,
                        number,
                        field_type,
                        doc,
                    });
                }
                s.fields
                    .set(fields)
                    .map_err(|_| "fields already set".to_string())?;
            }
            RecordDescriptorInner::Enum(e) => {
                let mut variants = Vec::with_capacity(fields_or_variants.len());
                for vv in &fields_or_variants {
                    let name = get_json_str(vv, "name").to_string();
                    let number = get_json_i32(vv, "number");
                    let doc = get_json_str(vv, "doc").to_string();
                    if let Some(type_val) = vv.get("type") {
                        let variant_type = parse_type_signature(type_val, &record_id_to_bundle)?;
                        variants.push(EnumVariant::Wrapper(EnumWrapperVariant {
                            name,
                            number,
                            variant_type,
                            doc,
                        }));
                    } else {
                        variants.push(EnumVariant::Constant(EnumConstantVariant {
                            name,
                            number,
                            doc,
                        }));
                    }
                }
                e.variants
                    .set(variants)
                    .map_err(|_| "variants already set".to_string())?;
            }
        }
    }

    // ── Resolve the root type ─────────────────────────────────────────────────
    let type_val = root
        .get("type")
        .ok_or_else(|| "type descriptor JSON is missing 'type'".to_string())?;
    parse_type_signature(type_val, &record_id_to_bundle)
}

fn parse_record_descriptor_partial(v: &serde_json::Value) -> Result<RecordDescriptorInner, String> {
    let kind = get_json_str(v, "kind");
    let id_str = get_json_str(v, "id");
    let doc = get_json_str(v, "doc").to_string();
    let (module_path, qualified_name) = split_record_id(id_str)?;

    let removed_numbers: HashSet<i32> = v
        .get("removed_numbers")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|n| n.as_i64().map(|n| n as i32))
                .collect()
        })
        .unwrap_or_default();

    match kind {
        "struct" => {
            let desc = Arc::new(StructDescriptor::new(module_path, qualified_name, doc));
            desc.set_removed_numbers(removed_numbers);
            Ok(RecordDescriptorInner::Struct(desc))
        }
        "enum" => {
            let desc = Arc::new(EnumDescriptor::new(module_path, qualified_name, doc));
            desc.set_removed_numbers(removed_numbers);
            Ok(RecordDescriptorInner::Enum(desc))
        }
        _ => Err(format!("unknown record kind {:?}", kind)),
    }
}

fn parse_type_signature(
    v: &serde_json::Value,
    record_id_to_bundle: &HashMap<String, RecordBundle>,
) -> Result<TypeDescriptor, String> {
    let kind = get_json_str(v, "kind");
    let val = v
        .get("value")
        .ok_or_else(|| format!("type signature missing 'value' (kind={:?})", kind))?;

    match kind {
        "primitive" => {
            let s = val.as_str().unwrap_or("");
            let prim = match s {
                "bool" => PrimitiveType::Bool,
                "int32" => PrimitiveType::Int32,
                "int64" => PrimitiveType::Int64,
                "hash64" => PrimitiveType::Hash64,
                "float32" => PrimitiveType::Float32,
                "float64" => PrimitiveType::Float64,
                "timestamp" => PrimitiveType::Timestamp,
                "string" => PrimitiveType::String,
                "bytes" => PrimitiveType::Bytes,
                _ => return Err(format!("unknown primitive type {:?}", s)),
            };
            Ok(TypeDescriptor::Primitive(prim))
        }
        "optional" => {
            let inner = parse_type_signature(val, record_id_to_bundle)?;
            Ok(TypeDescriptor::Optional(Box::new(inner)))
        }
        "array" => {
            let item_val = val
                .get("item")
                .ok_or_else(|| "array type signature missing 'item'".to_string())?;
            let item_type = parse_type_signature(item_val, record_id_to_bundle)?;
            let key_extractor = val
                .get("key_extractor")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            Ok(TypeDescriptor::Array(Box::new(ArrayDescriptor {
                item_type,
                key_extractor,
            })))
        }
        "record" => {
            let record_id = val.as_str().unwrap_or("");
            let bundle = record_id_to_bundle
                .get(record_id)
                .ok_or_else(|| format!("unknown record id {:?}", record_id))?;
            Ok(bundle.descriptor.as_type_descriptor())
        }
        _ => Err(format!("unknown type kind {:?}", kind)),
    }
}

fn get_json_str<'a>(v: &'a serde_json::Value, key: &str) -> &'a str {
    v.get(key).and_then(|v| v.as_str()).unwrap_or("")
}

fn get_json_i32(v: &serde_json::Value, key: &str) -> i32 {
    v.get(key)
        .and_then(|v| v.as_i64())
        .map(|n| n as i32)
        .unwrap_or(0)
}

fn split_record_id(id: &str) -> Result<(String, String), String> {
    id.find(':')
        .map(|i| (id[..i].to_string(), id[i + 1..].to_string()))
        .ok_or_else(|| {
            format!(
                "malformed record id {:?} (expected 'modulePath:qualifiedName')",
                id
            )
        })
}

// =============================================================================
// Tests
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    // ── PrimitiveType ─────────────────────────────────────────────────────────

    #[test]
    fn primitive_type_as_str() {
        assert_eq!(PrimitiveType::Bool.as_str(), "bool");
        assert_eq!(PrimitiveType::Int32.as_str(), "int32");
        assert_eq!(PrimitiveType::Int64.as_str(), "int64");
        assert_eq!(PrimitiveType::Hash64.as_str(), "hash64");
        assert_eq!(PrimitiveType::Float32.as_str(), "float32");
        assert_eq!(PrimitiveType::Float64.as_str(), "float64");
        assert_eq!(PrimitiveType::Timestamp.as_str(), "timestamp");
        assert_eq!(PrimitiveType::String.as_str(), "string");
        assert_eq!(PrimitiveType::Bytes.as_str(), "bytes");
    }

    #[test]
    fn primitive_type_display() {
        assert_eq!(PrimitiveType::Int32.to_string(), "int32");
        assert_eq!(PrimitiveType::String.to_string(), "string");
    }

    // ── Round-trip helpers ────────────────────────────────────────────────────

    /// Parses `json`, serialises back to JSON, and asserts both strings match.
    fn assert_round_trip(json: &str) {
        let td = TypeDescriptor::parse_from_json(json).expect("parse failed");
        let re_serialised = td.as_json();
        assert_eq!(
            json, re_serialised,
            "round-trip mismatch.\nExpected:\n{}\nGot:\n{}",
            json, re_serialised
        );
    }

    // ── Primitive round-trips ─────────────────────────────────────────────────

    #[test]
    fn primitive_bool_round_trip() {
        let td = TypeDescriptor::Primitive(PrimitiveType::Bool);
        let json = td.as_json();
        let reparsed = TypeDescriptor::parse_from_json(&json).unwrap();
        assert_eq!(json, reparsed.as_json());
    }

    #[test]
    fn all_primitives_round_trip() {
        for prim in [
            PrimitiveType::Bool,
            PrimitiveType::Int32,
            PrimitiveType::Int64,
            PrimitiveType::Hash64,
            PrimitiveType::Float32,
            PrimitiveType::Float64,
            PrimitiveType::Timestamp,
            PrimitiveType::String,
            PrimitiveType::Bytes,
        ] {
            let td = TypeDescriptor::Primitive(prim);
            let json = td.as_json();
            let reparsed = TypeDescriptor::parse_from_json(&json).unwrap();
            assert_eq!(json, reparsed.as_json(), "round-trip failed for {:?}", prim);
        }
    }

    // ── Optional ─────────────────────────────────────────────────────────────

    #[test]
    fn optional_round_trip() {
        let td =
            TypeDescriptor::Optional(Box::new(TypeDescriptor::Primitive(PrimitiveType::String)));
        let json = td.as_json();
        assert_round_trip(&json);
    }

    #[test]
    fn nested_optional_round_trip() {
        let td = TypeDescriptor::Optional(Box::new(TypeDescriptor::Optional(Box::new(
            TypeDescriptor::Primitive(PrimitiveType::Int32),
        ))));
        let json = td.as_json();
        assert_round_trip(&json);
    }

    // ── Array ─────────────────────────────────────────────────────────────────

    #[test]
    fn array_no_key_extractor_round_trip() {
        let td = TypeDescriptor::Array(Box::new(ArrayDescriptor {
            item_type: TypeDescriptor::Primitive(PrimitiveType::Int64),
            key_extractor: String::new(),
        }));
        let json = td.as_json();
        assert_round_trip(&json);
    }

    #[test]
    fn array_with_key_extractor() {
        let json = r#"{
  "type": {
    "kind": "array",
    "value": {
      "item": {
        "kind": "primitive",
        "value": "string"
      },
      "key_extractor": "id.nested"
    }
  },
  "records": []
}"#;
        let td = TypeDescriptor::parse_from_json(json).unwrap();
        let TypeDescriptor::Array(arr) = td else {
            panic!("expected Array");
        };
        assert_eq!(arr.key_extractor(), "id.nested");
        assert_round_trip(json);
    }

    // ── Struct ────────────────────────────────────────────────────────────────

    const SIMPLE_STRUCT_JSON: &str = r#"{
  "type": {
    "kind": "record",
    "value": "mod:Person"
  },
  "records": [
    {
      "kind": "struct",
      "id": "mod:Person",
      "fields": [
        {
          "name": "id",
          "number": 1,
          "type": {
            "kind": "primitive",
            "value": "int32"
          }
        },
        {
          "name": "name",
          "number": 2,
          "type": {
            "kind": "primitive",
            "value": "string"
          }
        }
      ]
    }
  ]
}"#;

    #[test]
    fn struct_parse_fields() {
        let td = TypeDescriptor::parse_from_json(SIMPLE_STRUCT_JSON).unwrap();
        let TypeDescriptor::Struct(s) = &td else {
            panic!("expected Struct");
        };
        assert_eq!(s.name(), "Person");
        assert_eq!(s.qualified_name(), "Person");
        assert_eq!(s.module_path(), "mod");
        assert_eq!(s.doc(), "");
        assert_eq!(s.fields().len(), 2);
        assert_eq!(s.fields()[0].name(), "id");
        assert_eq!(s.fields()[0].number(), 1);
        assert_eq!(s.fields()[1].name(), "name");
    }

    #[test]
    fn struct_field_by_name() {
        let td = TypeDescriptor::parse_from_json(SIMPLE_STRUCT_JSON).unwrap();
        let TypeDescriptor::Struct(s) = &td else {
            panic!()
        };
        let f = s.field_by_name("name").unwrap();
        assert_eq!(f.number(), 2);
        assert!(s.field_by_name("missing").is_none());
    }

    #[test]
    fn struct_field_by_number() {
        let td = TypeDescriptor::parse_from_json(SIMPLE_STRUCT_JSON).unwrap();
        let TypeDescriptor::Struct(s) = &td else {
            panic!()
        };
        let f = s.field_by_number(1).unwrap();
        assert_eq!(f.name(), "id");
        assert!(s.field_by_number(99).is_none());
    }

    #[test]
    fn struct_round_trip() {
        assert_round_trip(SIMPLE_STRUCT_JSON);
    }

    #[test]
    fn struct_with_doc_and_removed_numbers_round_trip() {
        let json = r#"{
  "type": {
    "kind": "record",
    "value": "m:S"
  },
  "records": [
    {
      "kind": "struct",
      "id": "m:S",
      "doc": "A struct.",
      "fields": [],
      "removed_numbers": [
        3,
        7
      ]
    }
  ]
}"#;
        let td = TypeDescriptor::parse_from_json(json).unwrap();
        let TypeDescriptor::Struct(s) = td else {
            panic!()
        };
        assert_eq!(s.doc(), "A struct.");
        assert!(s.removed_numbers().contains(&3));
        assert!(s.removed_numbers().contains(&7));
        assert!(!s.removed_numbers().contains(&1));
        assert_round_trip(json);
    }

    #[test]
    fn nested_qualified_name_extracts_short_name() {
        let json = r#"{
  "type": {
    "kind": "record",
    "value": "mod:Outer.Inner"
  },
  "records": [
    {
      "kind": "struct",
      "id": "mod:Outer.Inner",
      "fields": []
    }
  ]
}"#;
        let td = TypeDescriptor::parse_from_json(json).unwrap();
        let TypeDescriptor::Struct(s) = td else {
            panic!()
        };
        assert_eq!(s.name(), "Inner");
        assert_eq!(s.qualified_name(), "Outer.Inner");
    }

    // ── Enum ──────────────────────────────────────────────────────────────────

    const SIMPLE_ENUM_JSON: &str = r#"{
  "type": {
    "kind": "record",
    "value": "mod:Color"
  },
  "records": [
    {
      "kind": "enum",
      "id": "mod:Color",
      "variants": [
        {
          "name": "Red",
          "number": 1
        },
        {
          "name": "Green",
          "number": 2
        },
        {
          "name": "Blue",
          "number": 3,
          "type": {
            "kind": "primitive",
            "value": "string"
          }
        }
      ]
    }
  ]
}"#;

    #[test]
    fn enum_parse_variants() {
        let td = TypeDescriptor::parse_from_json(SIMPLE_ENUM_JSON).unwrap();
        let TypeDescriptor::Enum(e) = &td else {
            panic!("expected Enum");
        };
        assert_eq!(e.name(), "Color");
        assert_eq!(e.module_path(), "mod");
        assert_eq!(e.variants().len(), 3);
    }

    #[test]
    fn enum_constant_variant() {
        let td = TypeDescriptor::parse_from_json(SIMPLE_ENUM_JSON).unwrap();
        let TypeDescriptor::Enum(e) = &td else {
            panic!()
        };
        let v = e.variant_by_name("Red").unwrap();
        assert_eq!(v.number(), 1);
        assert!(matches!(v, EnumVariant::Constant(_)));
        assert!(v.variant_type().is_none());
    }

    #[test]
    fn enum_wrapper_variant() {
        let td = TypeDescriptor::parse_from_json(SIMPLE_ENUM_JSON).unwrap();
        let TypeDescriptor::Enum(e) = &td else {
            panic!()
        };
        let v = e.variant_by_number(3).unwrap();
        assert_eq!(v.name(), "Blue");
        assert!(matches!(v, EnumVariant::Wrapper(_)));
        assert!(v.variant_type().is_some());
    }

    #[test]
    fn enum_variant_by_name_missing() {
        let td = TypeDescriptor::parse_from_json(SIMPLE_ENUM_JSON).unwrap();
        let TypeDescriptor::Enum(e) = &td else {
            panic!()
        };
        assert!(e.variant_by_name("Purple").is_none());
    }

    #[test]
    fn enum_round_trip() {
        assert_round_trip(SIMPLE_ENUM_JSON);
    }

    #[test]
    fn enum_variants_serialised_sorted_by_number() {
        // Insert variants out of order; serialisation must sort them.
        let json_unsorted = r#"{
  "type": {
    "kind": "record",
    "value": "m:E"
  },
  "records": [
    {
      "kind": "enum",
      "id": "m:E",
      "variants": [
        {"name": "C", "number": 3},
        {"name": "A", "number": 1},
        {"name": "B", "number": 2}
      ]
    }
  ]
}"#;
        let td = TypeDescriptor::parse_from_json(json_unsorted).unwrap();
        let json_out = td.as_json();
        // The output must have A before B before C.
        let pos_a = json_out.find("\"A\"").unwrap();
        let pos_b = json_out.find("\"B\"").unwrap();
        let pos_c = json_out.find("\"C\"").unwrap();
        assert!(pos_a < pos_b && pos_b < pos_c);
    }

    // ── Cross-record references ───────────────────────────────────────────────

    #[test]
    fn struct_with_nested_struct_field() {
        let json = r#"{
  "type": {
    "kind": "record",
    "value": "m:Outer"
  },
  "records": [
    {
      "kind": "struct",
      "id": "m:Outer",
      "fields": [
        {
          "name": "inner",
          "number": 1,
          "type": {
            "kind": "record",
            "value": "m:Inner"
          }
        }
      ]
    },
    {
      "kind": "struct",
      "id": "m:Inner",
      "fields": [
        {
          "name": "x",
          "number": 1,
          "type": {
            "kind": "primitive",
            "value": "int32"
          }
        }
      ]
    }
  ]
}"#;
        let td = TypeDescriptor::parse_from_json(json).unwrap();
        let TypeDescriptor::Struct(outer) = &td else {
            panic!()
        };
        let inner_field = outer.field_by_name("inner").unwrap();
        let TypeDescriptor::Struct(inner) = inner_field.field_type() else {
            panic!("field type should be Struct");
        };
        assert_eq!(inner.name(), "Inner");
        let x = inner.field_by_name("x").unwrap();
        assert!(matches!(
            x.field_type(),
            TypeDescriptor::Primitive(PrimitiveType::Int32)
        ));
    }

    // ── parse errors ──────────────────────────────────────────────────────────

    #[test]
    fn error_invalid_json() {
        assert!(TypeDescriptor::parse_from_json("{not json}").is_err());
    }

    #[test]
    fn error_missing_type_key() {
        assert!(TypeDescriptor::parse_from_json(r#"{"records":[]}"#).is_err());
    }

    #[test]
    fn error_unknown_primitive() {
        let json = r#"{"type":{"kind":"primitive","value":"badtype"},"records":[]}"#;
        assert!(TypeDescriptor::parse_from_json(json).is_err());
    }

    #[test]
    fn error_unknown_record_id() {
        let json = r#"{"type":{"kind":"record","value":"x:NoSuch"},"records":[]}"#;
        assert!(TypeDescriptor::parse_from_json(json).is_err());
    }

    #[test]
    fn error_unknown_record_kind() {
        let json =
            r#"{"type":{"kind":"record","value":"m:S"},"records":[{"kind":"union","id":"m:S"}]}"#;
        assert!(TypeDescriptor::parse_from_json(json).is_err());
    }

    #[test]
    fn error_struct_field_missing_type() {
        let json = r#"{
  "type": {"kind": "record", "value": "m:S"},
  "records": [
    {"kind": "struct", "id": "m:S", "fields": [{"name": "x", "number": 1}]}
  ]
}"#;
        assert!(TypeDescriptor::parse_from_json(json).is_err());
    }
}
