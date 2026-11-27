(* Code snippets showing how to use OCaml-generated Skir types.
   Run with:
     dune exec ./snippets.exe *)

module User_skir = Skirout_user

let assert_ok = function
  | Ok v -> v
  | Error msg -> failwith ("Expected Ok, got Error: " ^ msg)

let get_subscription_info_text
    (status : User_skir.SubscriptionStatus.t) : string =
  match status with
  | User_skir.SubscriptionStatus.Unknown _ -> "Unknown subscription status"
  | User_skir.SubscriptionStatus.Free -> "Free user"
  | User_skir.SubscriptionStatus.Premium -> "Premium user"
  | User_skir.SubscriptionStatus.Trial trial ->
    "On trial since " ^ Skir.Timestamp.to_iso8601 trial.start_time

let () =
  (* ===========================================================================
     STRUCTS
     =========================================================================== *)

  (* Construct a User.t with User.make. Any omitted labeled argument defaults
     to its zero value. *)
  let john =
    User_skir.User.make
      ~user_id:42L
      ~name:"John Doe"
      ~quote:"Coffee is just a socially acceptable form of rage."
      ~pets:
        [
          User_skir.User.Pet.make
            ~name:"Dumbo"
            ~height_in_meters:1.0
            ~picture:"🐘"
            ();
        ]
      ~subscription_status:User_skir.SubscriptionStatus.Free
      ()
  in
  assert (john.name = "John Doe");

  (* You can also specify only a subset of fields: *)
  let jane =
    User_skir.User.make
      ~user_id:43L
      ~name:"Jane Doe"
      ()
  in
  assert (jane.quote = "");

  (* User.default holds the default value with all fields set to their default values. *)
  assert (User_skir.User.default = User_skir.User.make ());

  (* Creating modified copies with User.copy or OCaml's `with` syntax *)
  let evil_john =
    User_skir.User.copy
      ~name:"Evil John"
      ~quote:"I solemnly swear I am up to no good."
      john
  in
  let evil_john_2 =
    {
      john with
      name = "Evil John";
      quote = "I solemnly swear I am up to no good.";
    }
  in
  assert (evil_john = evil_john_2);
  assert (evil_john.user_id = 42L);

  (* ===========================================================================
     ENUMS
     =========================================================================== *)

  let john_status = User_skir.SubscriptionStatus.Free in
  let _jane_status = User_skir.SubscriptionStatus.Premium in
  let joly_status = User_skir.SubscriptionStatus.unknown in

  let roni_status =
    User_skir.SubscriptionStatus.Trial
      (User_skir.SubscriptionStatus.Trial.make
         ~start_time:(Skir.Timestamp.from_unix_millis 1744974198000L)
         ())
  in

  assert (
    User_skir.SubscriptionStatus.kind john_status
    = User_skir.SubscriptionStatus.Kind_Free);
  assert (
    User_skir.SubscriptionStatus.kind joly_status
    = User_skir.SubscriptionStatus.Kind_unknown);
  assert (
    User_skir.SubscriptionStatus.kind roni_status
    = User_skir.SubscriptionStatus.Kind_Trial);

  assert (get_subscription_info_text john_status = "Free user");
  assert (
    get_subscription_info_text roni_status
    = "On trial since 2025-04-18T11:03:18.000Z");

  (* ===========================================================================
     SERIALIZATION
     =========================================================================== *)

  let serializer = User_skir.User.serializer () in

  (* Serialize 'john' to dense JSON *)
  let john_dense_json = Skir.to_dense_json_code serializer john in
  assert (String.length john_dense_json > 0 && john_dense_json.[0] = '[');

  (* Serialize 'john' to readable JSON *)
  let john_readable_json = Skir.to_readable_json_code serializer john in
  print_endline john_readable_json;

  (* Deserialize from dense and readable JSON *)
  assert (assert_ok (Skir.from_json_code serializer john_dense_json) = john);
  assert (assert_ok (Skir.from_json_code serializer john_readable_json) = john);

  (* Serialize to and deserialize from compact binary format *)
  let john_bytes = Skir.to_bytes serializer john in
  assert (assert_ok (Skir.from_bytes serializer john_bytes) = john);

  (* ===========================================================================
     PRIMITIVE & COMPOSITE SERIALIZERS
     =========================================================================== *)

  assert (Skir.to_dense_json_code Skir.bool_serializer true = "1");
  assert (Skir.to_dense_json_code Skir.int32_serializer 3l = "3");
  assert (
    Skir.to_dense_json_code Skir.int64_serializer 9223372036854775807L
    = "\"9223372036854775807\"");
  assert (
    Skir.to_dense_json_code Skir.hash64_serializer (-1L)
    = "\"18446744073709551615\"");
  assert (
    Skir.to_dense_json_code Skir.timestamp_serializer
      (Skir.Timestamp.from_unix_millis 1743682787000L)
    = "1743682787000");
  assert (Skir.to_dense_json_code Skir.float32_serializer 1.5 = "1.5");
  assert (Skir.to_dense_json_code Skir.float64_serializer 3.14 = "3.14");
  assert (Skir.to_dense_json_code Skir.string_serializer "Foo" = "\"Foo\"");
  assert (Skir.to_dense_json_code Skir.bytes_serializer "\x01\x02\x03" = "\"AQID\"");

  let opt_str = Skir.optional_serializer Skir.string_serializer in
  assert (Skir.to_dense_json_code opt_str (Some "foo") = "\"foo\"");
  assert (Skir.to_dense_json_code opt_str None = "null");

  let bool_list = Skir.list_serializer Skir.bool_serializer in
  assert (Skir.to_dense_json_code bool_list [ true; false ] = "[1,0]");

  (* ===========================================================================
     CONSTANTS
     =========================================================================== *)

  assert (User_skir.tarzan_const.user_id = 123L);
  assert (User_skir.tarzan_const.name = "Tarzan");
  print_endline
    (Skir.to_readable_json_code serializer User_skir.tarzan_const);

  (* ===========================================================================
     REFLECTION
     =========================================================================== *)

  let td = Skir.type_descriptor serializer in
  let td_json = Skir.Type_descriptor.to_json_code td in
  print_endline td_json;
  let parsed_td = assert_ok (Skir.Type_descriptor.from_json_code td_json) in
  assert (Skir.Type_descriptor.to_json_code parsed_td = td_json)
