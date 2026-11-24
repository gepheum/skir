import build.skir.KeyedList;
import build.skir.service.Method;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import skirout.constants.Constants;
import skirout.enums.JsonValue;
import skirout.external.gepheum.skir_fantasy_game_example.fantasy_game.Point2D;
import skirout.methods.Methods;
import skirout.structs.Color;
import skirout.structs.Point;
import skirout.structs.RecA;
import skirout.structs.RecB;
import skirout.structs.Triangle;

public class SkiroutTest {
  @Test
  public void testMethod() {
    final Method<Point, JsonValue> method = Methods.MY_PROCEDURE;
    Assertions.assertEquals("MyProcedure", method.name());
    Assertions.assertEquals(674706602, method.number());
    Assertions.assertEquals(Point.SERIALIZER, method.requestSerializer());
    Assertions.assertEquals(JsonValue.SERIALIZER, method.responseSerializer());
  }

  @Test
  public void testConstant() {
    Assertions.assertEquals(3.141592653589793, Constants.PI);
  }

  @Test
  public void testStructTypeDescriptor() {
    Assertions.assertTrue(Point.TYPE_DESCRIPTOR.asJsonCode().startsWith("{"));
  }

  @Test
  public void testStructEquals() {
    final Set<Point> points = new HashSet<>();
    points.add(Point.builder().setX(10).setY(20).build());
    points.add(Point.builder().setX(10).setY(20).build());
    points.add(Point.builder().setX(10).setY(21).build());
    points.add(Point.builder().setX(10).setY(21).build());
    points.add(Point.builder().setX(11).setY(20).build());
    points.add(Point.builder().setX(11).setY(20).build());
    Assertions.assertEquals(3, points.size());
  }

  @Test
  public void testStructDefault() {
    Assertions.assertEquals(Point.builder().setX(0).setY(0).build(), Point.DEFAULT);
    Assertions.assertEquals(Point.partialBuilder().build(), Point.DEFAULT);
  }

  @Test
  public void testStructToString() {
    Assertions.assertEquals(
        "{\n  \"x\": 100\n}", Point.builder().setX(100).setY(0).build().toString());
  }

  @Test
  public void testStructToBuilder() {
    final Point point = Point.builder().setX(5).setY(10).build().toBuilder().setY(20).build();
    Assertions.assertEquals(Point.builder().setX(5).setY(20).build(), point);
  }

  @Test
  public void testStructBuilderUpdate() {
    final Color red = Color.builder().setB(0).setG(0).setR(255).build();
    final Color purple = Color.builder().setB(255).setG(0).setR(255).build();
    final Triangle triangle =
        Triangle.partialBuilder().setColor(red).build().toBuilder()
            .updateColor(color -> color.toBuilder().setB(255).build())
            .build();
    Assertions.assertEquals(Triangle.partialBuilder().setColor(purple).build(), triangle);
  }

  @Test
  public void testRecursiveStruct() {
    final RecA recA =
        RecA.partialBuilder()
            .setA(
                RecA.partialBuilder()
                    .setB(
                        RecB.partialBuilder()
                            .setA(RecA.partialBuilder().setBool(true).build())
                            .build())
                    .build())
            .build();
    Assertions.assertEquals(RecB.DEFAULT, recA.b());
    Assertions.assertEquals(
        "{\n  \"a\": {\n    \"b\": {\n      \"a\": {\n        \"bool\": true\n      }\n    }\n  }\n}",
        recA.toString());
  }

  @Test
  public void testEnumKind() {
    Assertions.assertEquals(
        JsonValue.Kind.ARRAY_WRAPPER, JsonValue.wrapArray(new ArrayList<>()).kind());
    Assertions.assertEquals(JsonValue.Kind.NULL_CONST, JsonValue.NULL.kind());
    Assertions.assertEquals(JsonValue.Kind.UNKNOWN, JsonValue.UNKNOWN.kind());
  }

  @Test
  public void testEnumEquals() {
    final HashSet<JsonValue> set = new HashSet<>();
    set.add(JsonValue.UNKNOWN);
    set.add(JsonValue.UNKNOWN);
    set.add(JsonValue.SERIALIZER.fromJsonCode("10000"));
    Assertions.assertEquals(1, set.size());
    set.add(JsonValue.NULL);
    set.add(JsonValue.NULL);
    Assertions.assertEquals(2, set.size());
    set.add(JsonValue.wrapArray(new ArrayList<>()));
    set.add(JsonValue.wrapArray(new ArrayList<>()));
    final List<JsonValue> array = new ArrayList<>();
    array.add(JsonValue.NULL);
    set.add(JsonValue.wrapArray(new ArrayList<>(array)));
    set.add(JsonValue.wrapArray(new ArrayList<>(array)));
    Assertions.assertEquals(4, set.size());
  }

  @Test
  public void testEnumToString() {
    Assertions.assertEquals("\"null\"", JsonValue.NULL.toString());
    Assertions.assertEquals("\"unknown\"", JsonValue.UNKNOWN.toString());
    Assertions.assertEquals(
        "{\n  \"kind\": \"array\",\n  \"value\": []\n}",
        JsonValue.wrapArray(new ArrayList<>()).toString());
  }

  @Test
  public void testEnumAs() {
    final List<JsonValue> array = new ArrayList<>();
    array.add(JsonValue.NULL);
    JsonValue jsonValue = JsonValue.wrapArray(array);
    Assertions.assertEquals(array, jsonValue.asArray());
    Assertions.assertTrue(jsonValue.isArray());
    Assertions.assertFalse(JsonValue.NULL.isArray());
  }

  @Test
  public void testEnumVisitor() {
    final EnumVisitor visitor = new EnumVisitor();
    Assertions.assertEquals(
        "hi array of size 0", JsonValue.wrapArray(new ArrayList<>()).accept(visitor));
    Assertions.assertEquals("hi unknown", JsonValue.UNKNOWN.accept(visitor));
  }

  private static class EnumVisitor implements JsonValue.Visitor<String> {
    @Override
    public String onUnknown() {
      return "hi unknown";
    }

    @Override
    public String onArray(List<JsonValue> value) {
      return "hi array of size " + value.size();
    }

    @Override
    public String onNull() {
      return "hi null";
    }

    @Override
    public String onBoolean(boolean value) {
      return "hi boolean";
    }

    @Override
    public String onNumber(double value) {
      return "hi number";
    }

    @Override
    public String onString(String value) {
      return "hi string";
    }

    @Override
    public String onObject(KeyedList<JsonValue.Pair, String> value) {
      return "hi object";
    }
  }

  @Test
  public void testEnumTypeDescriptor() {
    // Assertions.assertTrue(JsonValue.TYPE_DESCRIPTOR.asJsonCode().startsWith("{"));
    Assertions.assertTrue(RecA.TYPE_DESCRIPTOR.asJsonCode().startsWith("{"));
  }

  @Test
  public void testExternalDependency() {
    Point2D.builder();
  }
}
