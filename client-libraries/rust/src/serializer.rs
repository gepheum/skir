use super::reflection::TypeDescriptor;

// =============================================================================
// DeserializeError
// =============================================================================

/// Error returned by [`Serializer::from_json`] and [`Serializer::from_bytes`].
#[derive(Debug, thiserror::Error)]
pub enum DeserializeError {
    /// The input is not valid JSON.
    #[error("invalid JSON: {0}")]
    InvalidJson(#[from] serde_json::Error),
    /// The JSON is valid but does not match the expected schema.
    #[error("{0}")]
    Schema(String),
}

/// Allows `?` to be used in functions that return `Result<_, String>`.
impl From<DeserializeError> for String {
    fn from(e: DeserializeError) -> String {
        e.to_string()
    }
}

// =============================================================================
// JsonFlavor
// =============================================================================

/// When serializing a value to JSON, you can choose one of two flavors.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum JsonFlavor {
    /// Structs are serialized as JSON arrays, where the field numbers in the
    /// index definition match the indexes in the array. Enum constants are
    /// serialized as numbers.
    ///
    /// This is the serialization format you should choose in most cases. It is
    /// also the default.
    Dense,
    /// Structs are serialized as JSON objects, and enum constants are
    /// serialized as strings.
    ///
    /// This format is more verbose and readable, but it should not be used if
    /// you need persistence, because skir allows fields to be renamed in record
    /// definitions. In other words, never store a readable JSON on disk or in a
    /// database.
    Readable,
}

// =============================================================================
// UnrecognizedValuesPolicy
// =============================================================================

/// What to do with unrecognized fields when deserializing a value from dense
/// JSON or binary data.
///
/// Pick [`Keep`][UnrecognizedValues::Keep] if the input JSON or binary string
/// comes from a trusted program which might have been built from more recent
/// source files. Always pick [`Drop`][UnrecognizedValues::Drop] if the input
/// JSON or binary string might come from a malicious user.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UnrecognizedValues {
    /// Unrecognized fields found when deserializing a value are dropped.
    ///
    /// Pick this option if the input JSON or binary string might come from a
    /// malicious user.
    Drop,
    /// Unrecognized fields found when deserializing a value from dense JSON or
    /// binary data are saved. If the value is later re-serialized in the same
    /// format (dense JSON or binary), the unrecognized fields will be present
    /// in the serialized form.
    Keep,
}

// =============================================================================
// Serializer
// =============================================================================

/// Serialises and deserialises values of type `T` in both JSON and binary
/// formats.
pub struct Serializer<T: 'static> {
    adapter: AdapterRef<T>,
}

impl<T: 'static> Clone for Serializer<T> {
    fn clone(&self) -> Self {
        Self {
            adapter: self.adapter.clone(),
        }
    }
}

impl<T: 'static> std::fmt::Debug for Serializer<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Serializer").finish_non_exhaustive()
    }
}

impl<T: 'static> Serializer<T> {
    /// Serialises `v` to a JSON string.
    pub fn to_json(&self, v: &T, flavor: JsonFlavor) -> String {
        let mut out = String::new();
        match flavor {
            JsonFlavor::Readable => self.adapter.get().to_json(v, Some("\n"), &mut out),
            JsonFlavor::Dense => self.adapter.get().to_json(v, None, &mut out),
        }
        out
    }

    /// Deserialises a JSON string into a value of type `T`.
    pub fn from_json(&self, code: &str, policy: UnrecognizedValues) -> Result<T, DeserializeError> {
        let fv: serde_json::Value =
            serde_json::from_str(code).map_err(DeserializeError::InvalidJson)?;
        self.adapter
            .get()
            .from_json(&fv, policy == UnrecognizedValues::Keep)
            .map_err(DeserializeError::Schema)
    }

    /// Serialises `v` to the Skir binary wire format.
    ///
    /// The returned bytes are prefixed with the four-byte magic `"skir"`.
    pub fn to_bytes(&self, v: &T) -> Vec<u8> {
        let mut out = b"skir".to_vec();
        self.adapter.get().encode(v, &mut out);
        out
    }

    /// Deserialises a value from the Skir binary wire format.
    ///
    /// If `bytes` lacks the `"skir"` prefix the payload is treated as a UTF-8
    /// JSON string and parsed via [`Self::from_json`].
    pub fn from_bytes(
        &self,
        bytes: &[u8],
        policy: UnrecognizedValues,
    ) -> Result<T, DeserializeError> {
        let keep = policy == UnrecognizedValues::Keep;
        if bytes.starts_with(b"skir") {
            let mut rest = &bytes[4..];
            self.adapter
                .get()
                .decode(&mut rest, keep)
                .map_err(DeserializeError::Schema)
        } else {
            let s =
                std::str::from_utf8(bytes).map_err(|e| DeserializeError::Schema(e.to_string()))?;
            self.from_json(s, policy)
        }
    }

    /// Returns a [`TypeDescriptor`] that describes the schema of `T`.
    pub fn type_descriptor(&self) -> TypeDescriptor {
        self.adapter.get().type_descriptor()
    }
    /// Constructs a `Serializer` that owns `adapter`.
    ///
    /// For use only by code generated by the Skir code generator.
    pub(super) fn new(adapter: impl TypeAdapter<T> + 'static) -> Self {
        Self {
            adapter: AdapterRef::Owned(Box::new(adapter)),
        }
    }

    /// Constructs a `Serializer` that borrows a `'static` adapter reference
    /// (e.g. a reference to a `static` item).
    ///
    /// For use only by code generated by the Skir code generator.
    pub(super) fn new_borrowed(adapter: &'static dyn TypeAdapter<T>) -> Self {
        Self {
            adapter: AdapterRef::Borrowed(adapter),
        }
    }

    /// Returns a reference to the underlying [`TypeAdapter`].
    pub(super) fn adapter(&self) -> &dyn TypeAdapter<T> {
        self.adapter.get()
    }
}

/// Owned or `'static`-borrowed reference to a `dyn TypeAdapter<T>`.
///
/// Serves the same purpose as `Cow<'static, A>` would, but works with unsized
/// trait objects (which cannot satisfy `ToOwned`).
enum AdapterRef<T: 'static> {
    Owned(Box<dyn TypeAdapter<T>>),
    Borrowed(&'static dyn TypeAdapter<T>),
}

impl<T: 'static> Clone for AdapterRef<T> {
    fn clone(&self) -> Self {
        match self {
            Self::Owned(b) => Self::Owned(b.clone_box()),
            Self::Borrowed(r) => Self::Borrowed(*r),
        }
    }
}

impl<T: 'static> AdapterRef<T> {
    fn get(&self) -> &dyn TypeAdapter<T> {
        match self {
            Self::Owned(b) => b.as_ref(),
            Self::Borrowed(r) => *r,
        }
    }
}

// =============================================================================
// TypeAdapter
// =============================================================================

/// Internal interface implemented by every concrete adapter
/// (primitive, array, optional, struct, enum).
///
/// Only adapters defined inside this crate can satisfy it.
/// For use only by code generated by the Skir code generator.
pub(super) trait TypeAdapter<T>: Send + Sync {
    /// Returns `true` when `input` is the default (zero) value for `T`.
    fn is_default(&self, input: &T) -> bool;

    /// Writes the JSON representation of `input` to `out`.
    ///
    /// `eol_indent` is `None` for dense (compact) output. In readable (indented)
    /// mode it is `Some` with a string composed of `"\n"` followed by the
    /// indentation prefix for the current nesting level.
    fn to_json(&self, input: &T, eol_indent: Option<&str>, out: &mut String);

    /// Deserialises a [`serde_json::Value`] into `T`.
    ///
    /// Set `keep_unrecognized_values` to preserve fields/variants from a newer
    /// schema version that are not recognised by this decoder.
    fn from_json(
        &self,
        json: &serde_json::Value,
        keep_unrecognized_values: bool,
    ) -> Result<T, String>;

    /// Serialises `input` to the Skir binary wire format, appending bytes to `out`.
    fn encode(&self, input: &T, out: &mut Vec<u8>);

    /// Deserialises a value from the Skir binary wire format, advancing the
    /// slice past the bytes consumed.
    ///
    /// Set `keep_unrecognized_values` to preserve fields/variants from a newer
    /// schema version.
    fn decode(&self, input: &mut &[u8], keep_unrecognized_values: bool) -> Result<T, String>;

    /// Returns a [`TypeDescriptor`] that describes the schema of `T`.
    fn type_descriptor(&self) -> TypeDescriptor;

    /// Returns a boxed clone of this adapter.
    fn clone_box(&self) -> Box<dyn TypeAdapter<T>>;
}
