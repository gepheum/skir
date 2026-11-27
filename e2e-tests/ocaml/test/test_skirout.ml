module Full_name = Skirout_full_name
module Enums = Skirout_enums
module Structs = Skirout_structs
module Constants = Skirout_constants
module Methods = Skirout_methods
module Quest = Skirout_quest_collection
module Fantasy =
  Skirout__ext__gepheum__skir_fantasy_game_example__fantasy_game

let test_full_name () =
  let fn =
    Full_name.FullName.make ~first_name:"Tyler" ~last_name:"Fibonacci" ()
  in
  assert (fn.first_name = "Tyler");
  assert (fn.last_name = "Fibonacci");
  assert (
    Skir.to_dense_json_code (Full_name.FullName.serializer ()) fn
    = "[\"Tyler\",\"Fibonacci\"]");

  let partial_fn = Full_name.FullName.make ~first_name:"Tyler" () in
  assert (partial_fn.first_name = "Tyler");
  assert (partial_fn.last_name = "");
  assert (
    Skir.to_dense_json_code (Full_name.FullName.serializer ()) partial_fn
    = "[\"Tyler\"]");

  let replaced = Full_name.FullName.copy ~last_name:"Smith" fn in
  assert (replaced.first_name = "Tyler");
  assert (replaced.last_name = "Smith")

let test_enums_and_pattern_matching () =
  let describe (val_ : Enums.EnumWithStructField.t) : string =
    match val_ with
    | Enums.EnumWithStructField.Unknown _ -> "unknown"
    | Enums.EnumWithStructField.S s -> Printf.sprintf "s:%g,%g" s.x s.y
  in
  assert (describe Enums.EnumWithStructField.unknown = "unknown");
  let s_inst =
    Enums.EnumWithStructField.S
      (Enums.EnumWithStructField.S.make ~x:1.5 ~y:2.5 ())
  in
  assert (describe s_inst = "s:1.5,2.5");

  (* Empty enum *)
  match
    Skir.from_json_code (Enums.EmptyEnum.serializer ()) "\"UNKNOWN\""
  with
  | Ok (Enums.EmptyEnum.Unknown _) -> ()
  | _ -> failwith "Expected EmptyEnum Unknown"

let test_keyed_arrays () =
  let item1 =
    Structs.Item.make ~weekday:Enums.Weekday.Monday ~bool_:true ()
  in
  let item2 =
    Structs.Item.make ~weekday:Enums.Weekday.Tuesday ~bool_:true ()
  in
  let items = Structs.Items.make ~array_with_enum_key:[ item1; item2 ] () in
  assert (List.length items.array_with_enum_key = 2);
  assert (List.nth items.array_with_enum_key 1 = item2)

let test_constants_and_methods () =
  let expected =
    Enums.JsonValue.Array
      [
        Enums.JsonValue.Boolean true;
        Enums.JsonValue.Number 2.5;
        Enums.JsonValue.String "\n        foo\n        bar";
        Enums.JsonValue.Object
          [
            Enums.JsonValue.Pair.make ~name:"foo"
              ~value:Enums.JsonValue.Null ();
          ];
      ]
  in
  assert (Constants.one_constant_const = expected);

  assert (Methods.my_procedure_method.name = "MyProcedure");
  assert (Methods.my_procedure_method.doc = "My procedure")

let test_external () =
  let _ = Quest.QuestCollection.default in
  let _ = Fantasy.Quest.default in
  ()

let () =
  test_full_name ();
  test_enums_and_pattern_matching ();
  test_keyed_arrays ();
  test_constants_and_methods ();
  test_external ();
  print_endline "All OCaml skirout E2E tests passed!"
