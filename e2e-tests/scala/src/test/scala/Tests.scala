import build.skir.UnrecognizedValuesPolicy
import build.skir.reflection.ArrayDescriptor
import build.skir.reflection.EnumConstantVariant
import build.skir.reflection.EnumDescriptor
import build.skir.reflection.EnumWrapperVariant
import build.skir.reflection.OptionalDescriptor
import build.skir.reflection.PrimitiveDescriptor
import build.skir.reflection.RecordDescriptor
import build.skir.reflection.StructDescriptor
import build.skir.reflection.StructField
import build.skir.reflection.TypeDescriptor
import com.google.common.truth.Truth.assertThat
import org.junit.jupiter.api.Test
import java.time.Instant
import scala.jdk.CollectionConverters.*

class Tests {
  @Test
  def testGeneratedStructToString(): Unit = {
    assertThat(
      skirout.full_name.FullName(
        firstName = "John",
        lastName = "Doe",
      ).toString,
    ).isEqualTo(
      "{\n" +
        "  \"first_name\": \"John\",\n" +
        "  \"last_name\": \"Doe\"\n" +
        "}",
    )
    assertThat(
      skirout.full_name.FullName.partial().toString,
    ).isEqualTo("{}")
  }

  @Test
  def testGeneratedStructEquals(): Unit = {
    assertThat(
      skirout.full_name.FullName(
        firstName = "John",
        lastName = "Doe",
      ),
    ).isEqualTo(
      skirout.full_name.FullName(
        firstName = "John",
        lastName = "Doe",
      ),
    )
    assertThat(
      skirout.full_name.FullName(
        firstName = "John",
        lastName = "",
      ),
    ).isNotEqualTo(
      skirout.full_name.FullName(
        firstName = "John",
        lastName = "Doe",
      ),
    )
  }

  @Test
  def testGeneratedStructHashCode(): Unit = {
    val set = scala.collection.mutable.Set[skirout.full_name.FullName]()
    set.add(skirout.full_name.FullName(firstName = "John", lastName = "Doe"))
    set.add(skirout.full_name.FullName(firstName = "", lastName = "Doe"))
    set.add(skirout.full_name.FullName(firstName = "John", lastName = ""))
    set.add(skirout.full_name.FullName(firstName = "John", lastName = "Doe"))
    assertThat(set.size).isEqualTo(3)
  }

  @Test
  def testGeneratedStructPartialStaticFactoryMethod(): Unit = {
    val fullName = skirout.full_name.FullName.partial(firstName = "John")
    assertThat(fullName.firstName).isEqualTo("John")
    assertThat(fullName.lastName).isEqualTo("")
  }

  @Test
  def testGeneratedStructToMutable(): Unit = {
    val fullName = skirout.full_name.FullName(
      firstName = "John",
      lastName = "Doe",
    )
    val mutableFullName = fullName.toMutable()
    mutableFullName.firstName = "Jane"
    assertThat(mutableFullName.toFrozen()).isEqualTo(
      skirout.full_name.FullName(
        firstName = "Jane",
        lastName = "Doe",
      ),
    )
  }

  @Test
  def testGeneratedStructToFrozenReturnsThis(): Unit = {
    val fullName = skirout.full_name.FullName(
      firstName = "John",
      lastName = "Doe",
    )
    assertThat(fullName.toFrozen()).isSameInstanceAs(fullName)
  }

  @Test
  def testGeneratedStructCopy(): Unit = {
    val fullName = skirout.full_name.FullName(
      firstName = "John",
      lastName = "Doe",
    )
    assertThat(fullName.copy(firstName = "Jane")).isEqualTo(
      skirout.full_name.FullName(
        firstName = "Jane",
        lastName = "Doe",
      ),
    )
    assertThat(fullName.copy()).isSameInstanceAs(fullName)

    assertThat(
      skirout.structs
        .Triangle(
          color = skirout.structs.Color(r = 127, g = 128, b = 139),
          points = Seq(new skirout.structs.Point.Mutable(x = 1, y = 2)).asJava,
        )
        .copy(
          color = new skirout.structs.Color.Mutable(r = 10),
        ),
    ).isEqualTo(
      skirout.structs.Triangle(
        color = skirout.structs.Color(r = 10, g = 0, b = 0),
        points = Seq(skirout.structs.Point(x = 1, y = 2)).asJava,
      ),
    )
  }

  @Test
  def testGeneratedStructMutableGetter(): Unit = {
    val triangle = skirout.structs.Triangle(
      color = skirout.structs.Color(r = 127, g = 128, b = 139),
      points = Seq(
        skirout.structs.Point(x = 0, y = 0),
        skirout.structs.Point(x = 10, y = 0),
        skirout.structs.Point(x = 0, y = 20),
      ).asJava,
    )
    val mutableTriangle = triangle.toMutable()
    assertThat(mutableTriangle.toFrozen().color).isSameInstanceAs(triangle.color)
    assertThat(mutableTriangle.toFrozen().points).isSameInstanceAs(
      triangle.points,
    )

    mutableTriangle.mutableColor.r = 5
    assertThat(mutableTriangle.toFrozen().color).isEqualTo(
      skirout.structs.Color(r = 5, g = 128, b = 139),
    )
    assertThat(mutableTriangle.toFrozen().points).isSameInstanceAs(
      triangle.points,
    )

    mutableTriangle.mutablePoints.add(
      new skirout.structs.Point.Mutable(x = 10, y = 10),
    )
    mutableTriangle.mutablePoints.add(
      new skirout.structs.Point.Mutable(x = 20, y = 20),
    )
    assertThat(mutableTriangle.toFrozen().points).isEqualTo(
      Seq(
        skirout.structs.Point(x = 0, y = 0),
        skirout.structs.Point(x = 10, y = 0),
        skirout.structs.Point(x = 0, y = 20),
        skirout.structs.Point(x = 10, y = 10),
        skirout.structs.Point(x = 20, y = 20),
      ).asJava,
    )
  }

  @Test
  def testGeneratedStructOrMutableSealedTrait(): Unit = {
    val person: skirout.full_name.FullName_OrMutable =
      skirout.full_name.FullName(firstName = "John", lastName = "Doe")
    val mutablePerson: skirout.full_name.FullName_OrMutable =
      new skirout.full_name.FullName.Mutable(firstName = "John")
    assertThat(person.toFrozen()).isSameInstanceAs(person)
    assertThat(mutablePerson.toFrozen().firstName).isEqualTo("John")
  }

  @Test
  def testGeneratedStructReflection(): Unit = {
    assertThat(skirout.structs.Item.User.typeDescriptor.getName).isEqualTo("User")
    assertThat(skirout.structs.Item.User.typeDescriptor.getQualifiedName)
      .isEqualTo("Item.User")
    assertThat(skirout.structs.Item.typeDescriptor.getName).isEqualTo("Item")
    assertThat(skirout.structs.Item.typeDescriptor.getQualifiedName)
      .isEqualTo("Item")
    assertThat(skirout.vehicles.car.Car.typeDescriptor.getModulePath)
      .isEqualTo("vehicles/car.skir")

    assertThat(skirout.structs.Color.typeDescriptor.getRemovedNumbers).isEmpty()
    assertThat(skirout.structs.FullName.typeDescriptor.getRemovedNumbers)
      .isEqualTo(Set(java.lang.Integer.valueOf(1)).asJava)

    val typeDescriptor = skirout.vehicles.car.Car.typeDescriptor
    assertThat(typeDescriptor.getFields).hasSize(4)
    val field = typeDescriptor
      .getField("purchase_time")
      .asInstanceOf[StructField.Reflective[
        skirout.vehicles.car.Car,
        skirout.vehicles.car.Car.Mutable,
        Instant,
      ]]
    assertThat(field).isNotNull()
    val mutable: skirout.vehicles.car.Car.Mutable =
      typeDescriptor.newMutable(null)
    field.set(mutable, Instant.ofEpochMilli(1000))
    assertThat(mutable.toFrozen().purchaseTime)
      .isEqualTo(Instant.ofEpochMilli(1000))
    assertThat(typeDescriptor.toFrozen(mutable).purchaseTime)
      .isEqualTo(Instant.ofEpochMilli(1000))
    assertThat(field.get(mutable.toFrozen()))
      .isEqualTo(Instant.ofEpochMilli(1000))

    val expectedJson =
      "{\n" +
        "  \"type\": {\n" +
        "    \"kind\": \"record\",\n" +
        "    \"value\": \"vehicles/car.skir:Car\"\n" +
        "  },\n" +
        "  \"records\": [\n" +
        "    {\n" +
        "      \"kind\": \"struct\",\n" +
        "      \"id\": \"vehicles/car.skir:Car\",\n" +
        "      \"fields\": [\n" +
        "        {\n" +
        "          \"name\": \"model\",\n" +
        "          \"number\": 0,\n" +
        "          \"type\": {\n" +
        "            \"kind\": \"primitive\",\n" +
        "            \"value\": \"string\"\n" +
        "          }\n" +
        "        },\n" +
        "        {\n" +
        "          \"name\": \"purchase_time\",\n" +
        "          \"number\": 1,\n" +
        "          \"type\": {\n" +
        "            \"kind\": \"primitive\",\n" +
        "            \"value\": \"timestamp\"\n" +
        "          }\n" +
        "        },\n" +
        "        {\n" +
        "          \"name\": \"owner\",\n" +
        "          \"number\": 2,\n" +
        "          \"type\": {\n" +
        "            \"kind\": \"record\",\n" +
        "            \"value\": \"user.skir:User\"\n" +
        "          }\n" +
        "        },\n" +
        "        {\n" +
        "          \"name\": \"second_owner\",\n" +
        "          \"number\": 3,\n" +
        "          \"type\": {\n" +
        "            \"kind\": \"optional\",\n" +
        "            \"value\": {\n" +
        "              \"kind\": \"record\",\n" +
        "              \"value\": \"user.skir:User\"\n" +
        "            }\n" +
        "          }\n" +
        "        }\n" +
        "      ]\n" +
        "    },\n" +
        "    {\n" +
        "      \"kind\": \"struct\",\n" +
        "      \"id\": \"user.skir:User\",\n" +
        "      \"fields\": [\n" +
        "        {\n" +
        "          \"name\": \"user_id\",\n" +
        "          \"number\": 0,\n" +
        "          \"type\": {\n" +
        "            \"kind\": \"primitive\",\n" +
        "            \"value\": \"int64\"\n" +
        "          }\n" +
        "        }\n" +
        "      ]\n" +
        "    }\n" +
        "  ]\n" +
        "}"
    assertThat(typeDescriptor.asJsonCode()).isEqualTo(expectedJson)
    assertThat(
      TypeDescriptor.Companion.parseFromJsonCode(expectedJson).asJsonCode(),
    ).isEqualTo(expectedJson)
  }

  @Test
  def testGeneratedStructRecursive(): Unit = {
    val rec = skirout.structs.RecA.partial(
      a = skirout.structs.RecA.partial(
        b = skirout.structs.RecB.partial(),
      ),
    )
    assertThat(rec).isEqualTo(
      skirout.structs.RecA.partial(
        a = skirout.structs.RecA.partial(
          b = skirout.structs.RecB.partial(),
        ),
      ),
    )
    assertThat(rec.toString).isEqualTo("{}")
  }

  @Test
  def testKeyedListWorks(): Unit = {
    val items = skirout.structs.Items.partial(
      arrayWithInt64Key = Seq(
        skirout.structs.Item.partial(int64 = 123L, string = "a123"),
        skirout.structs.Item.partial(int64 = 234L, string = "a234"),
      ).asJava,
    )
    assertThat(
      skirout.structs.Items
        .partial(arrayWithInt64Key = items.arrayWithInt64Key)
        .arrayWithInt64Key,
    ).isSameInstanceAs(items.arrayWithInt64Key)
    assertThat(items.arrayWithInt64Key.findByKey(123L)).isEqualTo(
      skirout.structs.Item.partial(int64 = 123L, string = "a123"),
    )
    assertThat(items.arrayWithInt64Key.findByKey(345L)).isNull()
  }

  @Test
  def testKeyedListCopy(): Unit = {
    val items = skirout.structs.Items.partial(
      arrayWithStringKey = Seq(
        skirout.structs.Item.partial(string = "a123", otherString = "b123"),
      ).asJava,
      arrayWithOtherStringKey = Seq(
        skirout.structs.Item.partial(string = "a234", otherString = "b234"),
      ).asJava,
    )

    val firstCopy = skirout.structs.Items.partial(
      arrayWithStringKey = items.arrayWithStringKey,
      arrayWithOtherStringKey = items.arrayWithOtherStringKey,
    )
    assertThat(firstCopy.arrayWithStringKey).isSameInstanceAs(
      items.arrayWithStringKey,
    )
    assertThat(firstCopy.arrayWithOtherStringKey).isSameInstanceAs(
      items.arrayWithOtherStringKey,
    )

    val secondCopy = skirout.structs.Items.partial(
      arrayWithStringKey = items.arrayWithOtherStringKey,
      arrayWithOtherStringKey = items.arrayWithStringKey,
    )
    assertThat(secondCopy.arrayWithStringKey).isNotSameInstanceAs(
      items.arrayWithOtherStringKey,
    )
    assertThat(secondCopy.arrayWithOtherStringKey).isNotSameInstanceAs(
      items.arrayWithStringKey,
    )
  }

  @Test
  def testGeneratedEnumObtainingInstances(): Unit = {
    assertThat(skirout.enums.Status.UNKNOWN)
      .isInstanceOf(classOf[skirout.enums.Status])
    assertThat(skirout.enums.Status.OK)
      .isInstanceOf(classOf[skirout.enums.Status])
    assertThat(
      skirout.enums.Status.ErrorWrapper(
        skirout.enums.Status.Error(code = 100, message = "The Message"),
      ),
    ).isInstanceOf(classOf[skirout.enums.Status])
    assertThat(
      skirout.enums.Status.createError(code = 100, message = "The Message"),
    ).isInstanceOf(classOf[skirout.enums.Status])
  }

  @Test
  def testGeneratedEnumEqualsAndHashCode(): Unit = {
    val set = scala.collection.mutable.Set[skirout.enums.Status]()
    set.add(skirout.enums.Status.OK)
    set.add(skirout.enums.Status.OK)
    set.add(skirout.enums.Status.UNKNOWN)
    set.add(skirout.enums.Status.UNKNOWN)
    set.add(
      skirout.enums.Status.ErrorWrapper(
        skirout.enums.Status.Error(code = 100, message = "The Message"),
      ),
    )
    set.add(
      skirout.enums.Status.ErrorWrapper(
        skirout.enums.Status.Error(code = 100, message = "The Message"),
      ),
    )
    set.add(
      skirout.enums.Status.ErrorWrapper(
        skirout.enums.Status.Error(code = 101, message = "The Other Message"),
      ),
    )
    assertThat(set.size).isEqualTo(4)
  }

  @Test
  def testGeneratedEnumPatternMatching(): Unit = {
    val status: skirout.enums.Status =
      skirout.enums.Status.createError(code = 100, message = "The Message")
    val matchedCode = status match {
      case _: skirout.enums.Status.Unknown          => -1
      case skirout.enums.Status.OK                  => 0
      case skirout.enums.Status.ErrorWrapper(error) => error.code
    }
    assertThat(matchedCode).isEqualTo(100)
  }

  @Test
  def testGeneratedEnumReflection(): Unit = {
    val typeDescriptor: EnumDescriptor.Reflective[skirout.enums.Status] =
      skirout.enums.Status.typeDescriptor
    assertThat(typeDescriptor.getName).isEqualTo("Status")
    assertThat(typeDescriptor.getQualifiedName).isEqualTo("Status")
    assertThat(typeDescriptor.getModulePath).isEqualTo("enums.skir")
    assertThat(typeDescriptor.getVariants).hasSize(2)
    assertThat(typeDescriptor.getRemovedNumbers).isEqualTo(
      Set(
        java.lang.Integer.valueOf(2),
        java.lang.Integer.valueOf(3),
      ).asJava,
    )
    {
      val variant = typeDescriptor
        .getVariant("error")
        .asInstanceOf[EnumWrapperVariant.Reflective[
          skirout.enums.Status,
          skirout.enums.Status.Error,
        ]]
      assertThat(variant).isNotNull()
      assertThat(variant.getName).isEqualTo("error")
      assertThat(variant.getNumber).isEqualTo(4)
      assertThat(
        variant.test(
          skirout.enums.Status.createError(code = 100, message = "The Message"),
        ),
      ).isEqualTo(true)
      assertThat(variant.test(skirout.enums.Status.OK)).isEqualTo(false)
      assertThat(
        variant.get(
          skirout.enums.Status.createError(code = 100, message = "The Message"),
        ),
      ).isEqualTo(
        skirout.enums.Status.Error(code = 100, message = "The Message"),
      )
      assertThat(
        variant.wrap(
          skirout.enums.Status.Error(code = 100, message = "The Message"),
        ),
      ).isEqualTo(
        skirout.enums.Status.createError(code = 100, message = "The Message"),
      )
    }
    {
      val field = typeDescriptor
        .getVariant("OK")
        .asInstanceOf[EnumConstantVariant.Reflective[skirout.enums.Status]]
      assertThat(field).isNotNull()
      assertThat(field.getName).isEqualTo("ok")
      assertThat(field.getNumber).isEqualTo(1)
      assertThat(field.getConstant).isEqualTo(skirout.enums.Status.OK)
    }
  }

  @Test
  def testGeneratedStructSerializeAndDeserialize(): Unit = {
    val triangle = skirout.structs.Triangle(
      color = skirout.structs.Color(r = 127, g = 128, b = 139),
      points = Seq(new skirout.structs.Point.Mutable(x = 1, y = 2)).asJava,
    )
    val serializer = skirout.structs.Triangle.serializer
    assertThat(serializer.toJsonCode(triangle))
      .isEqualTo("[[127,128,139],[[1,2]]]")
    assertThat(serializer.fromJson(serializer.toJson(triangle)))
      .isEqualTo(triangle)
    assertThat(serializer.fromBytes(serializer.toBytes(triangle)))
      .isEqualTo(triangle)
  }

  @Test
  def testGeneratedStructSerializeAndDeserializeRecursive(): Unit = {
    val rec = skirout.structs.RecA.partial(
      a = skirout.structs.RecA.partial(
        b = skirout.structs.RecB.partial(
          a = skirout.structs.RecA.partial(c = true),
        ),
      ),
    )
    val serializer = skirout.structs.RecA.serializer
    assertThat(serializer.toJsonCode(rec)).isEqualTo("[[[],[[[],[],1]]]]")
    assertThat(serializer.fromJson(serializer.toJson(rec))).isEqualTo(rec)
    assertThat(serializer.fromBytes(serializer.toBytes(rec))).isEqualTo(rec)
  }

  @Test
  def testGeneratedEnumSerializeAndDeserialize(): Unit = {
    val status =
      skirout.enums.Status.createError(code = 100, message = "The Message")
    val serializer = skirout.enums.Status.serializer
    assertThat(serializer.toJsonCode(status))
      .isEqualTo("[4,[100,\"The Message\"]]")
    assertThat(serializer.fromJson(serializer.toJson(status))).isEqualTo(status)
    assertThat(serializer.fromBytes(serializer.toBytes(status)))
      .isEqualTo(status)
    assertThat(
      serializer.fromBytes(serializer.toBytes(skirout.enums.Status.OK)),
    ).isEqualTo(skirout.enums.Status.OK)
    assertThat(
      serializer.fromBytes(serializer.toBytes(skirout.enums.Status.UNKNOWN)),
    ).isEqualTo(skirout.enums.Status.UNKNOWN)
  }

  @Test
  def testGeneratedStructUnrecognizedFieldsJson(): Unit = {
    val fooAfter = skirout.schema_change.FooAfter.partial(
      n = 42,
      bit = true,
      bars = Seq(
        skirout.schema_change.BarAfter.partial(x = 1.0F, s = "bar1"),
        skirout.schema_change.BarAfter.partial(x = 2.0F, s = "bar2"),
      ).asJava,
      enums = Seq(
        skirout.schema_change.EnumAfter.A,
        skirout.schema_change.EnumAfter.CWrapper("foo"),
        skirout.schema_change.EnumAfter.D,
      ).asJava,
    )
    val fooAfterSerializer = skirout.schema_change.FooAfter.serializer
    val fooBeforeSerializer = skirout.schema_change.FooBefore.serializer
    val jsonCode = fooAfterSerializer.toJsonCode(fooAfter)
    assertThat(jsonCode)
      .isEqualTo("[[[1.0,0,0,\"bar1\"],[2.0,0,0,\"bar2\"]],42,[1,[5,\"foo\"],6],1]")
    assertThat(
      fooBeforeSerializer.toJsonCode(
        fooBeforeSerializer.fromJsonCode(
          jsonCode,
          UnrecognizedValuesPolicy.KEEP,
        ),
      ),
    ).isEqualTo(jsonCode)
    assertThat(
      fooBeforeSerializer.toJsonCode(
        fooBeforeSerializer.fromJsonCode(jsonCode),
      ),
    ).isEqualTo("[[[1.0],[2.0]],42,[1,0,0]]")
  }

  @Test
  def testGeneratedStructUnrecognizedFieldsBytes(): Unit = {
    val fooAfter = skirout.schema_change.FooAfter.partial(
      n = 42,
      bit = true,
      bars = Seq(
        skirout.schema_change.BarAfter.partial(x = 1.0F, s = "bar1"),
        skirout.schema_change.BarAfter.partial(x = 2.0F, s = "bar2"),
      ).asJava,
      enums = Seq(
        skirout.schema_change.EnumAfter.A,
        skirout.schema_change.EnumAfter.CWrapper("foo"),
        skirout.schema_change.EnumAfter.D,
      ).asJava,
    )
    val fooAfterSerializer = skirout.schema_change.FooAfter.serializer
    val fooBeforeSerializer = skirout.schema_change.FooBefore.serializer
    val bytes = fooAfterSerializer.toBytes(fooAfter)
    assertThat(fooAfterSerializer.fromBytes(bytes)).isEqualTo(fooAfter)
    assertThat(bytes.hex()).isEqualTo(
      "736b6972fa04f8fa04f00000803f0000f30462617231fa04f0000000400000f304626172322af901f805f303666f6f0601",
    )
    assertThat(
      fooBeforeSerializer.toBytes(
        fooBeforeSerializer.fromBytes(bytes, UnrecognizedValuesPolicy.KEEP),
      ),
    ).isEqualTo(bytes)
    assertThat(
      fooBeforeSerializer.toBytes(fooBeforeSerializer.fromBytes(bytes)),
    ).isEqualTo(
      fooBeforeSerializer.toBytes(
        skirout.schema_change.FooBefore.partial(
          bars = Seq(
            skirout.schema_change.BarBefore.partial(x = 1.0F),
            skirout.schema_change.BarBefore.partial(x = 2.0F),
          ).asJava,
          n = 42,
          enums = Seq(
            skirout.schema_change.EnumBefore.A,
            skirout.schema_change.EnumBefore.UNKNOWN,
            skirout.schema_change.EnumBefore.UNKNOWN,
          ).asJava,
        ),
      ),
    )
  }

  @Test
  def testGeneratedStructHonorRemovedFieldsJson(): Unit = {
    val fooBefore = skirout.schema_change.FooBefore.partial(
      bars = Seq(skirout.schema_change.BarBefore.partial(y = true)).asJava,
      enums = Seq(
        skirout.schema_change.EnumBefore.B,
        skirout.schema_change.EnumBefore.CWrapper("foo"),
      ).asJava,
    )
    val fooBeforeSerializer = skirout.schema_change.FooBefore.serializer
    val fooAfterSerializer = skirout.schema_change.FooAfter.serializer
    val jsonCode = fooBeforeSerializer.toJsonCode(fooBefore)
    assertThat(jsonCode).isEqualTo("[[[0.0,0,1]],0,[3,[4,\"foo\"]]]")

    val fooAfter =
      fooAfterSerializer.fromJsonCode(jsonCode, UnrecognizedValuesPolicy.KEEP)
    assertThat(fooAfterSerializer.toJsonCode(fooAfter))
      .isEqualTo("[[[]],0,[0,0]]")
  }

  @Test
  def testGeneratedStructHonorRemovedFieldsBytes(): Unit = {
    val fooBefore = skirout.schema_change.FooBefore.partial(
      bars = Seq(skirout.schema_change.BarBefore.partial(y = true)).asJava,
      enums = Seq(
        skirout.schema_change.EnumBefore.B,
        skirout.schema_change.EnumBefore.CWrapper("foo"),
      ).asJava,
    )
    val fooBeforeSerializer = skirout.schema_change.FooBefore.serializer
    val fooAfterSerializer = skirout.schema_change.FooAfter.serializer
    val bytes = fooBeforeSerializer.toBytes(fooBefore)
    assertThat(bytes.hex())
      .isEqualTo("736b6972f9f7f900000100f803fef303666f6f")

    val fooAfter =
      fooAfterSerializer.fromBytes(bytes, UnrecognizedValuesPolicy.KEEP)
    assertThat(fooAfterSerializer.toBytes(fooAfter).hex())
      .isEqualTo("736b6972f9f7f600f80000")
  }

  @Test
  def testGeneratedConstant(): Unit = {
    assertThat(skirout.constants.ONE_SINGLE_QUOTED_STRING).isEqualTo("\"Foo\"")
    assertThat(skirout.constants.ONE_CONSTANT).isEqualTo(
      skirout.enums.JsonValue.ArrayWrapper(
        Seq(
          skirout.enums.JsonValue.BooleanWrapper(true),
          skirout.enums.JsonValue.NumberWrapper(3.14),
          skirout.enums.JsonValue.StringWrapper(
            "\n" +
              "        foo\n" +
              "        bar",
          ),
          skirout.enums.JsonValue.ObjectWrapper(
            Seq(
              skirout.enums.JsonValue.Pair(
                name = "foo",
                value = skirout.enums.JsonValue.NULL,
              ),
            ).asJava,
          ),
        ).asJava,
      ),
    )
    assertThat(skirout.constants.INFINITY).isEqualTo(Float.PositiveInfinity)
    assertThat(skirout.constants.NEGATIVE_INFINITY)
      .isEqualTo(Float.NegativeInfinity)
    assertThat(skirout.constants.NAN.isNaN).isEqualTo(true)
    assertThat(skirout.constants.LARGE_INT64).isEqualTo(9223372036854775807L)
    assertThat(skirout.constants.LARGE_HASH64).isEqualTo(-1L)
    assertThat(skirout.constants.PI).isEqualTo(3.141592653589793)
  }

  @Test
  def testGeneratedMethods(): Unit = {
    assertThat(skirout.methods.WithExplicitNumber.number()).isEqualTo(3L)
  }
}
