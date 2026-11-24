// These lints fire on intentional API design choices in this library:
// - `wrong_self_convention`: `from_*` methods on serializer adapters take `&self`
//   because they're instance methods on a stateful adapter, not free constructors.
// - `too_many_arguments`: internal codec functions have many parameters by design.
// - `type_complexity`: some serializer types are inherently verbose.
#![allow(clippy::wrong_self_convention)]
#![allow(clippy::too_many_arguments)]
#![allow(clippy::type_complexity)]

pub mod enum_adapter;
pub mod keyed_vec;
pub mod method;
pub mod reflection;
pub mod serializer;
pub mod serializers;
pub mod service;
pub mod service_client;
pub mod struct_adapter;
pub mod unrecognized;

// =============================================================================
// Re-exports
// =============================================================================

// keyed_vec
pub use keyed_vec::KeyedVec;
pub use keyed_vec::KeyedVecSpec;

// serializer
pub use serializer::DeserializeError;
pub use serializer::JsonFlavor;
pub use serializer::Serializer;
pub use serializer::UnrecognizedValues;

// method
pub use method::Method;

// reflection (exposed for tests)
pub use reflection::TypeDescriptor;

// unrecognized
pub use unrecognized::UnrecognizedFields;
pub use unrecognized::UnrecognizedVariant;

// service
pub use service::HttpErrorCode;
pub use service::MethodErrorInfo;
pub use service::RawResponse;
pub use service::Service;
pub use service::ServiceBuilder;
pub use service::ServiceError;

// service_client
pub use service_client::RpcError;
pub use service_client::ServiceClient;

/// Items from the `internal` modules of sub-modules, re-exported as a single
/// top-level `internal` module.
pub mod internal {
    // keyed_vec::internal
    pub use super::keyed_vec::internal::BorrowLookup;
    pub use super::keyed_vec::internal::CopyLookup;
    pub use super::keyed_vec::internal::Lookup;

    // enum_adapter::internal
    pub use super::serializers::internal::option_box_serializer;
    pub use super::serializers::internal::recursive_serializer;

    // struct_adapter::internal
    pub use super::struct_adapter::internal::struct_serializer_from_static;
    pub use super::struct_adapter::internal::StructAdapter;

    // enum_adapter::internal
    pub use super::enum_adapter::internal::enum_serializer_from_static;
    pub use super::enum_adapter::internal::EnumAdapter;
}
