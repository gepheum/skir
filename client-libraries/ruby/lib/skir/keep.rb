# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Skir
  # Sentinel type used in `replace` methods to keep a field's existing value.
  class Keep
    extend T::Sig

    sig { void }
    def initialize
      freeze
    end
  end

  KEEP = T.let(Keep.new, Keep)
end
