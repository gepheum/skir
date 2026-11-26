# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Skir
  class Serializer
    extend T::Sig
    extend T::Generic

    Elem = type_member
  end

  # Descriptor for a Skir RPC method.
  class Method
    extend T::Sig
    extend T::Generic

    Request = type_member
    Response = type_member

    sig { returns(String) }
    attr_reader :name

    sig { returns(Integer) }
    attr_reader :number

    sig { returns(Serializer[Request]) }
    attr_reader :request_serializer

    sig { returns(Serializer[Response]) }
    attr_reader :response_serializer

    sig { returns(String) }
    attr_reader :doc

    sig do
      params(
        name: String,
        number: Integer,
        request_serializer: Serializer[Request],
        response_serializer: Serializer[Response],
        doc: String
      ).void
    end
    def initialize(name:, number:, request_serializer:, response_serializer:, doc: "")
      @name = T.let(name.dup.freeze, String)
      @number = T.let(number, Integer)
      @request_serializer = T.let(request_serializer, Serializer[Request])
      @response_serializer = T.let(response_serializer, Serializer[Response])
      @doc = T.let(doc.dup.freeze, String)
      freeze
    end
  end
end
