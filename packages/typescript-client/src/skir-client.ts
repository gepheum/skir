import type { _INITIALIZER as initializerKey } from "./codegen-runtime/base.js";

export type { BinaryForm } from "./binary-io.js";
export { ByteString } from "./byte-string.js";
export {
  _EMPTY_ARRAY,
  _EnumBase,
  _FrozenBase,
  _toFrozenArray,
} from "./codegen-runtime/base.js";
export { _initModuleClasses } from "./codegen-runtime/initialize-classes.js";
export {
  installServiceOnExpressApp,
  Service,
  ServiceClient,
  ServiceError,
} from "./rpc.js";
export type {
  Method,
  RawResponse,
  RequestHandler,
  RequestMeta,
  ServiceOptions,
} from "./rpc.js";
export type {
  Freezable,
  Json,
  JsonFlavor,
  MutableForm,
  Serializer,
} from "./serializers/base.js";
export {
  arraySerializer,
  optionalSerializer,
} from "./serializers/collections.js";
export { primitiveSerializer } from "./serializers/primitives.js";
export {
  parseTypeDescriptorFromJson,
  parseTypeDescriptorFromJsonCode,
} from "./serializers/type-descriptor.js";
export type {
  ArrayDescriptor,
  EnumConstantVariant,
  EnumDescriptor,
  EnumVariant,
  EnumVariantResult,
  EnumWrapperVariant,
  OptionalDescriptor,
  PrimitiveDescriptor,
  PrimitiveTypes,
  StructDescriptor,
  StructField,
  StructFieldResult,
  TypeDescriptor,
  TypeDescriptorSpecialization,
} from "./serializers/type-descriptor.js";
export { Timestamp } from "./timestamp.js";
// Generated declarations use this key; it has no runtime value.
export declare const _INITIALIZER: typeof initializerKey;
