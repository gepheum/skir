module Goldens = Skirout__ext__gepheum__skir_golden_tests__goldens

type evaluated_value = {
  to_bytes : unit -> string;
  to_dense_json : unit -> string;
  to_readable_json : unit -> string;
  type_descriptor_json : unit -> string;
  from_json_keep : string -> (evaluated_value, string) result;
  from_json_drop : string -> (evaluated_value, string) result;
  from_bytes_drop : string -> (evaluated_value, string) result;
}

let rec make_ev (value : 'a) (ser : 'a Skir.serializer) : evaluated_value =
  {
    to_bytes = (fun () -> Skir.to_bytes ser value);
    to_dense_json = (fun () -> Skir.to_dense_json_code ser value);
    to_readable_json = (fun () -> Skir.to_readable_json_code ser value);
    type_descriptor_json =
      (fun () -> Skir.Type_descriptor.to_json_code (Skir.type_descriptor ser));
    from_json_keep =
      (fun json ->
        match Skir.from_json_code ~unrecognized_values:Skir.Keep ser json with
        | Ok v -> Ok (make_ev v ser)
        | Error e -> Error e);
    from_json_drop =
      (fun json ->
        match Skir.from_json_code ~unrecognized_values:Skir.Drop ser json with
        | Ok v -> Ok (make_ev v ser)
        | Error e -> Error e);
    from_bytes_drop =
      (fun bytes ->
        match Skir.from_bytes ~unrecognized_values:Skir.Drop ser bytes with
        | Ok v -> Ok (make_ev v ser)
        | Error e -> Error e);
  }

let to_hex s = Skir.Hex.encode s

let starts_with s prefix =
  let slen = String.length s in
  let plen = String.length prefix in
  slen >= plen && String.sub s 0 plen = prefix

let ( let* ) = Result.bind

let rec evaluate_bytes (expr : Goldens.BytesExpression.t) :
    (string, string) result =
  match expr with
  | Goldens.BytesExpression.Literal b -> Ok b
  | Goldens.BytesExpression.ToBytes tv ->
    let* ev = evaluate_typed_value tv in
    Ok (ev.to_bytes ())
  | Goldens.BytesExpression.Unknown _ -> Error "unknown BytesExpression variant"

and evaluate_string (expr : Goldens.StringExpression.t) :
    (string, string) result =
  match expr with
  | Goldens.StringExpression.Literal s -> Ok s
  | Goldens.StringExpression.ToDenseJson tv ->
    let* ev = evaluate_typed_value tv in
    Ok (ev.to_dense_json ())
  | Goldens.StringExpression.ToReadableJson tv ->
    let* ev = evaluate_typed_value tv in
    Ok (ev.to_readable_json ())
  | Goldens.StringExpression.Unknown _ ->
    Error "unknown StringExpression variant"

and evaluate_typed_value (tv : Goldens.TypedValue.t) :
    (evaluated_value, string) result =
  match tv with
  | Goldens.TypedValue.Unknown _ -> Error "unknown TypedValue variant"
  | Goldens.TypedValue.Bool v -> Ok (make_ev v Skir.bool_serializer)
  | Goldens.TypedValue.Int32 v -> Ok (make_ev v Skir.int32_serializer)
  | Goldens.TypedValue.Int64 v -> Ok (make_ev v Skir.int64_serializer)
  | Goldens.TypedValue.Hash64 v -> Ok (make_ev v Skir.hash64_serializer)
  | Goldens.TypedValue.Float32 v -> Ok (make_ev v Skir.float32_serializer)
  | Goldens.TypedValue.Float64 v -> Ok (make_ev v Skir.float64_serializer)
  | Goldens.TypedValue.Timestamp v -> Ok (make_ev v Skir.timestamp_serializer)
  | Goldens.TypedValue.String v -> Ok (make_ev v Skir.string_serializer)
  | Goldens.TypedValue.Bytes v -> Ok (make_ev v Skir.bytes_serializer)
  | Goldens.TypedValue.BoolOptional v ->
    Ok (make_ev v (Skir.optional_serializer Skir.bool_serializer))
  | Goldens.TypedValue.Ints v ->
    Ok (make_ev v (Skir.list_serializer Skir.int32_serializer))
  | Goldens.TypedValue.Point v -> Ok (make_ev v (Goldens.Point.serializer ()))
  | Goldens.TypedValue.Color v -> Ok (make_ev v (Goldens.Color.serializer ()))
  | Goldens.TypedValue.MyEnum v -> Ok (make_ev v (Goldens.MyEnum.serializer ()))
  | Goldens.TypedValue.EnumA v -> Ok (make_ev v (Goldens.EnumA.serializer ()))
  | Goldens.TypedValue.EnumB v -> Ok (make_ev v (Goldens.EnumB.serializer ()))
  | Goldens.TypedValue.KeyedArrays v ->
    Ok (make_ev v (Goldens.KeyedArrays.serializer ()))
  | Goldens.TypedValue.RecStruct v ->
    Ok (make_ev v (Goldens.RecStruct.serializer ()))
  | Goldens.TypedValue.RecEnum v ->
    Ok (make_ev v (Goldens.RecEnum.serializer ()))
  | Goldens.TypedValue.RoundTripDenseJson inner ->
    let* ev = evaluate_typed_value inner in
    ev.from_json_drop (ev.to_dense_json ())
  | Goldens.TypedValue.RoundTripReadableJson inner ->
    let* ev = evaluate_typed_value inner in
    ev.from_json_drop (ev.to_readable_json ())
  | Goldens.TypedValue.RoundTripBytes inner ->
    let* ev = evaluate_typed_value inner in
    ev.from_bytes_drop (ev.to_bytes ())
  | Goldens.TypedValue.PointFromJsonKeepUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.Point.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Keep
         (Goldens.Point.serializer ())
         json)
  | Goldens.TypedValue.PointFromJsonDropUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.Point.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Drop
         (Goldens.Point.serializer ())
         json)
  | Goldens.TypedValue.PointFromBytesKeepUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.Point.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Keep
         (Goldens.Point.serializer ())
         bytes)
  | Goldens.TypedValue.PointFromBytesDropUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.Point.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Drop
         (Goldens.Point.serializer ())
         bytes)
  | Goldens.TypedValue.ColorFromJsonKeepUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.Color.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Keep
         (Goldens.Color.serializer ())
         json)
  | Goldens.TypedValue.ColorFromJsonDropUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.Color.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Drop
         (Goldens.Color.serializer ())
         json)
  | Goldens.TypedValue.ColorFromBytesKeepUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.Color.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Keep
         (Goldens.Color.serializer ())
         bytes)
  | Goldens.TypedValue.ColorFromBytesDropUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.Color.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Drop
         (Goldens.Color.serializer ())
         bytes)
  | Goldens.TypedValue.MyEnumFromJsonKeepUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.MyEnum.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Keep
         (Goldens.MyEnum.serializer ())
         json)
  | Goldens.TypedValue.MyEnumFromJsonDropUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.MyEnum.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Drop
         (Goldens.MyEnum.serializer ())
         json)
  | Goldens.TypedValue.MyEnumFromBytesKeepUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.MyEnum.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Keep
         (Goldens.MyEnum.serializer ())
         bytes)
  | Goldens.TypedValue.MyEnumFromBytesDropUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.MyEnum.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Drop
         (Goldens.MyEnum.serializer ())
         bytes)
  | Goldens.TypedValue.EnumAFromJsonKeepUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.EnumA.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Keep
         (Goldens.EnumA.serializer ())
         json)
  | Goldens.TypedValue.EnumAFromJsonDropUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.EnumA.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Drop
         (Goldens.EnumA.serializer ())
         json)
  | Goldens.TypedValue.EnumAFromBytesKeepUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.EnumA.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Keep
         (Goldens.EnumA.serializer ())
         bytes)
  | Goldens.TypedValue.EnumAFromBytesDropUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.EnumA.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Drop
         (Goldens.EnumA.serializer ())
         bytes)
  | Goldens.TypedValue.EnumBFromJsonKeepUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.EnumB.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Keep
         (Goldens.EnumB.serializer ())
         json)
  | Goldens.TypedValue.EnumBFromJsonDropUnrecognized expr ->
    let* json = evaluate_string expr in
    Result.map
      (fun v -> make_ev v (Goldens.EnumB.serializer ()))
      (Skir.from_json_code ~unrecognized_values:Skir.Drop
         (Goldens.EnumB.serializer ())
         json)
  | Goldens.TypedValue.EnumBFromBytesKeepUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.EnumB.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Keep
         (Goldens.EnumB.serializer ())
         bytes)
  | Goldens.TypedValue.EnumBFromBytesDropUnrecognized expr ->
    let* bytes = evaluate_bytes expr in
    Result.map
      (fun v -> make_ev v (Goldens.EnumB.serializer ()))
      (Skir.from_bytes ~unrecognized_values:Skir.Drop
         (Goldens.EnumB.serializer ())
         bytes)

let rec check_all f = function
  | [] -> Ok ()
  | x :: rest ->
    let* () = f x in
    check_all f rest

let verify_reserialize_one (tv : Goldens.TypedValue.t)
    (input : Goldens.Assertion.ReserializeValue.t) : (unit, string) result =
  let* ev = evaluate_typed_value tv in
  let actual_bytes = ev.to_bytes () in
  let* () =
    if List.mem actual_bytes input.expected_bytes then Ok ()
    else
      Error
        (Printf.sprintf "bytes not in expected set\n  actual: hex:%s\n  expected: %s"
           (to_hex actual_bytes)
           (String.concat " or "
              (List.map (fun b -> "hex:" ^ to_hex b) input.expected_bytes)))
  in
  let dense_json = ev.to_dense_json () in
  let* () =
    if List.mem dense_json input.expected_dense_json then Ok ()
    else
      Error
        (Printf.sprintf "dense JSON not in expected set\n  actual: %s\n  expected: %s"
           dense_json
           (String.concat " or " input.expected_dense_json))
  in
  let readable_json = ev.to_readable_json () in
  if List.mem readable_json input.expected_readable_json then Ok ()
  else
    Error
      (Printf.sprintf "readable JSON not in expected set\n  actual: %s\n  expected: %s"
         readable_json
         (String.concat " or " input.expected_readable_json))

let verify_reserialize_value (input : Goldens.Assertion.ReserializeValue.t) :
    (unit, string) result =
  let all_values =
    [
      input.value;
      Goldens.TypedValue.RoundTripDenseJson input.value;
      Goldens.TypedValue.RoundTripReadableJson input.value;
      Goldens.TypedValue.RoundTripBytes input.value;
    ]
  in
  let* () = check_all (fun tv -> verify_reserialize_one tv input) all_values in

  (* Skip-value test *)
  let* () =
    check_all
      (fun expected_bytes ->
        let payload =
          String.sub expected_bytes 4 (String.length expected_bytes - 4)
        in
        let buf = "skir\xF8" ^ payload ^ "\x01" in
        match
          Skir.from_bytes ~unrecognized_values:Skir.Drop
            (Goldens.Point.serializer ())
            buf
        with
        | Error e -> Error ("skip-value test failed: " ^ e)
        | Ok pt ->
          if pt.x = 1l then Ok ()
          else
            Error
              (Printf.sprintf "skip-value test: expected pt.x = 1, got %ld" pt.x))
      input.expected_bytes
  in

  let* typed_ev = evaluate_typed_value input.value in

  (* Alternative JSONs *)
  let* () =
    check_all
      (fun alt_expr ->
        let* alt_json = evaluate_string alt_expr in
        let* rt = typed_ev.from_json_keep alt_json in
        let rt_json = rt.to_dense_json () in
        if List.mem rt_json input.expected_dense_json then Ok ()
        else
          Error
            (Printf.sprintf
               "alternative JSON round-trip mismatch: got %s, expected %s (from %s)"
               rt_json
               (String.concat " or " input.expected_dense_json)
               alt_json))
      input.alternative_jsons
  in

  (* Expected dense + readable JSONs *)
  let* () =
    check_all
      (fun alt_json ->
        let* rt = typed_ev.from_json_keep alt_json in
        let rt_json = rt.to_dense_json () in
        if List.mem rt_json input.expected_dense_json then Ok ()
        else
          Error
            (Printf.sprintf "expected JSON round-trip mismatch: got %s" rt_json))
      (input.expected_dense_json @ input.expected_readable_json)
  in

  (* Alternative bytes *)
  let* () =
    check_all
      (fun alt_expr ->
        let* alt_bytes = evaluate_bytes alt_expr in
        let* rt = typed_ev.from_bytes_drop alt_bytes in
        let rt_bytes = rt.to_bytes () in
        if List.mem rt_bytes input.expected_bytes then Ok ()
        else
          Error
            (Printf.sprintf "alternative bytes round-trip mismatch: got hex:%s"
               (to_hex rt_bytes)))
      input.alternative_bytes
  in

  (* Expected bytes *)
  let* () =
    check_all
      (fun alt_bytes ->
        let* rt = typed_ev.from_bytes_drop alt_bytes in
        let rt_bytes = rt.to_bytes () in
        if List.mem rt_bytes input.expected_bytes then Ok ()
        else Error "expected bytes round-trip mismatch")
      input.expected_bytes
  in

  (* Type descriptor check *)
  match input.expected_type_descriptor with
  | None -> Ok ()
  | Some expected_td -> (
    let actual_td = typed_ev.type_descriptor_json () in
    if actual_td <> expected_td then
      Error
        (Printf.sprintf "type descriptor mismatch\n  actual:\n%s\n  expected:\n%s"
           actual_td expected_td)
    else
      match Skir.Type_descriptor.from_json_code expected_td with
      | Error e -> Error ("failed to parse type descriptor: " ^ e)
      | Ok parsed ->
        let reparsed = Skir.Type_descriptor.to_json_code parsed in
        if reparsed = expected_td then Ok ()
        else Error "type descriptor round-trip mismatch")

let verify_assertion (a : Goldens.Assertion.t) : (unit, string) result =
  match a with
  | Goldens.Assertion.Unknown _ -> Error "unknown Assertion variant"
  | Goldens.Assertion.BytesEqual x ->
    let* actual = evaluate_bytes x.actual in
    let* expected = evaluate_bytes x.expected in
    if actual = expected then Ok ()
    else
      Error
        (Printf.sprintf "bytes mismatch: actual hex:%s vs expected hex:%s"
           (to_hex actual) (to_hex expected))
  | Goldens.Assertion.BytesIn x ->
    let* actual = evaluate_bytes x.actual in
    if List.mem actual x.expected then Ok ()
    else Error ("bytes not in expected set: hex:" ^ to_hex actual)
  | Goldens.Assertion.StringEqual x ->
    let* actual = evaluate_string x.actual in
    let* expected = evaluate_string x.expected in
    if actual = expected then Ok ()
    else
      Error
        (Printf.sprintf "string mismatch: actual %S vs expected %S" actual
           expected)
  | Goldens.Assertion.StringIn x ->
    let* actual = evaluate_string x.actual in
    if List.mem actual x.expected then Ok ()
    else Error ("string not in expected set: " ^ actual)
  | Goldens.Assertion.ReserializeValue x -> verify_reserialize_value x
  | Goldens.Assertion.ReserializeLargeString x ->
    let n = Int32.to_int x.num_chars in
    let s = String.make n 'a' in
    let ser = Skir.string_serializer in
    let* rt_dense = Skir.from_json_code ser (Skir.to_dense_json_code ser s) in
    let* () =
      if rt_dense = s then Ok () else Error "large string dense JSON mismatch"
    in
    let* rt_read = Skir.from_json_code ser (Skir.to_readable_json_code ser s) in
    let* () =
      if rt_read = s then Ok ()
      else Error "large string readable JSON mismatch"
    in
    let bytes = Skir.to_bytes ser s in
    let* () =
      if starts_with bytes x.expected_byte_prefix then Ok ()
      else Error "large string byte prefix mismatch"
    in
    let* rt_bytes = Skir.from_bytes ser bytes in
    if rt_bytes = s then Ok () else Error "large string bytes round-trip mismatch"
  | Goldens.Assertion.ReserializeLargeArray x ->
    let n = Int32.to_int x.num_items in
    let arr = List.init n (fun _ -> 1l) in
    let ser = Skir.list_serializer Skir.int32_serializer in
    let* rt_dense = Skir.from_json_code ser (Skir.to_dense_json_code ser arr) in
    let* () =
      if rt_dense = arr then Ok () else Error "large array dense JSON mismatch"
    in
    let* rt_read =
      Skir.from_json_code ser (Skir.to_readable_json_code ser arr)
    in
    let* () =
      if rt_read = arr then Ok ()
      else Error "large array readable JSON mismatch"
    in
    let bytes = Skir.to_bytes ser arr in
    let* () =
      if starts_with bytes x.expected_byte_prefix then Ok ()
      else Error "large array byte prefix mismatch"
    in
    let* rt_bytes = Skir.from_bytes ser bytes in
    if rt_bytes = arr then Ok ()
    else Error "large array bytes round-trip mismatch"
  | Goldens.Assertion.EnumAFromJsonIsConstant x -> (
    let* actual = evaluate_string x.actual in
    let policy = if x.keep_unrecognized then Skir.Keep else Skir.Drop in
    match
      Skir.from_json_code ~unrecognized_values:policy
        (Goldens.EnumA.serializer ())
        actual
    with
    | Ok Goldens.EnumA.A -> Ok ()
    | Ok _ -> Error "enum_a_from_json_is_constant: expected A"
    | Error e -> Error e)
  | Goldens.Assertion.EnumAFromBytesIsConstant x -> (
    let* actual = evaluate_bytes x.actual in
    let policy = if x.keep_unrecognized then Skir.Keep else Skir.Drop in
    match
      Skir.from_bytes ~unrecognized_values:policy
        (Goldens.EnumA.serializer ())
        actual
    with
    | Ok Goldens.EnumA.A -> Ok ()
    | Ok _ -> Error "enum_a_from_bytes_is_constant: expected A"
    | Error e -> Error e)
  | Goldens.Assertion.EnumBFromJsonIsWrapperB x -> (
    let* actual = evaluate_string x.actual in
    let policy = if x.keep_unrecognized then Skir.Keep else Skir.Drop in
    match
      Skir.from_json_code ~unrecognized_values:policy
        (Goldens.EnumB.serializer ())
        actual
    with
    | Ok (Goldens.EnumB.B v) when v = x.expected -> Ok ()
    | Ok _ -> Error "enum_b_from_json_is_wrapper_b mismatch"
    | Error e -> Error e)
  | Goldens.Assertion.EnumBFromBytesIsWrapperB x -> (
    let* actual = evaluate_bytes x.actual in
    let policy = if x.keep_unrecognized then Skir.Keep else Skir.Drop in
    match
      Skir.from_bytes ~unrecognized_values:policy
        (Goldens.EnumB.serializer ())
        actual
    with
    | Ok (Goldens.EnumB.B v) when v = x.expected -> Ok ()
    | Ok _ -> Error "enum_b_from_bytes_is_wrapper_b mismatch"
    | Error e -> Error e)

let () =
  let unit_tests = Goldens.unit_tests_const in
  assert (unit_tests <> []);
  let first_num = (List.hd unit_tests).test_number in
  List.iteri
    (fun i (ut : Goldens.UnitTest.t) ->
      assert (Int32.to_int ut.test_number = Int32.to_int first_num + i);
      match verify_assertion ut.assertion with
      | Ok () -> ()
      | Error msg ->
        failwith
          (Printf.sprintf "Golden test #%ld failed:\n%s" ut.test_number msg))
    unit_tests;
  Printf.printf "All %d OCaml golden tests passed!\n" (List.length unit_tests)
