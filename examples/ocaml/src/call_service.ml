(* Sends RPCs to a SkirRPC service.
   See start_service.ml for how to start one.
   Run with:
     dune exec ./call_service.exe *)

module User_skir = Skirout_user
module Service_skir = Skirout_service

let assert_ok = function
  | Ok v -> v
  | Error msg -> failwith ("RPC failed: " ^ msg)

let () =
  let client = Skir.Service_client.create "http://localhost:8787/myapi" in

  print_endline "";
  print_endline "About to add 2 users: John Doe and Tarzan";

  let _ =
    assert_ok
      (Skir.Service_client.invoke_remote client Service_skir.add_user_method
         (Service_skir.AddUserRequest.make
            ~user:(User_skir.User.make ~user_id:42L ~name:"John Doe" ())
            ()))
  in

  let _ =
    assert_ok
      (Skir.Service_client.invoke_remote client Service_skir.add_user_method
         ~headers:[ ("X-Foo", "hi") ]
         (Service_skir.AddUserRequest.make ~user:User_skir.tarzan_const ()))
  in

  print_endline "Done";

  let found =
    assert_ok
      (Skir.Service_client.invoke_remote client Service_skir.get_user_method
         (Service_skir.GetUserRequest.make ~user_id:123L ()))
  in

  Printf.printf "Found user: %s\n"
    (Skir.to_readable_json_code
       (Service_skir.GetUserResponse.serializer ())
       found)
