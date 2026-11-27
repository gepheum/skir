(* Starts a SkirRPC service on http://localhost:8787/myapi
   Run with:
     dune exec ./start_service.exe
   Run call_service.exe to call this service from another process. *)

module User_skir = Skirout_user
module Service_skir = Skirout_service

let id_to_user : (int64, User_skir.User.t) Hashtbl.t = Hashtbl.create 16

let get_user (req : Service_skir.GetUserRequest.t) _meta :
    Service_skir.GetUserResponse.t =
  let user = Hashtbl.find_opt id_to_user req.user_id in
  Service_skir.GetUserResponse.make ~user ()

let add_user (req : Service_skir.AddUserRequest.t) _meta :
    Service_skir.AddUserResponse.t =
  let user = req.user in
  if user.user_id = 0L then invalid_arg "invalid user id";
  Printf.printf "Adding user: %s (id=%Ld)\n%!" user.name user.user_id;
  Hashtbl.replace id_to_user user.user_id user;
  Service_skir.AddUserResponse.default

let skir_service : (string * string) list Skir.Service.t =
  let svc = Skir.Service.create () in
  Skir.Service.add_method svc Service_skir.add_user_method add_user;
  Skir.Service.add_method svc Service_skir.get_user_method get_user;
  svc

let url_decode s =
  let len = String.length s in
  let buf = Buffer.create len in
  let hex_val ch =
    match ch with
    | '0' .. '9' -> Char.code ch - Char.code '0'
    | 'a' .. 'f' -> Char.code ch - Char.code 'a' + 10
    | 'A' .. 'F' -> Char.code ch - Char.code 'A' + 10
    | _ -> 0
  in
  let i = ref 0 in
  while !i < len do
    match s.[!i] with
    | '+' ->
      Buffer.add_char buf ' ';
      incr i
    | '%' when !i + 2 < len ->
      let hi = hex_val s.[!i + 1] in
      let lo = hex_val s.[!i + 2] in
      Buffer.add_char buf (Char.chr ((hi lsl 4) lor lo));
      i := !i + 3
    | ch ->
      Buffer.add_char buf ch;
      incr i
  done;
  Buffer.contents buf

let handle_client client_sock =
  let ic = Unix.in_channel_of_descr client_sock in
  let oc = Unix.out_channel_of_descr client_sock in
  (try
     let req_line = String.trim (input_line ic) in
     let parts = String.split_on_char ' ' req_line in
     let meth, target =
       match parts with
       | m :: t :: _ -> (m, t)
       | _ -> ("GET", "/")
     in
     let content_length = ref 0 in
     let headers = ref [] in
     (try
        while true do
          let line = String.trim (input_line ic) in
          if line = "" then raise Exit;
          match String.index_opt line ':' with
          | None -> ()
          | Some idx ->
            let k =
              String.lowercase_ascii (String.trim (String.sub line 0 idx))
            in
            let v =
              String.trim
                (String.sub line (idx + 1) (String.length line - idx - 1))
            in
            headers := (k, v) :: !headers;
            if k = "content-length" then
              content_length :=
                (match int_of_string_opt v with Some n -> n | None -> 0)
        done
      with Exit | End_of_file -> ());
     let body =
       if !content_length > 0 then really_input_string ic !content_length else ""
     in
     let path, query =
       match String.index_opt target '?' with
       | None -> (target, "")
       | Some idx ->
         ( String.sub target 0 idx,
           String.sub target (idx + 1) (String.length target - idx - 1) )
     in
     let status_code, content_type, resp_data =
       if path = "/" then (200, "text/plain; charset=utf-8", "Hello, World!")
       else if path = "/myapi" || path = "/myapi/" then
         let req_body =
           if meth = "POST" then body else url_decode query
         in
         let raw =
           Skir.Service.handle_request skir_service req_body !headers
         in
         (raw.status_code, raw.content_type, raw.data)
       else (404, "text/plain; charset=utf-8", "Not found")
     in
     let status_text =
       match status_code with
       | 200 -> "OK"
       | 400 -> "Bad Request"
       | 404 -> "Not Found"
       | _ -> "Internal Server Error"
     in
     Printf.fprintf oc
       "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s%!"
       status_code status_text content_type (String.length resp_data) resp_data
   with _ -> ());
  try Unix.close client_sock with _ -> ()

let () =
  let port = 8787 in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_any, port));
  Unix.listen sock 64;
  Printf.printf "Serving at http://localhost:%d\n" port;
  Printf.printf "API endpoint: http://localhost:%d/myapi\n%!" port;
  while true do
    let client_sock, _ = Unix.accept sock in
    handle_client client_sock
  done
