use std::marker::PhantomData;
use std::vec::Vec;

/// Internal data owned by `UnrecognizedFields<T>` instances.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct UnrecognizedFieldsData<T> {
    pub(super) format: UnrecognizedFormat,
    pub(super) array_len: u32,
    // Raw bytes of the unrecognized field values.
    pub(super) values: Vec<u8>,
    _phantom: PhantomData<T>,
}

impl<T> UnrecognizedFieldsData<T> {
    /// Creates an [`UnrecognizedFields`] carrying extra JSON slots from a dense
    /// JSON array.  `array_len` is the full slot count (recognized +
    /// unrecognized); `json_bytes` is the serialized JSON of the extra elements
    /// as a JSON array string (e.g. `"[1,\"foo\"]"`).  
    pub(super) fn new_from_json(array_len: u32, json_bytes: Vec<u8>) -> Box<Self> {
        Box::new(UnrecognizedFieldsData {
            format: UnrecognizedFormat::DenseJson,
            array_len,
            values: json_bytes,
            _phantom: PhantomData,
        })
    }

    /// Creates an [`UnrecognizedFields`] carrying raw binary wire bytes for
    /// extra slots from a binary-encoded struct.
    pub(super) fn new_from_bytes(array_len: u32, raw_bytes: Vec<u8>) -> Box<Self> {
        Box::new(UnrecognizedFieldsData {
            format: UnrecognizedFormat::Bytes,
            array_len,
            values: raw_bytes,
            _phantom: PhantomData,
        })
    }
}

/// Stores an unrecognized enum variant encountered while deserializing.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct UnrecognizedVariantData<T> {
    pub(super) format: UnrecognizedFormat,
    /// Wire number of the unrecognized variant.
    pub(super) number: i32,
    /// Empty if the unrecognized variant is a constant variant (number).
    pub(super) value: Vec<u8>,
    _phantom: PhantomData<T>,
}

impl<T> UnrecognizedVariantData<T> {
    /// Creates an [`UnrecognizedVariant`] for an unrecognized constant variant
    /// from a JSON number-like context.  `raw_bytes` is the re-encoded number.
    pub(super) fn new_from_bytes(number: i32, raw_bytes: Vec<u8>) -> Box<Self> {
        Box::new(UnrecognizedVariantData {
            format: UnrecognizedFormat::Bytes,
            number,
            value: raw_bytes,
            _phantom: PhantomData,
        })
    }

    /// Creates an [`UnrecognizedVariant`] for an unrecognized variant carrying
    /// a JSON-encoded value (wrapper variant or raw JSON element).
    pub(super) fn new_from_json(number: i32, json_bytes: Vec<u8>) -> Box<Self> {
        Box::new(UnrecognizedVariantData {
            format: UnrecognizedFormat::DenseJson,
            number,
            value: json_bytes,
            _phantom: PhantomData,
        })
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub(super) enum UnrecognizedFormat {
    #[default]
    Unknown,
    DenseJson,
    Bytes,
}

/// Stores unrecognized fields encountered while deserializing a struct of type
/// `T`.
pub type UnrecognizedFields<T> = Box<UnrecognizedFieldsData<T>>;

/// Stores unrecognized fields encountered while deserializing an enum of type
/// `T`.
pub type UnrecognizedVariant<T> = Box<UnrecognizedVariantData<T>>;
