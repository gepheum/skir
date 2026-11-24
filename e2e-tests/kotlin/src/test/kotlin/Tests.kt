package build.skir

import build.skir.reflection.ArrayDescriptor
import build.skir.reflection.EnumConstantVariant
import build.skir.reflection.EnumDescriptor
import build.skir.reflection.EnumWrapperVariant
import build.skir.reflection.OptionalDescriptor
import build.skir.reflection.PrimitiveDescriptor
import build.skir.reflection.RecordDescriptor
import build.skir.reflection.StructDescriptor
import build.skir.reflection.TypeDescriptor
import build.skir.service.Service
import com.google.common.truth.Truth.assertThat
import org.junit.jupiter.api.Test
import java.net.http.HttpHeaders
import java.time.Instant

class Tests {
    @Test
    fun `test generated struct - toString()`() {
        assertThat(
            skirout.full_name.FullName(
                firstName = "John",
                lastName = "Doe",
            ).toString(),
        ).isEqualTo(
            "FullName(\n" +
                "  firstName = \"John\",\n" +
                "  lastName = \"Doe\",\n" +
                ")",
        )
        assertThat(
            skirout.full_name.FullName(
                firstName = "John",
                lastName = "",
            ).toString(),
        ).isEqualTo(
            "FullName.partial(\n" +
                "  firstName = \"John\",\n" +
                ")",
        )
        assertThat(
            skirout.full_name.FullName.partial().toString(),
        ).isEqualTo(
            "FullName.partial()",
        )
        assertThat(
            skirout.structs.Triangle(
                color =
                    skirout.structs.Color(
                        r = 127,
                        g = 128,
                        b = 139,
                    ),
                points =
                    listOf(
                        skirout.structs.Point(x = 0, y = 0),
                        skirout.structs.Point(x = 10, y = 0),
                        skirout.structs.Point(x = 0, y = 20),
                    ),
            ).toString(),
        ).isEqualTo(
            "Triangle(\n" +
                "  color = Color(\n" +
                "    r = 127,\n" +
                "    g = 128,\n" +
                "    b = 139,\n" +
                "  ),\n" +
                "  points = listOf(\n" +
                "    Point.partial(),\n" +
                "    Point.partial(\n" +
                "      x = 10,\n" +
                "    ),\n" +
                "    Point.partial(\n" +
                "      y = 20,\n" +
                "    ),\n" +
                "  ),\n" +
                ")",
        )
    }

    @Test
    fun `test generated struct - equals()`() {
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
    fun `test generated struct - hashCode()`() {
        val set = mutableSetOf<skirout.full_name.FullName>()
        set.add(
            skirout.full_name.FullName(
                firstName = "John",
                lastName = "Doe",
            ),
        )
        set.add(
            skirout.full_name.FullName(
                firstName = "",
                lastName = "Doe",
            ),
        )
        set.add(
            skirout.full_name.FullName(
                firstName = "John",
                lastName = "",
            ),
        )
        set.add(
            skirout.full_name.FullName(
                firstName = "John",
                lastName = "Doe",
            ),
        )
        assertThat(set).hasSize(3)
    }

    @Test
    fun `test generated struct - partial static factory method`() {
        val fullName =
            skirout.full_name.FullName.partial(
                firstName = "John",
            )
        assertThat(fullName.firstName).isEqualTo("John")
        assertThat(fullName.lastName).isEqualTo("")
    }

    @Test
    fun `test generated struct - toMutable()`() {
        val fullName =
            skirout.full_name.FullName(
                firstName = "John",
                lastName = "Doe",
            )
        val mutableFullName = fullName.toMutable()
        mutableFullName.firstName = "Jane"
        assertThat(
            mutableFullName.toFrozen(),
        ).isEqualTo(
            skirout.full_name.FullName(
                firstName = "Jane",
                lastName = "Doe",
            ),
        )
    }

    @Test
    fun `test generated struct - toFrozen() returns this`() {
        val fullName =
            skirout.full_name.FullName(
                firstName = "John",
                lastName = "Doe",
            )
        @Suppress("DEPRECATION")
        assertThat(fullName.toFrozen()).isSameInstanceAs(fullName)
    }

    @Test
    fun `test generated struct - copy()`() {
        val fullName =
            skirout.full_name.FullName(
                firstName = "John",
                lastName = "Doe",
            )
        assertThat(
            fullName.copy(firstName = "Jane"),
        ).isEqualTo(
            skirout.full_name.FullName(
                firstName = "Jane",
                lastName = "Doe",
            ),
        )
        @Suppress("DEPRECATION")
        assertThat(fullName.copy()).isSameInstanceAs(fullName)

        assertThat(
            skirout.structs.Triangle(
                color =
                    skirout.structs.Color(
                        r = 127,
                        g = 128,
                        b = 139,
                    ),
                points =
                    listOf(
                        skirout.structs.Point.Mutable(x = 1, y = 2),
                    ),
            ).copy(
                color =
                    skirout.structs.Color.Mutable(
                        r = 10,
                    ),
            ),
        ).isEqualTo(
            skirout.structs.Triangle(
                color =
                    skirout.structs.Color(
                        r = 10,
                        g = 0,
                        b = 0,
                    ),
                points =
                    listOf(
                        skirout.structs.Point(x = 1, y = 2),
                    ),
            ),
        )
    }

    @Test
    fun `test generated struct - mutable getter`() {
        val triangle =
            skirout.structs.Triangle(
                color =
                    skirout.structs.Color(
                        r = 127,
                        g = 128,
                        b = 139,
                    ),
                points =
                    listOf(
                        skirout.structs.Point(x = 0, y = 0),
                        skirout.structs.Point(x = 10, y = 0),
                        skirout.structs.Point(x = 0, y = 20),
                    ),
            )
        val mutableTriangle = triangle.toMutable()
        assertThat(mutableTriangle.toFrozen().color).isSameInstanceAs(triangle.color)
        assertThat(mutableTriangle.toFrozen().points).isSameInstanceAs(triangle.points)

        mutableTriangle.mutableColor.r = 5
        assertThat(
            mutableTriangle.toFrozen().color,
        ).isEqualTo(
            skirout.structs.Color(
                r = 5,
                g = 128,
                b = 139,
            ),
        )
        assertThat(mutableTriangle.toFrozen().points).isSameInstanceAs(triangle.points)

        mutableTriangle.mutablePoints.add(skirout.structs.Point.Mutable(x = 10, y = 10))
        mutableTriangle.mutablePoints.add(skirout.structs.Point.Mutable(x = 20, y = 20))
        assertThat(
            mutableTriangle.toFrozen().points,
        ).isEqualTo(
            listOf(
                skirout.structs.Point(x = 0, y = 0),
                skirout.structs.Point(x = 10, y = 0),
                skirout.structs.Point(x = 0, y = 20),
                skirout.structs.Point(x = 10, y = 10),
                skirout.structs.Point(x = 20, y = 20),
            ),
        )
    }

    @Test
    fun `test generated struct - _OrMutable sealed interface`() {
        val person: skirout.full_name.FullName_OrMutable =
            skirout.full_name.FullName(
                firstName = "John",
                lastName = "Doe",
            )
        val mutablePerson: skirout.full_name.FullName_OrMutable =
            skirout.full_name.FullName.Mutable(
                firstName = "John",
            )
        assertThat(
            person.toFrozen(),
        ).isSameInstanceAs(
            person,
        )
        mutablePerson.toFrozen()
    }

    @Test
    fun `test generated struct - reflection`() {
        assertThat(
            skirout.structs.Item.User.typeDescriptor.name,
        ).isEqualTo(
            "User",
        )
        assertThat(
            skirout.structs.Item.User.typeDescriptor.qualifiedName,
        ).isEqualTo(
            "Item.User",
        )
        assertThat(
            skirout.structs.Item.typeDescriptor.name,
        ).isEqualTo(
            "Item",
        )
        assertThat(
            skirout.structs.Item.typeDescriptor.qualifiedName,
        ).isEqualTo(
            "Item",
        )
        assertThat(
            skirout.vehicles.car.Car.typeDescriptor.modulePath,
        ).isEqualTo(
            "vehicles/car.skir",
        )

        assertThat(
            skirout.structs.Color.typeDescriptor.removedNumbers,
        ).isEmpty()
        assertThat(
            skirout.structs.FullName.typeDescriptor.removedNumbers,
        ).isEqualTo(
            setOf(1),
        )

        val typeDescriptor = skirout.vehicles.car.Car.typeDescriptor
        assertThat(
            typeDescriptor.fields,
        ).hasSize(4)
        val field = typeDescriptor.getField("purchase_time")
        assertThat(field).isNotNull()
        @Suppress("UNCHECKED_CAST")
        field as build.skir.reflection.StructField.Reflective<
            skirout.vehicles.car.Car,
            skirout.vehicles.car.Car.Mutable,
            Instant,
            >
        val mutable: skirout.vehicles.car.Car.Mutable =
            typeDescriptor.newMutable(null)
        field.set(mutable, Instant.ofEpochMilli(1000))
        assertThat(
            mutable.toFrozen().purchaseTime,
        ).isEqualTo(
            Instant.ofEpochMilli(1000),
        )
        assertThat(
            typeDescriptor.toFrozen(mutable).purchaseTime,
        ).isEqualTo(
            Instant.ofEpochMilli(1000),
        )
        assertThat(
            field.get(mutable.toFrozen()),
        ).isEqualTo(
            Instant.ofEpochMilli(1000),
        )

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
        assertThat(
            typeDescriptor.asJsonCode(),
        ).isEqualTo(expectedJson)
        assertThat(
            TypeDescriptor.parseFromJsonCode(expectedJson).asJsonCode(),
        ).isEqualTo(expectedJson)

        when (field.type) {
            is PrimitiveDescriptor.Reflective<*> -> {}
            is OptionalDescriptor.Reflective<*> -> {}
            is OptionalDescriptor.JavaReflective<*> -> {}
            is ArrayDescriptor.Reflective<*, *> -> {}
            is StructDescriptor.Reflective<*, *> -> {}
            is EnumDescriptor.Reflective<*> -> {}
        }

        when (field.type) {
            is PrimitiveDescriptor.Reflective<*> -> {}
            is OptionalDescriptor.Reflective<*> -> {}
            is OptionalDescriptor.JavaReflective<*> -> {}
            is ArrayDescriptor.Reflective<*, *> -> {}
            is RecordDescriptor.Reflective<*, *> -> {}
        }

        when (TypeDescriptor.parseFromJsonCode(expectedJson)) {
            is PrimitiveDescriptor -> {}
            is OptionalDescriptor -> {}
            is ArrayDescriptor -> {}
            is StructDescriptor -> {}
            is EnumDescriptor -> {}
        }

        when (TypeDescriptor.parseFromJsonCode(expectedJson)) {
            is PrimitiveDescriptor -> {}
            is OptionalDescriptor -> {}
            is ArrayDescriptor -> {}
            is RecordDescriptor<*> -> {}
        }
    }

    @Test
    fun `test generated struct - recursive`() {
        val rec =
            skirout.structs.RecA.partial(
                a =
                    skirout.structs.RecA.partial(
                        b = skirout.structs.RecB.partial(),
                    ),
            )
        assertThat(
            rec,
        ).isEqualTo(
            skirout.structs.RecA.partial(
                a =
                    skirout.structs.RecA.partial(
                        b = skirout.structs.RecB.partial(),
                    ),
            ),
        )
        assertThat(
            rec.toString(),
        ).isEqualTo(
            "RecA.partial()",
        )
    }

    @Test
    fun `test keyed list - works`() {
        val items =
            skirout.structs.Items.partial(
                arrayWithInt64Key =
                    listOf(
                        skirout.structs.Item.partial(
                            int64 = 123,
                            string = "a123",
                        ),
                        skirout.structs.Item.partial(
                            int64 = 234,
                            string = "a234",
                        ),
                    ),
            )
        assertThat(
            skirout.structs.Items.partial(arrayWithInt64Key = items.arrayWithInt64Key).arrayWithInt64Key,
        ).isSameInstanceAs(
            items.arrayWithInt64Key,
        )
        assertThat(
            items.arrayWithInt64Key.mapView[123],
        ).isEqualTo(
            skirout.structs.Item.partial(
                int64 = 123,
                string = "a123",
            ),
        )
        assertThat(
            items.arrayWithInt64Key.mapView[345],
        ).isNull()
    }

    @Test
    fun `test keyed list - copy`() {
        val items =
            skirout.structs.Items.partial(
                arrayWithStringKey =
                    listOf(
                        skirout.structs.Item.partial(
                            string = "a123",
                            otherString = "b123",
                        ),
                    ),
                arrayWithOtherStringKey =
                    listOf(
                        skirout.structs.Item.partial(
                            string = "a234",
                            otherString = "b234",
                        ),
                    ),
            )

        val firstCopy =
            skirout.structs.Items.partial(
                arrayWithStringKey = items.arrayWithStringKey,
                arrayWithOtherStringKey = items.arrayWithOtherStringKey,
            )
        // The lists should *not* have been copied.
        assertThat(firstCopy.arrayWithStringKey).isSameInstanceAs(items.arrayWithStringKey)
        assertThat(firstCopy.arrayWithOtherStringKey).isSameInstanceAs(items.arrayWithOtherStringKey)

        val secondCopy =
            skirout.structs.Items.partial(
                arrayWithStringKey = items.arrayWithOtherStringKey,
                arrayWithOtherStringKey = items.arrayWithStringKey,
            )
        // The lists should have been copied since the keys are different.
        assertThat(secondCopy.arrayWithStringKey).isNotSameInstanceAs(items.arrayWithOtherStringKey)
        assertThat(secondCopy.arrayWithOtherStringKey).isNotSameInstanceAs(items.arrayWithStringKey)
    }

    @Test
    fun `test generated enum - obtaining instances`() {
        assertThat(
            skirout.enums.Status.UNKNOWN,
        ).isInstanceOf(
            skirout.enums.Status::class.java,
        )
        assertThat(
            skirout.enums.Status.OK,
        ).isInstanceOf(
            skirout.enums.Status::class.java,
        )
        assertThat(
            skirout.enums.Status.ErrorWrapper(
                skirout.enums.Status.Error(
                    code = 100,
                    message = "The Message",
                ),
            ),
        ).isInstanceOf(
            skirout.enums.Status::class.java,
        )
        assertThat(
            skirout.enums.Status.createError(
                code = 100,
                message = "The Message",
            ),
        ).isInstanceOf(
            skirout.enums.Status::class.java,
        )
        assertThat(
            skirout.enums.Status.UNKNOWN,
        ).isInstanceOf(
            skirout.enums.Status::class.java,
        )
    }

    @Test
    fun `test generated enum - toString()`() {
        assertThat(
            skirout.enums.Status.OK.toString(),
        ).isEqualTo(
            "Status.OK",
        )
        assertThat(
            skirout.enums.Status.ErrorWrapper(
                skirout.enums.Status.Error(
                    code = 100,
                    message = "The Message",
                ),
            ).toString(),
        ).isEqualTo(
            "Status.ErrorWrapper(\n" +
                "  Status.Error(\n" +
                "    code = 100,\n" +
                "    message = \"The Message\",\n" +
                "  )\n" +
                ")",
        )
        assertThat(
            skirout.enums.Status.createError(
                code = 100,
                message = "The Message",
            ).toString(),
        ).isEqualTo(
            "Status.ErrorWrapper(\n" +
                "  Status.Error(\n" +
                "    code = 100,\n" +
                "    message = \"The Message\",\n" +
                "  )\n" +
                ")",
        )
        assertThat(
            skirout.enums.Status.UNKNOWN.toString(),
        ).isEqualTo(
            "Status.UNKNOWN",
        )
    }

    @Test
    fun `test generated enum - equals() and hashCode`() {
        val set = mutableSetOf<skirout.enums.Status>()
        set.add(skirout.enums.Status.OK)
        set.add(skirout.enums.Status.OK)
        set.add(skirout.enums.Status.UNKNOWN)
        set.add(skirout.enums.Status.UNKNOWN)
        set.add(
            skirout.enums.Status.ErrorWrapper(
                skirout.enums.Status.Error(
                    code = 100,
                    message = "The Message",
                ),
            ),
        )
        set.add(
            skirout.enums.Status.ErrorWrapper(
                skirout.enums.Status.Error(
                    code = 100,
                    message = "The Message",
                ),
            ),
        )
        set.add(
            skirout.enums.Status.ErrorWrapper(
                skirout.enums.Status.Error(
                    code = 101,
                    message = "The Other Message",
                ),
            ),
        )
        assertThat(
            set,
        ).isEqualTo(
            setOf(
                skirout.enums.Status.OK,
                skirout.enums.Status.UNKNOWN,
                skirout.enums.Status.ErrorWrapper(
                    skirout.enums.Status.Error(
                        code = 100,
                        message = "The Message",
                    ),
                ),
                skirout.enums.Status.ErrorWrapper(
                    skirout.enums.Status.Error(
                        code = 101,
                        message = "The Other Message",
                    ),
                ),
            ),
        )
    }

    fun `test generated enum - condition on enum`(status: skirout.enums.Status) {
        when (status) {
            is skirout.enums.Status.Unknown -> {}
            is skirout.enums.Status.OK -> {}
            is skirout.enums.Status.ErrorWrapper -> {}
        }
    }

    @Test
    @Suppress("UNCHECKED_CAST")
    fun `test generated enum - reflection`() {
        val typeDescriptor: EnumDescriptor.Reflective<skirout.enums.Status> =
            skirout.enums.Status.typeDescriptor
        assertThat(
            typeDescriptor.name,
        ).isEqualTo(
            "Status",
        )
        assertThat(
            typeDescriptor.qualifiedName,
        ).isEqualTo(
            "Status",
        )
        assertThat(
            typeDescriptor.modulePath,
        ).isEqualTo(
            "enums.skir",
        )
        assertThat(
            typeDescriptor.variants,
        ).hasSize(
            2,
        )
        assertThat(
            typeDescriptor.removedNumbers,
        ).isEqualTo(
            setOf(2, 3),
        )
        run {
            val variant = typeDescriptor.getVariant("error")!!
            assertThat(
                variant,
            ).isInstanceOf(
                EnumWrapperVariant.Reflective::class.java,
            )
            variant as EnumWrapperVariant.Reflective<skirout.enums.Status, skirout.enums.Status.Error>
            assertThat(
                variant.name,
            ).isEqualTo(
                "error",
            )
            assertThat(
                variant.number,
            ).isEqualTo(
                4,
            )
            assertThat(
                variant.test(
                    skirout.enums.Status.createError(
                        code = 100,
                        message = "The Message",
                    ),
                ),
            ).isTrue()
            assertThat(
                variant.test(
                    skirout.enums.Status.OK,
                ),
            ).isFalse()
            assertThat(
                variant.get(
                    skirout.enums.Status.createError(
                        code = 100,
                        message = "The Message",
                    ),
                ),
            ).isEqualTo(
                skirout.enums.Status.Error(
                    code = 100,
                    message = "The Message",
                ),
            )
            assertThat(
                variant.wrap(
                    skirout.enums.Status.Error(
                        code = 100,
                        message = "The Message",
                    ),
                ),
            ).isEqualTo(
                skirout.enums.Status.createError(
                    code = 100,
                    message = "The Message",
                ),
            )
            assertThat(
                typeDescriptor.getVariant(
                    skirout.enums.Status.createError(
                        code = 100,
                        message = "The Message",
                    ),
                ),
            ).isEqualTo(
                variant,
            )
        }
        run {
            val field = typeDescriptor.getVariant("OK")!!
            assertThat(
                field,
            ).isInstanceOf(
                EnumConstantVariant.Reflective::class.java,
            )
            field as EnumConstantVariant.Reflective<skirout.enums.Status>
            assertThat(
                field.name,
            ).isEqualTo(
                "ok",
            )
            assertThat(
                field.number,
            ).isEqualTo(
                1,
            )
            assertThat(
                field.constant,
            ).isEqualTo(
                skirout.enums.Status.OK,
            )
            assertThat(
                typeDescriptor.getVariant(
                    skirout.enums.Status.OK,
                ),
            ).isEqualTo(
                field,
            )
        }
        run {
            val field = typeDescriptor.getVariant(0)!!
            assertThat(
                field.name,
            ).isEqualTo(
                "unknown",
            )
            assertThat(
                field.number,
            ).isEqualTo(
                0,
            )
            field as EnumConstantVariant.Reflective<skirout.enums.Status>
            assertThat(
                field.constant,
            ).isEqualTo(
                skirout.enums.Status.UNKNOWN,
            )
            assertThat(
                typeDescriptor.getVariant(
                    skirout.enums.Status.UNKNOWN,
                ),
            ).isEqualTo(
                field,
            )
        }
    }

    @Test
    fun `test generated struct - serialize and deserialize`() {
        val triangle =
            skirout.structs.Triangle(
                color =
                    skirout.structs.Color(
                        r = 127,
                        g = 128,
                        b = 139,
                    ),
                points =
                    listOf(
                        skirout.structs.Point.Mutable(x = 1, y = 2),
                    ),
            )
        val serializer = skirout.structs.Triangle.serializer
        assertThat(
            serializer.toJsonCode(triangle),
        ).isEqualTo(
            "[[127,128,139],[[1,2]]]",
        )
        assertThat(
            serializer.fromJson(serializer.toJson(triangle)),
        ).isEqualTo(
            triangle,
        )
        assertThat(
            serializer.fromBytes(serializer.toBytes(triangle)),
        ).isEqualTo(
            triangle,
        )
    }

    @Test
    fun `test generated struct - serialize and deserialize recursive`() {
        val rec =
            skirout.structs.RecA.partial(
                a =
                    skirout.structs.RecA.partial(
                        b =
                            skirout.structs.RecB.partial(
                                a =
                                    skirout.structs.RecA.partial(
                                        c = true,
                                    ),
                            ),
                    ),
            )
        val serializer = skirout.structs.RecA.serializer
        assertThat(
            serializer.toJsonCode(rec),
        ).isEqualTo(
            "[[[],[[[],[],1]]]]",
        )
        assertThat(
            serializer.fromJson(serializer.toJson(rec)),
        ).isEqualTo(
            rec,
        )
        assertThat(
            serializer.fromBytes(serializer.toBytes(rec)),
        ).isEqualTo(
            rec,
        )
    }

    @Test
    fun `test generated enum - serialize and deserialize`() {
        val status =
            skirout.enums.Status.createError(
                code = 100,
                message = "The Message",
            )
        val serializer = skirout.enums.Status.serializer
        assertThat(
            serializer.toJsonCode(status),
        ).isEqualTo(
            "[4,[100,\"The Message\"]]",
        )
        assertThat(
            serializer.fromJson(serializer.toJson(status)),
        ).isEqualTo(
            status,
        )
        assertThat(
            serializer.fromBytes(serializer.toBytes(status)),
        ).isEqualTo(
            status,
        )
        assertThat(
            serializer.fromBytes(serializer.toBytes(skirout.enums.Status.OK)),
        ).isEqualTo(
            skirout.enums.Status.OK,
        )
        assertThat(
            serializer.fromBytes(serializer.toBytes(skirout.enums.Status.UNKNOWN)),
        ).isEqualTo(
            skirout.enums.Status.UNKNOWN,
        )
    }

    @Test
    fun `test generated struct - unrecognized fields - JSON`() {
        val fooAfter =
            skirout.schema_change.FooAfter.partial(
                n = 42,
                bit = true,
                bars =
                    listOf(
                        skirout.schema_change.BarAfter.partial(
                            x = 1.0F,
                            s = "bar1",
                        ),
                        skirout.schema_change.BarAfter.partial(
                            x = 2.0F,
                            s = "bar2",
                        ),
                    ),
                enums =
                    listOf(
                        skirout.schema_change.EnumAfter.A,
                        skirout.schema_change.EnumAfter.CWrapper("foo"),
                        skirout.schema_change.EnumAfter.D,
                    ),
            )
        val fooAfterSerializer = skirout.schema_change.FooAfter.serializer
        val fooBeforeSerializer = skirout.schema_change.FooBefore.serializer
        val jsonCode = fooAfterSerializer.toJsonCode(fooAfter)
        assertThat(jsonCode).isEqualTo("[[[1.0,0,0,\"bar1\"],[2.0,0,0,\"bar2\"]],42,[1,[5,\"foo\"],6],1]")
        assertThat(
            fooBeforeSerializer.toJsonCode(
                fooBeforeSerializer.fromJsonCode(
                    jsonCode,
                    UnrecognizedValuesPolicy.KEEP,
                ),
            ),
        ).isEqualTo(jsonCode)
        // And now without keep-unrecognized-fields
        assertThat(
            fooBeforeSerializer.toJsonCode(
                fooBeforeSerializer.fromJsonCode(
                    jsonCode,
                ),
            ),
        ).isEqualTo("[[[1.0],[2.0]],42,[1,0,0]]")
    }

    @Test
    fun `test generated struct - unrecognized fields - bytes`() {
        val fooAfter =
            skirout.schema_change.FooAfter.partial(
                n = 42,
                bit = true,
                bars =
                    listOf(
                        skirout.schema_change.BarAfter.partial(
                            x = 1.0F,
                            s = "bar1",
                        ),
                        skirout.schema_change.BarAfter.partial(
                            x = 2.0F,
                            s = "bar2",
                        ),
                    ),
                enums =
                    listOf(
                        skirout.schema_change.EnumAfter.A,
                        skirout.schema_change.EnumAfter.CWrapper("foo"),
                        skirout.schema_change.EnumAfter.D,
                    ),
            )
        val fooAfterSerializer = skirout.schema_change.FooAfter.serializer
        val fooBeforeSerializer = skirout.schema_change.FooBefore.serializer
        val bytes = fooAfterSerializer.toBytes(fooAfter)
        assertThat(fooAfterSerializer.fromBytes(bytes)).isEqualTo(fooAfter)
        assertThat(
            bytes.hex(),
        ).isEqualTo("736b6972fa04f8fa04f00000803f0000f30462617231fa04f0000000400000f304626172322af901f805f303666f6f0601")
        assertThat(
            fooBeforeSerializer.toBytes(
                fooBeforeSerializer.fromBytes(
                    bytes,
                    UnrecognizedValuesPolicy.KEEP,
                ),
            ),
        ).isEqualTo(bytes)
        // And now without keep-unrecognized-fields
        assertThat(
            fooBeforeSerializer.toBytes(
                fooBeforeSerializer.fromBytes(
                    bytes,
                ),
            ),
        ).isEqualTo(
            fooBeforeSerializer.toBytes(
                skirout.schema_change.FooBefore.partial(
                    bars =
                        listOf(
                            skirout.schema_change.BarBefore.partial(
                                x = 1.0F,
                            ),
                            skirout.schema_change.BarBefore.partial(
                                x = 2.0F,
                            ),
                        ),
                    n = 42,
                    enums =
                        listOf(
                            skirout.schema_change.EnumBefore.A,
                            skirout.schema_change.EnumBefore.UNKNOWN,
                            skirout.schema_change.EnumBefore.UNKNOWN,
                        ),
                ),
            ),
        )
    }

    @Test
    fun `test generated struct - honor removed fields - JSON`() {
        val fooBefore =
            skirout.schema_change.FooBefore.partial(
                bars = listOf(skirout.schema_change.BarBefore.partial(y = true)),
                enums =
                    listOf(
                        skirout.schema_change.EnumBefore.B,
                        skirout.schema_change.EnumBefore.CWrapper("foo"),
                    ),
            )

        // Serialize FooBefore to JSON
        val fooBeforeSerializer = skirout.schema_change.FooBefore.serializer
        val fooAfterSerializer = skirout.schema_change.FooAfter.serializer
        val jsonCode = fooBeforeSerializer.toJsonCode(fooBefore)
        assertThat(jsonCode).isEqualTo("[[[0.0,0,1]],0,[3,[4,\"foo\"]]]")

        val fooAfter =
            fooAfterSerializer
                .fromJsonCode(jsonCode, UnrecognizedValuesPolicy.KEEP)

        assertThat(fooAfterSerializer.toJsonCode(fooAfter)).isEqualTo("[[[]],0,[0,0]]")
    }

    @Test
    fun `test generated struct - honor removed fields - bytes`() {
        val fooBefore =
            skirout.schema_change.FooBefore.partial(
                bars = listOf(skirout.schema_change.BarBefore.partial(y = true)),
                enums =
                    listOf(
                        skirout.schema_change.EnumBefore.B,
                        skirout.schema_change.EnumBefore.CWrapper("foo"),
                    ),
            )

        // Serialize FooBefore to JSON
        val fooBeforeSerializer = skirout.schema_change.FooBefore.serializer
        val fooAfterSerializer = skirout.schema_change.FooAfter.serializer
        val bytes = fooBeforeSerializer.toBytes(fooBefore)
        assertThat(bytes.hex()).isEqualTo("736b6972f9f7f900000100f803fef303666f6f")

        val fooAfter =
            fooAfterSerializer
                .fromBytes(bytes, UnrecognizedValuesPolicy.KEEP)

        assertThat(fooAfterSerializer.toBytes(fooAfter).hex()).isEqualTo("736b6972f9f7f600f80000")
    }

    @Test
    fun `test generated constant`() {
        assertThat(
            skirout.constants.ONE_SINGLE_QUOTED_STRING,
        ).isEqualTo(
            "\"Foo\"",
        )
        assertThat(
            skirout.constants.ONE_CONSTANT,
        ).isEqualTo(
            skirout.enums.JsonValue.ArrayWrapper(
                listOf(
                    skirout.enums.JsonValue.BooleanWrapper(
                        true,
                    ),
                    skirout.enums.JsonValue.NumberWrapper(
                        3.14,
                    ),
                    skirout.enums.JsonValue.StringWrapper(
                        "\n" +
                            "        foo\n" +
                            "        bar",
                    ),
                    skirout.enums.JsonValue.ObjectWrapper(
                        listOf(
                            skirout.enums.JsonValue.Pair(
                                name = "foo",
                                value = skirout.enums.JsonValue.NULL,
                            ),
                        ),
                    ),
                ),
            ),
        )
        assertThat(skirout.constants.INFINITY).isEqualTo(Float.POSITIVE_INFINITY)
        assertThat(skirout.constants.NEGATIVE_INFINITY).isEqualTo(Float.NEGATIVE_INFINITY)
        assertThat(skirout.constants.NAN).isEqualTo(Double.NaN)
        assertThat(skirout.constants.LARGE_INT64).isEqualTo(9223372036854775807)
        assertThat(skirout.constants.PI).isEqualTo(3.141592653589793)
    }

    @Test
    fun `test generated methods`() {
        assertThat(
            skirout.methods.WithExplicitNumber.number,
        ).isEqualTo(
            3,
        )
    }
}

class ServiceImpl {
    private fun myProcedure(
        point: skirout.structs.Point,
        requestHeaders: HttpHeaders,
    ): skirout.enums.JsonValue {
        return skirout.enums.JsonValue.StringWrapper("FOO x:${point.x}")
    }

    val service by lazy {
        Service.Builder<HttpHeaders>()
            .addMethod(skirout.methods.MyProcedure) { req, reqMeta -> myProcedure(req, reqMeta) }
            .build()
    }
}

const val INFINITY = skirout.constants.INFINITY
const val NEGATIVE_INFINITY = skirout.constants.NEGATIVE_INFINITY
const val NAN = skirout.constants.NAN
const val LARGE_INT64 = skirout.constants.LARGE_INT64
const val PI = skirout.constants.PI
const val ONE_BOOL = skirout.constants.ONE_BOOL
const val ONE_SINGLE_QUOTED_STRING = skirout.constants.ONE_SINGLE_QUOTED_STRING
