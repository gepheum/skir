let assert_ok = function
  | Ok v -> v
  | Error msg -> failwith ("Expected Ok, got Error: " ^ msg)

let test_timestamps () =
  let t0 = Skir.Timestamp.unix_epoch in
  assert (Skir.Timestamp.unix_millis t0 = 0L);
  assert (Skir.Timestamp.to_iso8601 t0 = "1970-01-01T00:00:00.000Z");

  let t1 = Skir.Timestamp.from_unix_millis 1234567890000L in
  assert (Skir.Timestamp.to_iso8601 t1 = "2009-02-13T23:31:30.000Z");

  let t_low = Skir.Timestamp.from_unix_millis (-9000000000000000L) in
  assert (Skir.Timestamp.equal t_low Skir.Timestamp.min);

  let t_high = Skir.Timestamp.from_unix_millis 9000000000000000L in
  assert (Skir.Timestamp.equal t_high Skir.Timestamp.max)

let test_primitive_serializers () =
  (* bool *)
  let b_ser = Skir.bool_serializer in
  assert (Skir.to_dense_json_code b_ser true = "1");
  assert (Skir.to_readable_json_code b_ser true = "true");
  assert (assert_ok (Skir.from_json_code b_ser "true") = true);
  assert (assert_ok (Skir.from_json_code b_ser "false") = false);
  assert (assert_ok (Skir.from_json_code b_ser "0") = false);
  assert (assert_ok (Skir.from_json_code b_ser "\"0\"") = false);
  assert (assert_ok (Skir.from_json_code b_ser "1") = true);
  assert (assert_ok (Skir.from_bytes b_ser (Skir.to_bytes b_ser true)) = true);
  assert (assert_ok (Skir.from_bytes b_ser (Skir.to_bytes b_ser false)) = false);

  (* int32 *)
  let i32_ser = Skir.int32_serializer in
  assert (Skir.to_dense_json_code i32_ser 42l = "42");
  assert (assert_ok (Skir.from_json_code i32_ser "3.14") = 3l);
  assert (assert_ok (Skir.from_json_code i32_ser "-3.14") = -3l);
  List.iter
    (fun v ->
      assert (
        assert_ok (Skir.from_bytes i32_ser (Skir.to_bytes i32_ser v)) = v))
    [ 0l; 1l; 231l; 232l; 257l; 65535l; 65536l; -1l; -256l; -257l; -65536l; -100000l ];

  (* int64 & hash64 *)
  let i64_ser = Skir.int64_serializer in
  assert (
    Skir.to_dense_json_code i64_ser 9007199254740991L = "9007199254740991");
  assert (
    Skir.to_dense_json_code i64_ser 9007199254740992L = "\"9007199254740992\"");
  assert (
    assert_ok (Skir.from_json_code i64_ser "\"9007199254740992\"")
    = 9007199254740992L);
  List.iter
    (fun v ->
      assert (
        assert_ok (Skir.from_bytes i64_ser (Skir.to_bytes i64_ser v)) = v))
    [ 0L; 1L; -1L; 42L; -42L; Int64.max_int; Int64.min_int ];

  let h64_ser = Skir.hash64_serializer in
  assert (Skir.to_dense_json_code h64_ser (-1L) = "\"18446744073709551615\"");
  assert (
    assert_ok (Skir.from_json_code h64_ser "\"18446744073709551615\"") = -1L);
  assert (
    assert_ok (Skir.from_bytes h64_ser (Skir.to_bytes h64_ser (-1L))) = -1L);

  (* floats *)
  let f32_ser = Skir.float32_serializer in
  assert (Skir.to_dense_json_code f32_ser 1.5 = "1.5");
  assert (Skir.to_dense_json_code f32_ser Float.infinity = "\"Infinity\"");
  assert (Skir.to_dense_json_code f32_ser Float.neg_infinity = "\"-Infinity\"");
  assert (Skir.to_dense_json_code f32_ser Float.nan = "\"NaN\"");
  assert (
    Float.is_nan (assert_ok (Skir.from_json_code f32_ser "\"NaN\"")));

  let f64_ser = Skir.float64_serializer in
  assert (Skir.to_dense_json_code f64_ser 3.14 = "3.14");
  assert (
    assert_ok (Skir.from_bytes f64_ser (Skir.to_bytes f64_ser 3.14)) = 3.14);

  (* string & bytes *)
  let str_ser = Skir.string_serializer in
  assert (Skir.to_dense_json_code str_ser "hello" = "\"hello\"");
  assert (
    assert_ok (Skir.from_bytes str_ser (Skir.to_bytes str_ser "🚀")) = "🚀");

  let bytes_ser = Skir.bytes_serializer in
  assert (Skir.to_dense_json_code bytes_ser "\x01\x02\x03" = "\"AQID\"");
  assert (Skir.to_readable_json_code bytes_ser "\x01\x02\x03" = "\"hex:010203\"");
  assert (
    assert_ok (Skir.from_json_code bytes_ser "\"hex:010203\"") = "\x01\x02\x03");
  assert (
    assert_ok (Skir.from_json_code bytes_ser "\"AQID\"") = "\x01\x02\x03");

  (* timestamp *)
  let ts_ser = Skir.timestamp_serializer in
  let ts3 = Skir.Timestamp.from_unix_millis 3L in
  assert (Skir.to_dense_json_code ts_ser ts3 = "3");
  assert (
    Skir.to_readable_json_code ts_ser ts3
    = "{\n  \"unix_millis\": 3,\n  \"formatted\": \"1970-01-01T00:00:00.003Z\"\n}");
  assert (
    Skir.Timestamp.equal
      (assert_ok
         (Skir.from_json_code ts_ser
            "{\"unix_millis\": 3, \"formatted\": \"FOO\"}"))
      ts3)

let test_struct_and_enum_adapters () =
  (* Point struct: x (0), removed (1), y (2) *)
  let default_pt = (0l, 0l, None) in
  let sa =
    Skir.Internal.make_struct_adapter ~record_id:"test.skir:Point"
      ~doc:"A point" ~default:default_pt
      ~new_mutable:(fun () -> (ref 0l, ref 0l, ref None))
      ~to_frozen:(fun (rx, ry, ru) -> (!rx, !ry, !ru))
      ~get_unrecognized:(fun (_, _, u) -> u)
      ~set_unrecognized:(fun (_, _, ru) u -> ru := u)
  in
  Skir.Internal.add_struct_field sa ~name:"x" ~number:0
    ~serializer:Skir.int32_serializer
    ~getter:(fun (x, _, _) -> x)
    ~setter:(fun (rx, _, _) v -> rx := v)
    ~doc:"X coord";
  Skir.Internal.add_struct_field sa ~name:"y" ~number:2
    ~serializer:Skir.int32_serializer
    ~getter:(fun (_, y, _) -> y)
    ~setter:(fun (_, ry, _) v -> ry := v)
    ~doc:"";
  Skir.Internal.add_struct_removed_number sa 1;
  Skir.Internal.finalize_struct sa;
  let pt_ser = Skir.Internal.struct_serializer sa in

  let p1 = (10l, 20l, None) in
  assert (Skir.to_dense_json_code pt_ser p1 = "[10,0,20]");
  assert (Skir.to_readable_json_code pt_ser p1 = "{\n  \"x\": 10,\n  \"y\": 20\n}");
  let p_keep =
    assert_ok
      (Skir.from_json_code ~unrecognized_values:Skir.Keep pt_ser "[10,0,20,99]")
  in
  assert (Skir.to_dense_json_code pt_ser p_keep = "[10,0,20,99]");
  let p_drop = assert_ok (Skir.from_json_code pt_ser "[10,0,20,99]") in
  assert (Skir.to_dense_json_code pt_ser p_drop = "[10,0,20]");

  (* Type descriptor round-trip *)
  let td = Skir.type_descriptor pt_ser in
  let td_code = Skir.Type_descriptor.to_json_code td in
  let td_parsed = assert_ok (Skir.Type_descriptor.from_json_code td_code) in
  assert (Skir.Type_descriptor.to_json_code td_parsed = td_code)

let test_service () =
  let echo_method : (string, string) Skir.Method.t =
    {
      name = "Echo";
      number = 101L;
      request_serializer = Skir.string_serializer;
      response_serializer = Skir.string_serializer;
      doc = "Echoes a string";
    }
  in
  let svc = Skir.Service.create () in
  Skir.Service.add_method svc echo_method (fun req meta -> req ^ ":" ^ meta);
  let resp =
    Skir.Service.handle_request svc "Echo:101::\"hello\"" "world"
  in
  assert (resp.status_code = 200);
  assert (resp.data = "\"hello:world\"");

  let list_resp = Skir.Service.handle_request svc "list" "" in
  assert (list_resp.status_code = 200);

  let studio_resp = Skir.Service.handle_request svc "studio" "" in
  assert (studio_resp.status_code = 200)

let () =
  test_timestamps ();
  test_primitive_serializers ();
  test_struct_and_enum_adapters ();
  test_service ();
  print_endline "All OCaml skir_client unit tests passed!"
