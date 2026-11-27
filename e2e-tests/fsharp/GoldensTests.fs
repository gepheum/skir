module GoldensTests

open System
open System.Collections.Immutable
open System.Linq
open SkirClient
open Skirout_External_Gepheum_SkirGoldenTests_Goldens

exception GoldenAssertionException of string

let fail (msg: string) = raise (GoldenAssertionException msg)

let toHex (bytes: byte[]) : string =
    BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant()

[<AbstractClass>]
type EvaluatedValue() =
    abstract member ToBytes: unit -> byte[]
    abstract member ToDenseJson: unit -> string
    abstract member ToReadableJson: unit -> string
    abstract member TypeDescriptorJson: unit -> string
    abstract member FromJsonKeepUnrecognized: string -> EvaluatedValue
    abstract member FromJsonDropUnrecognized: string -> EvaluatedValue
    abstract member FromBytesDropUnrecognized: byte[] -> EvaluatedValue

type EvaluatedValue<'T>(value: 'T, serializer: Serializer<'T>) =
    inherit EvaluatedValue()
    override _.ToBytes() = serializer.ToBytes(value)
    override _.ToDenseJson() = serializer.ToJson(value)
    override _.ToReadableJson() = serializer.ToJson(value, readable = true)
    override _.TypeDescriptorJson() = serializer.TypeDescriptor.AsJson()
    override _.FromJsonKeepUnrecognized(json: string) =
        let v = serializer.FromJson(json, keepUnrecognizedValues = true)
        EvaluatedValue<'T>(v, serializer) :> EvaluatedValue
    override _.FromJsonDropUnrecognized(json: string) =
        let v = serializer.FromJson(json, keepUnrecognizedValues = false)
        EvaluatedValue<'T>(v, serializer) :> EvaluatedValue
    override _.FromBytesDropUnrecognized(bytes: byte[]) =
        let v = serializer.FromBytes(bytes, keepUnrecognizedValues = false)
        EvaluatedValue<'T>(v, serializer) :> EvaluatedValue

let ev (value: 'T) (serializer: Serializer<'T>) : EvaluatedValue =
    EvaluatedValue<'T>(value, serializer) :> EvaluatedValue

let boolOptionalSerializer : Serializer<option<bool>> =
    Serializers.OptionalCustom<bool, option<bool>>(
        Serializers.Bool,
        None,
        Func<bool, option<bool>>(Some),
        Func<option<bool>, bool>(Option.isNone),
        Func<option<bool>, bool>(Option.get)
    )

let rec evaluateBytes (expr: BytesExpression) : byte[] =
    match expr with
    | BytesExpression.Literal b -> b.ToArray()
    | BytesExpression.ToBytes tv -> (evaluateTypedValue tv).ToBytes()
    | BytesExpression.Unknown _ -> fail "unknown BytesExpression variant"

and evaluateString (expr: StringExpression) : string =
    match expr with
    | StringExpression.Literal s -> s
    | StringExpression.ToDenseJson tv -> (evaluateTypedValue tv).ToDenseJson()
    | StringExpression.ToReadableJson tv -> (evaluateTypedValue tv).ToReadableJson()
    | StringExpression.Unknown _ -> fail "unknown StringExpression variant"

and evaluateTypedValue (tv: TypedValue) : EvaluatedValue =
    match tv with
    | TypedValue.Bool v -> ev v Serializers.Bool
    | TypedValue.Int32 v -> ev v Serializers.Int32
    | TypedValue.Int64 v -> ev v Serializers.Int64
    | TypedValue.Hash64 v -> ev v Serializers.Hash64
    | TypedValue.Float32 v -> ev v Serializers.Float32
    | TypedValue.Float64 v -> ev v Serializers.Float64
    | TypedValue.Timestamp v -> ev v Serializers.Timestamp
    | TypedValue.String v -> ev v Serializers.String
    | TypedValue.Bytes v -> ev v Serializers.Bytes
    | TypedValue.BoolOptional v -> ev v boolOptionalSerializer
    | TypedValue.Ints v -> ev v (Serializers.Array(Serializers.Int32))
    | TypedValue.Point v -> ev v Point.Serializer
    | TypedValue.Color v -> ev v Color.Serializer
    | TypedValue.MyEnum v -> ev v MyEnum.Serializer
    | TypedValue.EnumA v -> ev v EnumA.Serializer
    | TypedValue.EnumB v -> ev v EnumB.Serializer
    | TypedValue.KeyedArrays v -> ev v KeyedArrays.Serializer
    | TypedValue.RecStruct v -> ev v RecStruct.Serializer
    | TypedValue.RecEnum v -> ev v RecEnum.Serializer
    | TypedValue.RoundTripDenseJson inner ->
        let e = evaluateTypedValue inner
        e.FromJsonDropUnrecognized(e.ToDenseJson())
    | TypedValue.RoundTripReadableJson inner ->
        let e = evaluateTypedValue inner
        e.FromJsonDropUnrecognized(e.ToReadableJson())
    | TypedValue.RoundTripBytes inner ->
        let e = evaluateTypedValue inner
        e.FromBytesDropUnrecognized(e.ToBytes())
    | TypedValue.PointFromJsonKeepUnrecognized expr ->
        ev (Point.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = true)) Point.Serializer
    | TypedValue.PointFromJsonDropUnrecognized expr ->
        ev (Point.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = false)) Point.Serializer
    | TypedValue.PointFromBytesKeepUnrecognized expr ->
        ev (Point.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = true)) Point.Serializer
    | TypedValue.PointFromBytesDropUnrecognized expr ->
        ev (Point.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = false)) Point.Serializer
    | TypedValue.ColorFromJsonKeepUnrecognized expr ->
        ev (Color.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = true)) Color.Serializer
    | TypedValue.ColorFromJsonDropUnrecognized expr ->
        ev (Color.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = false)) Color.Serializer
    | TypedValue.ColorFromBytesKeepUnrecognized expr ->
        ev (Color.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = true)) Color.Serializer
    | TypedValue.ColorFromBytesDropUnrecognized expr ->
        ev (Color.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = false)) Color.Serializer
    | TypedValue.MyEnumFromJsonKeepUnrecognized expr ->
        ev (MyEnum.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = true)) MyEnum.Serializer
    | TypedValue.MyEnumFromJsonDropUnrecognized expr ->
        ev (MyEnum.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = false)) MyEnum.Serializer
    | TypedValue.MyEnumFromBytesKeepUnrecognized expr ->
        ev (MyEnum.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = true)) MyEnum.Serializer
    | TypedValue.MyEnumFromBytesDropUnrecognized expr ->
        ev (MyEnum.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = false)) MyEnum.Serializer
    | TypedValue.EnumAFromJsonKeepUnrecognized expr ->
        ev (EnumA.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = true)) EnumA.Serializer
    | TypedValue.EnumAFromJsonDropUnrecognized expr ->
        ev (EnumA.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = false)) EnumA.Serializer
    | TypedValue.EnumAFromBytesKeepUnrecognized expr ->
        ev (EnumA.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = true)) EnumA.Serializer
    | TypedValue.EnumAFromBytesDropUnrecognized expr ->
        ev (EnumA.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = false)) EnumA.Serializer
    | TypedValue.EnumBFromJsonKeepUnrecognized expr ->
        ev (EnumB.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = true)) EnumB.Serializer
    | TypedValue.EnumBFromJsonDropUnrecognized expr ->
        ev (EnumB.Serializer.FromJson(evaluateString expr, keepUnrecognizedValues = false)) EnumB.Serializer
    | TypedValue.EnumBFromBytesKeepUnrecognized expr ->
        ev (EnumB.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = true)) EnumB.Serializer
    | TypedValue.EnumBFromBytesDropUnrecognized expr ->
        ev (EnumB.Serializer.FromBytes(evaluateBytes expr, keepUnrecognizedValues = false)) EnumB.Serializer
    | TypedValue.Unknown _ -> fail "unknown TypedValue variant"

let verifyReserializeValue (input: Assertion_ReserializeValue) : unit =
    let allValues =
        [
            input.Value
            TypedValue.RoundTripDenseJson input.Value
            TypedValue.RoundTripReadableJson input.Value
            TypedValue.RoundTripBytes input.Value
        ]

    for inputTv in allValues do
        let evaluated = evaluateTypedValue inputTv
        let actualBytes = evaluated.ToBytes()
        let foundBytes = input.ExpectedBytes.Any(fun exp -> exp.Span.SequenceEqual(actualBytes))
        if not foundBytes then
            fail (sprintf "bytes not in expected set: actual hex:%s" (toHex actualBytes))

        let denseJson = evaluated.ToDenseJson()
        if not (input.ExpectedDenseJson.Contains(denseJson)) then
            fail (sprintf "dense JSON not in expected set: actual %s" denseJson)

        let readableJson = evaluated.ToReadableJson()
        if not (input.ExpectedReadableJson.Contains(readableJson)) then
            fail (sprintf "readable JSON not in expected set: actual %s" readableJson)

    // Skip-value test
    for expectedBytes in input.ExpectedBytes do
        let expectedByteArray = expectedBytes.ToArray()
        let buf = Array.zeroCreate<byte> (expectedByteArray.Length + 2)
        buf.[0] <- byte 's'
        buf.[1] <- byte 'k'
        buf.[2] <- byte 'i'
        buf.[3] <- byte 'r'
        buf.[4] <- 248uy
        Array.Copy(expectedByteArray, 4, buf, 5, expectedByteArray.Length - 4)
        buf.[expectedByteArray.Length + 1] <- 1uy
        let pt = Point.Serializer.FromBytes(buf)
        if pt.X <> 1 then
            fail (sprintf "skip-value test: expected pt.X = 1, got %d" pt.X)

    let typedEv = evaluateTypedValue input.Value

    for altJsonExpr in input.AlternativeJsons do
        let altJson = evaluateString altJsonExpr
        let roundTripped = typedEv.FromJsonKeepUnrecognized(altJson)
        let roundTripJson = roundTripped.ToDenseJson()
        if not (input.ExpectedDenseJson.Contains(roundTripJson)) then
            fail (sprintf "alternative JSON round-trip mismatch: got %s" roundTripJson)

    for altJson in input.ExpectedDenseJson.Concat(input.ExpectedReadableJson) do
        let roundTripped = typedEv.FromJsonKeepUnrecognized(altJson)
        let roundTripJson = roundTripped.ToDenseJson()
        if not (input.ExpectedDenseJson.Contains(roundTripJson)) then
            fail (sprintf "expected JSON round-trip mismatch: got %s" roundTripJson)

    for altBytesExpr in input.AlternativeBytes do
        let altBytes = evaluateBytes altBytesExpr
        let roundTripped = typedEv.FromBytesDropUnrecognized(altBytes)
        let roundTripBytes = roundTripped.ToBytes()
        let found = input.ExpectedBytes.Any(fun exp -> exp.Span.SequenceEqual(roundTripBytes))
        if not found then
            fail (sprintf "alternative bytes round-trip mismatch: got hex:%s" (toHex roundTripBytes))

    for altBytes in input.ExpectedBytes do
        let altByteArray = altBytes.ToArray()
        let roundTripped = typedEv.FromBytesDropUnrecognized(altByteArray)
        let roundTripBytes = roundTripped.ToBytes()
        let found = input.ExpectedBytes.Any(fun exp -> exp.Span.SequenceEqual(roundTripBytes))
        if not found then
            fail "expected bytes round-trip mismatch"

    match input.ExpectedTypeDescriptor with
    | None -> ()
    | Some expectedTd ->
        let actualTd = typedEv.TypeDescriptorJson()
        if actualTd <> expectedTd then
            fail (sprintf "type descriptor mismatch:\nactual: %s\nexpected: %s" actualTd expectedTd)
        let parsed = TypeDescriptor.ParseFromJson(expectedTd)
        let reparsedTd = parsed.AsJson()
        if reparsedTd <> expectedTd then
            fail "type descriptor round-trip mismatch"

let verifyAssertion (assertion: Assertion) : unit =
    match assertion with
    | Assertion.BytesEqual a ->
        let actual = evaluateBytes a.Actual
        let expected = evaluateBytes a.Expected
        if not (actual.SequenceEqual(expected)) then
            fail (sprintf "bytes mismatch: actual hex:%s vs expected hex:%s" (toHex actual) (toHex expected))
    | Assertion.BytesIn a ->
        let actual = evaluateBytes a.Actual
        let found = a.Expected.Any(fun exp -> exp.Span.SequenceEqual(actual))
        if not found then
            fail (sprintf "bytes not in expected set: hex:%s" (toHex actual))
    | Assertion.StringEqual a ->
        let actual = evaluateString a.Actual
        let expected = evaluateString a.Expected
        if actual <> expected then
            fail (sprintf "string mismatch: actual %s vs expected %s" actual expected)
    | Assertion.StringIn a ->
        let actual = evaluateString a.Actual
        if not (a.Expected.Contains(actual)) then
            fail (sprintf "string not in expected set: %s" actual)
    | Assertion.ReserializeValue a -> verifyReserializeValue a
    | Assertion.ReserializeLargeString a ->
        let s = System.String('a', a.NumChars)
        let ser = Serializers.String
        if ser.FromJson(ser.ToJson(s)) <> s then
            fail "large string dense JSON mismatch"
        if ser.FromJson(ser.ToJson(s, readable = true)) <> s then
            fail "large string readable JSON mismatch"
        let bytes = ser.ToBytes(s)
        let prefix = a.ExpectedBytePrefix.ToArray()
        if not (bytes.Take(prefix.Length).SequenceEqual(prefix)) then
            fail "large string byte prefix mismatch"
        if ser.FromBytes(bytes) <> s then
            fail "large string bytes round-trip mismatch"
    | Assertion.ReserializeLargeArray a ->
        let n = a.NumItems
        let arr = Enumerable.Repeat(1, n).ToImmutableArray()
        let ser = Serializers.Array(Serializers.Int32)
        let isCorrect (v: ImmutableArray<int>) = v.Length = n && v.All(fun x -> x = 1)
        if not (isCorrect (ser.FromJson(ser.ToJson(arr)))) then
            fail "large array dense JSON mismatch"
        if not (isCorrect (ser.FromJson(ser.ToJson(arr, readable = true)))) then
            fail "large array readable JSON mismatch"
        let bytes = ser.ToBytes(arr)
        let prefix = a.ExpectedBytePrefix.ToArray()
        if not (bytes.Take(prefix.Length).SequenceEqual(prefix)) then
            fail "large array byte prefix mismatch"
        if not (isCorrect (ser.FromBytes(bytes))) then
            fail "large array bytes round-trip mismatch"
    | Assertion.EnumAFromJsonIsConstant a ->
        let json = evaluateString a.Actual
        let value = EnumA.Serializer.FromJson(json, keepUnrecognizedValues = a.KeepUnrecognized)
        if not ( obj.ReferenceEquals(value, EnumA.A) ) then
            fail "enum_a_from_json_is_constant mismatch"
    | Assertion.EnumAFromBytesIsConstant a ->
        let bytes = evaluateBytes a.Actual
        let value = EnumA.Serializer.FromBytes(bytes, keepUnrecognizedValues = a.KeepUnrecognized)
        if not ( obj.ReferenceEquals(value, EnumA.A) ) then
            fail "enum_a_from_bytes_is_constant mismatch"
    | Assertion.EnumBFromJsonIsWrapperB a ->
        let json = evaluateString a.Actual
        let value = EnumB.Serializer.FromJson(json, keepUnrecognizedValues = a.KeepUnrecognized)
        match value with
        | EnumB.B b when b = a.Expected -> ()
        | _ -> fail "enum_b_from_json_is_wrapper_b mismatch"
    | Assertion.EnumBFromBytesIsWrapperB a ->
        let bytes = evaluateBytes a.Actual
        let value = EnumB.Serializer.FromBytes(bytes, keepUnrecognizedValues = a.KeepUnrecognized)
        match value with
        | EnumB.B b when b = a.Expected -> ()
        | _ -> fail "enum_b_from_bytes_is_wrapper_b mismatch"
    | Assertion.Unknown _ -> fail "unknown Assertion variant"

let run () =
    let unitTests = Consts.UnitTests
    if unitTests.IsEmpty then
        failwith "UNIT_TESTS constant is empty"

    let firstNumber = unitTests.[0].TestNumber
    for i in 0 .. unitTests.Length - 1 do
        if unitTests.[i].TestNumber <> firstNumber + i then
            failwithf "Sequential test number mismatch at index %d" i

    let failures = System.Collections.Generic.List<string>()
    for unitTest in unitTests do
        try
            verifyAssertion unitTest.Assertion
        with GoldenAssertionException msg ->
            failures.Add(sprintf "Test #%d: %s" unitTest.TestNumber msg)

    if failures.Count > 0 then
        failwithf "%d golden test(s) failed:\n\n%s" failures.Count (String.Join("\n\n", failures))

    printfn "All %d F# golden tests passed!" unitTests.Length
