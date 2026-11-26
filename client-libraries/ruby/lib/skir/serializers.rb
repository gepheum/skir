# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "internal/arrays"
require_relative "internal/optionals"
require_relative "internal/primitives"
require_relative "serializer"

module Skir
  extend T::Sig

  PRIMITIVE_SERIALIZERS = T.let(
    {
      "bool" => Internal.make_serializer(Internal::Primitives::BOOL_ADAPTER),
      "int32" => Internal.make_serializer(Internal::Primitives::INT32_ADAPTER),
      "int64" => Internal.make_serializer(Internal::Primitives::INT64_ADAPTER),
      "hash64" => Internal.make_serializer(Internal::Primitives::HASH64_ADAPTER),
      "float32" => Internal.make_serializer(Internal::Primitives::FLOAT32_ADAPTER),
      "float64" => Internal.make_serializer(Internal::Primitives::FLOAT64_ADAPTER),
      "timestamp" => Internal.make_serializer(Internal::Primitives::TIMESTAMP_ADAPTER),
      "string" => Internal.make_serializer(Internal::Primitives::STRING_ADAPTER),
      "bytes" => Internal.make_serializer(Internal::Primitives::BYTES_ADAPTER)
    }.freeze,
    T::Hash[String, Serializer[T.untyped]]
  )

  sig { params(primitive: T.any(String, Symbol)).returns(Serializer[T.untyped]) }
  def self.primitive_serializer(primitive)
    PRIMITIVE_SERIALIZERS.fetch(primitive.to_s)
  end

  sig do
    type_parameters(:Other)
      .params(other_serializer: Serializer[T.type_parameter(:Other)])
      .returns(Serializer[T.nilable(T.type_parameter(:Other))])
  end
  def self.optional_serializer(other_serializer)
    Internal.make_serializer(Internal::Optionals.get_optional_adapter(other_serializer._adapter))
  end

  sig do
    type_parameters(:Item)
      .params(item_serializer: Serializer[T.type_parameter(:Item)])
      .returns(Serializer[T::Array[T.type_parameter(:Item)]])
  end
  def self.array_serializer(item_serializer)
    Internal.make_serializer(Internal::Arrays.get_array_adapter(item_serializer._adapter, []))
  end
end
