module SkiroutTests

open System.Collections.Immutable

let assertTrue cond msg =
    if not cond then
        failwithf "Assertion failed: %s" msg

let testFullName () =
    let fn = Skirout_FullName.FullName.Create(firstName = "Tyler", lastName = "Fibonacci")
    assertTrue (fn.FirstName = "Tyler") "FirstName"
    assertTrue (fn.LastName = "Fibonacci") "LastName"
    assertTrue
        (Skirout_FullName.FullName.Serializer.ToJson(fn) = "[\"Tyler\",\"Fibonacci\"]")
        "FullName ToJson"

    let partialFn = Skirout_FullName.FullName.Create(firstName = "Tyler")
    assertTrue (partialFn.FirstName = "Tyler") "partial FirstName"
    assertTrue (partialFn.LastName = "") "partial LastName"
    assertTrue
        (Skirout_FullName.FullName.Serializer.ToJson(partialFn) = "[\"Tyler\"]")
        "partial FullName ToJson"

    let replaced = { fn with LastName = "Smith" }
    assertTrue (replaced.FirstName = "Tyler") "replaced FirstName"
    assertTrue (replaced.LastName = "Smith") "replaced LastName"

let testEnumsAndPatternMatching () =
    let describe (v: Skirout_Enums.EnumWithStructField) : string =
        match v with
        | Skirout_Enums.EnumWithStructField.Unknown _ -> "unknown"
        | Skirout_Enums.EnumWithStructField.S s -> sprintf "s:%g,%g" s.X s.Y

    assertTrue (describe Skirout_Enums.EnumWithStructField.UnknownDefault = "unknown") "describe unknown"
    let sInst =
        Skirout_Enums.EnumWithStructField.S(
            Skirout_Enums.EnumWithStructField_S.Create(x = 1.5f, y = 2.5f)
        )
    assertTrue (describe sInst = "s:1.5,2.5") "describe sInst"

    let empty = Skirout_Enums.EmptyEnum.Serializer.FromJson("\"UNKNOWN\"")
    assertTrue (empty = Skirout_Enums.EmptyEnum.UnknownDefault) "EmptyEnum unknown equality"

let testKeyedArrays () =
    let item1 =
        Skirout_Structs.Item.Create(
            weekday = Skirout_Enums.Weekday.Monday,
            bool = true,
            int32 = 10,
            string = "a"
        )
    let item2 =
        Skirout_Structs.Item.Create(
            weekday = Skirout_Enums.Weekday.Tuesday,
            bool = false,
            int32 = 20,
            string = "b"
        )
    let items =
        Skirout_Structs.Items.Create(
            arrayWithEnumKey = ImmutableArray.Create(item1, item2),
            arrayWithInt32Key = ImmutableArray.Create(item1, item2),
            arrayWithStringKey = ImmutableArray.Create(item1, item2)
        )
    assertTrue
        (items.ArrayWithEnumKey_FindByWeekdayKind(Skirout_Enums.Weekday_Kind.Tuesday) = Some item2)
        "FindByWeekdayKind found"
    assertTrue
        (items.ArrayWithEnumKey_FindByWeekdayKind(Skirout_Enums.Weekday_Kind.Wednesday) = None)
        "FindByWeekdayKind not found"
    assertTrue
        (items.ArrayWithInt32Key_FindByInt32(20) = Some item2)
        "FindByInt32 found"
    assertTrue
        (items.ArrayWithInt32Key_FindByInt32OrDefault(999) = Skirout_Structs.Item.Default)
        "FindByInt32OrDefault"
    assertTrue
        (items.ArrayWithStringKey_FindByString("a") = Some item1)
        "FindByString found"

let testConstantsAndMethods () =
    let expected =
        Skirout_Enums.JsonValue.Array(
            ImmutableArray.Create(
                Skirout_Enums.JsonValue.Boolean true,
                Skirout_Enums.JsonValue.Number 2.5,
                Skirout_Enums.JsonValue.String "\n        foo\n        bar",
                Skirout_Enums.JsonValue.Object(
                    ImmutableArray.Create(
                        Skirout_Enums.JsonValue_Pair.Create(
                            name = "foo",
                            value = Skirout_Enums.JsonValue.Null
                        )
                    )
                )
            )
        )
    assertTrue (Skirout_Constants.Consts.OneConstant = expected) "OneConstant structural equality"
    assertTrue (Skirout_Methods.Methods.MyProcedure.Name = "MyProcedure") "MyProcedure Name"
    assertTrue (Skirout_Methods.Methods.MyProcedure.Doc = "My procedure") "MyProcedure Doc"

let testExternal () =
    let qc = Skirout_QuestCollection.QuestCollection.Default
    let q = Skirout_External_Gepheum_SkirFantasyGameExample_FantasyGame.Quest.Default
    assertTrue (qc.CollectionName = "") "QuestCollection default"
    assertTrue (q.QuestId = 0) "Quest default"

let run () =
    testFullName ()
    testEnumsAndPatternMatching ()
    testKeyedArrays ()
    testConstantsAndMethods ()
    testExternal ()
    printfn "All F# skirout E2E tests passed!"
