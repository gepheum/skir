// Reflection allows you to inspect and traverse Skir types and values at
// runtime.
//
// When *not* to use reflection: when working with a specific type known at
// compile-time, you can directly access the properties and constructor of the
// object, so you don't need reflection.
//
// When to use reflection: when the Skir type is passed as a parameter (like the
// generic T here), you need reflection - the ability to programmatically
// inspect a type's structure (fields, their types, etc.) and manipulate values
// without compile-time knowledge of that structure.
//
// This pattern is useful for building generic utilities like:
//   - Custom validators that work across all your types
//   - Custom formatters/normalizers (like this uppercase example)
//   - Serialization utilities
//   - Any operation that needs to work uniformly across different Skir types

package examples;

import build.skir.reflection.ArrayDescriptor;
import build.skir.reflection.EnumDescriptor;
import build.skir.reflection.OptionalDescriptor;
import build.skir.reflection.ReflectiveTransformer;
import build.skir.reflection.ReflectiveTypeVisitor;
import build.skir.reflection.StructDescriptor;
import build.skir.reflection.TypeDescriptor;
import build.skir.reflection.TypeEquivalence;
import java.util.List;
import java.util.Optional;

public class AllStringsToUpperCase {
  private AllStringsToUpperCase() {}

  /**
   * Using reflection, converts all the strings contained in {@code input} to upper case. Accepts
   * any Skir type.
   *
   * <p>Example input:
   *
   * <pre>
   * {
   *   "user_id": 123,
   *   "name": "Tarzan",
   *   "quote": "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
   *   "pets": [
   *     {
   *       "name": "Cheeta",
   *       "height_in_meters": 1.67,
   *       "picture": "🐒"
   *     }
   *   ],
   *   "subscription_status": {
   *     "kind": "trial",
   *     "value": {
   *       "start_time": {
   *         "unix_millis": 1743592409000,
   *         "formatted": "2025-04-02T11:13:29Z"
   *       }
   *     }
   *   }
   * }
   * </pre>
   *
   * <p>Example output:
   *
   * <pre>
   * {
   *   "user_id": 123,
   *   "name": "TARZAN",
   *   "quote": "AAAAAAAAAAYAAAAAAAAAAYAAAAAAAAAA",
   *   "pets": [
   *     {
   *       "name": "CHEETA",
   *       "height_in_meters": 1.67,
   *       "picture": "🐒"
   *     }
   *   ],
   *   "subscription_status": {
   *     "kind": "trial",
   *     "value": {
   *       "start_time": {
   *         "unix_millis": 1743592409000,
   *         "formatted": "2025-04-02T11:13:29Z"
   *       }
   *     }
   *   }
   * }
   * </pre>
   */
  public static <T> T allStringsToUpperCase(T input, TypeDescriptor.Reflective<T> descriptor) {
    final ToUpperCaseVisitor<T> visitor = new ToUpperCaseVisitor<>(input);
    descriptor.accept(visitor);
    return visitor.result;
  }

  private static class ToUpperCaseTransformer implements ReflectiveTransformer {
    static final ToUpperCaseTransformer INSTANCE = new ToUpperCaseTransformer();

    private ToUpperCaseTransformer() {}

    @Override
    public <T> T transform(T input, TypeDescriptor.Reflective<T> descriptor) {
      return allStringsToUpperCase(input, descriptor);
    }
  }

  private static class ToUpperCaseVisitor<T> extends ReflectiveTypeVisitor.Noop<T> {
    final T input;
    T result;

    ToUpperCaseVisitor(T input) {
      this.input = input;
      this.result = input;
    }

    @Override
    public <NotNull> void visitOptional(
        OptionalDescriptor.Reflective<NotNull> descriptor,
        TypeEquivalence<T, NotNull> equivalence) {
      result =
          equivalence.toT(
              descriptor.map(equivalence.fromT(input), ToUpperCaseTransformer.INSTANCE));
    }

    @Override
    public <NotNull> void visitJavaOptional(
        OptionalDescriptor.JavaReflective<NotNull> descriptor,
        TypeEquivalence<T, Optional<NotNull>> equivalence) {
      result =
          equivalence.toT(
              descriptor.map(equivalence.fromT(input), ToUpperCaseTransformer.INSTANCE));
    }

    @Override
    public <E, L extends List<? extends E>> void visitArray(
        ArrayDescriptor.Reflective<E, L> descriptor, TypeEquivalence<T, L> equivalence) {
      result =
          equivalence.toT(
              descriptor.map(equivalence.fromT(input), ToUpperCaseTransformer.INSTANCE));
    }

    @Override
    public <Mutable> void visitStruct(StructDescriptor.Reflective<T, Mutable> descriptor) {
      T transformed = descriptor.mapFields(input, ToUpperCaseTransformer.INSTANCE);
      result = transformed;
    }

    @Override
    public void visitEnum(EnumDescriptor.Reflective<T> descriptor) {
      result = descriptor.mapValue(input, ToUpperCaseTransformer.INSTANCE);
    }

    @Override
    public void visitString(TypeEquivalence<T, String> equivalence) {
      result = equivalence.toT(equivalence.fromT(input).toUpperCase());
    }
  }
}
