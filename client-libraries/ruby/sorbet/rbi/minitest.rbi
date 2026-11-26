# typed: true

module Minitest
  class Test
    def assert(test, msg = nil); end
    def refute(test, msg = nil); end
    def assert_equal(exp, act, msg = nil); end
    def refute_equal(exp, act, msg = nil); end
    def assert_same(exp, act, msg = nil); end
    def refute_same(exp, act, msg = nil); end
    def assert_nil(obj, msg = nil); end
    def refute_nil(obj, msg = nil); end
    def assert_includes(collection, obj, msg = nil); end
    def assert_instance_of(cls, obj, msg = nil); end
    def assert_in_delta(exp, act, delta = 0.001, msg = nil); end
    def assert_operator(o1, op, o2 = T.unsafe(nil), msg = nil); end
    def assert_predicate(o1, op, msg = nil); end
    def refute_predicate(o1, op, msg = nil); end
    def assert_raises(*exp, &blk); end
    def flunk(msg = nil); end
  end
end
