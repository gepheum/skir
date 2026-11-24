const core = @import("serializer.zig");
const enum_adapter = @import("enum_adapter.zig");
const keyed_array = @import("keyed_array.zig");
const recursive = @import("recursive.zig");
const service = @import("service.zig");
const service_client = @import("service_client.zig");
const serializers = @import("serializers.zig");
const struct_adapter = @import("struct_adapter.zig");
const timestamp = @import("timestamp.zig");
const type_descriptor = @import("type_descriptor.zig");
const unrecognized = @import("unrecognized.zig");

/// Runtime entry-point module used by generated Zig code.
///
/// Import this module to access serializers, service/server APIs, client APIs,
/// and schema descriptor helpers from one place.

// Core runtime types
pub const KeyedArray = keyed_array.KeyedArray;
pub const Method = core.Method;
pub const Recursive = recursive.Recursive;
pub const SerializeFormat = core.SerializeFormat;
pub const Serializer = core.Serializer;
pub const Timestamp = timestamp.Timestamp;
pub const _UnrecognizedFields = unrecognized.UnrecognizedFields;
pub const _UnrecognizedVariant = unrecognized.UnrecognizedVariant;

// Serializer factories
pub const arraySerializer = serializers.arraySerializer;
pub const boolSerializer = serializers.boolSerializer;
pub const bytesSerializer = serializers.bytesSerializer;
pub const float32Serializer = serializers.float32Serializer;
pub const float64Serializer = serializers.float64Serializer;
pub const hash64Serializer = serializers.hash64Serializer;
pub const int32Serializer = serializers.int32Serializer;
pub const int64Serializer = serializers.int64Serializer;
pub const keyedArraySerializer = serializers.keyedArraySerializer;
pub const optionalSerializer = serializers.optionalSerializer;
pub const pointerSerializer = serializers.pointerSerializer;
pub const recursiveSerializer = serializers.recursiveSerializer;
pub const stringSerializer = serializers.stringSerializer;
pub const timestampSerializer = serializers.timestampSerializer;

// RPC service/runtime
pub const HttpErrorCode = service.HttpErrorCode;
pub const MethodResult = service.MethodResult;
pub const RawResponse = service.RawResponse;
pub const RpcError = service_client.RpcError;
pub const RpcResult = service_client.RpcResult;
pub const Service = service.Service;
pub const ServiceClient = service_client.ServiceClient;
pub const ServiceError = service.ServiceError;
pub const getPercentDecodedQueryFromUrl = service.getPercentDecodedQueryFromUrl;

// Type descriptors
pub const ArrayDescriptor = type_descriptor.ArrayDescriptor;
pub const EnumConstantVariant = type_descriptor.EnumConstantVariant;
pub const EnumVariant = type_descriptor.EnumVariant;
pub const EnumDescriptor = type_descriptor.EnumDescriptor;
pub const EnumWrapperVariant = type_descriptor.EnumWrapperVariant;
pub const PrimitiveType = type_descriptor.PrimitiveType;
pub const StructDescriptor = type_descriptor.StructDescriptor;
pub const StructField = type_descriptor.StructField;
pub const TypeDescriptor = type_descriptor.TypeDescriptor;
pub const typeDescriptorFromJson = type_descriptor.typeDescriptorFromJson;

// Internal hooks (generated/runtime internals)
pub const _EnumAdapter = enum_adapter.EnumAdapter;
pub const _enumSerializerFromStatic = enum_adapter._enumSerializerFromStatic;
pub const _StructAdapter = struct_adapter.StructAdapter;
pub const _SerializerVTable = core._SerializerVTable;
pub const _serializerFromAdapter = core._serializerFromAdapter;
pub const _structSerializerFromStatic = struct_adapter._structSerializerFromStatic;

// Include tests from service modules so `zig build test` discovers them.
test {
    _ = @import("service.zig");
    _ = @import("service_client.zig");
}
