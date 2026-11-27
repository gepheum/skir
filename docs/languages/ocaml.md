# OCaml

This guide explains how to use Skir in an OCaml project (OCaml 4.14+ / 5.x with [Dune](https://dune.build)).

## Set up

In your `skir.yml` file, add the following snippet under `generators`:

```yaml
- mod: skir-ocaml-gen
  outDir: ./skirout
  config: {}
```

The generated OCaml code depends on the `skir_client` library (`Skir` module). Install it with `opam`:

```bash
opam pin add skir_client https://github.com/gepheum/skir-ocaml-client.git -y
```

Then add `skir_client` to your `dune` file's `libraries` stanza and include the `skirout` subdirectory:

```lisp
(include_subdirs unqualified)

(executable
 (name main)
 (libraries skir_client unix))
```

## Generated code guide

The examples below are for the code generated from `user.skir`.

### Referring to generated symbols

Each `.skir` file `path/to/my_module.skir` generates a flat OCaml module `Skirout_path__to__my_module` (`skirout_path__to__my_module.ml`). Each record (`struct` or `enum`, including nested records) is generated as a submodule inside it:

```ocaml
module User_skir = Skirout_user

(* Now you can use:
   - User_skir.User.t, User_skir.User.Pet.t
   - User_skir.SubscriptionStatus.t, User_skir.SubscriptionStatus.Trial.t
   - User_skir.tarzan_const
   - etc. *)
```

### Structs

For every struct `S` in the `.skir` file, Skir generates a submodule `S` containing:
- `type t`: an immutable OCaml record type
- `val default : t`: the default instance with all fields set to their default values
- `val make`: a labeled constructor helper (omitted fields default to their zero values)
- `val copy`: a functional update helper with optional labeled parameters
- `val serializer : unit -> t Skir.serializer`
- Any nested record submodules (e.g. `User.Pet`)

```ocaml
module User_skir = Skirout_user

(* Construct a User.t with User.make. Any omitted labeled argument defaults to its zero value. *)
let john =
  User_skir.User.make
    ~user_id:42L
    ~name:"John Doe"
    ~quote:"Coffee is just a socially acceptable form of rage."
    ~pets:[
      User_skir.User.Pet.make
        ~name:"Dumbo"
        ~height_in_meters:1.0
        ~picture:"🐘"
        ();
    ]
    ~subscription_status:User_skir.SubscriptionStatus.Free
    ()

let () = assert (john.name = "John Doe")

(* You can also specify only a subset of fields: *)
let jane =
  User_skir.User.make
    ~user_id:43L
    ~name:"Jane Doe"
    ()

(* Missing fields are initialized to their default values. *)
let () = assert (jane.quote = "")

(* User.default holds the default value with all fields set to their default values. *)
let () = assert (User_skir.User.default = User_skir.User.make ())
```

#### Creating modified copies

```ocaml
(* Option 1: use the generated User.copy function *)
let evil_john =
  User_skir.User.copy
    ~name:"Evil John"
    ~quote:"I solemnly swear I am up to no good."
    john

(* Option 2: use OCaml's native record update syntax `with` *)
let evil_john_2 =
  {
    john with
    name = "Evil John";
    quote = "I solemnly swear I am up to no good.";
  }

let () = assert (evil_john = evil_john_2)
let () = assert (evil_john.user_id = 42L)
```

### Enums

The definition of the `SubscriptionStatus` enum in the `.skir` file is:

```skir
enum SubscriptionStatus {
  free;
  trial: Trial;
  premium;
}
```

Skir generates a submodule `SubscriptionStatus` with an algebraic variant type `SubscriptionStatus.t`. The `Unknown` constructor is included automatically as the default variant.

#### Constructing enum values

```ocaml
let john_status = User_skir.SubscriptionStatus.Free
let jane_status = User_skir.SubscriptionStatus.Premium
let joly_status = User_skir.SubscriptionStatus.unknown (* Unknown None *)

(* Wrapper variants carry their payload directly *)
let roni_status =
  User_skir.SubscriptionStatus.Trial
    (User_skir.SubscriptionStatus.Trial.make
       ~start_time:(Skir.Timestamp.from_unix_millis 1744974198000L)
       ())
```

#### Pattern matching on enums

Because enums are native OCaml variant types scoped to their submodule, you get exhaustive pattern matching checked by the OCaml compiler with no constructor collisions across enums:

```ocaml
let get_subscription_info_text (status : User_skir.SubscriptionStatus.t) : string =
  match status with
  | User_skir.SubscriptionStatus.Unknown _ -> "Unknown subscription status"
  | User_skir.SubscriptionStatus.Free -> "Free user"
  | User_skir.SubscriptionStatus.Premium -> "Premium user"
  | User_skir.SubscriptionStatus.Trial trial ->
    "On trial since " ^ Skir.Timestamp.to_iso8601 trial.start_time
```

### Serialization

Every struct and enum submodule has a `serializer ()` function returning a `'a Skir.serializer`.

```ocaml
let serializer = User_skir.User.serializer ()

(* Serialize 'john' to dense JSON *)
let john_dense_json = Skir.to_dense_json_code serializer john
let () = print_endline john_dense_json
(* [42,"John Doe",...] *)

(* Serialize 'john' to readable JSON *)
let john_readable_json = Skir.to_readable_json_code serializer john
let () = print_endline john_readable_json
(* {
     "user_id": 42,
     "name": "John Doe",
     "quote": "Coffee is just a socially acceptable form of rage.",
     "pets": [
       {
         "name": "Dumbo",
         "height_in_meters": 1,
         "picture": "🐘"
       }
     ],
     "subscription_status": "free"
   } *)

(* Deserialize from JSON (both dense and readable formats are accepted) *)
let () =
  assert (Skir.from_json_code serializer john_dense_json = Ok john);
  assert (Skir.from_json_code serializer john_readable_json = Ok john)

(* Serialize to and deserialize from compact binary format *)
let john_bytes = Skir.to_bytes serializer john
let () = assert (Skir.from_bytes serializer john_bytes = Ok john)
```

#### Primitive and composite serializers

```ocaml
let () =
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

  (* Optional and list serializers *)
  let opt_str = Skir.optional_serializer Skir.string_serializer in
  assert (Skir.to_dense_json_code opt_str (Some "foo") = "\"foo\"");
  assert (Skir.to_dense_json_code opt_str None = "null");

  let bool_list = Skir.list_serializer Skir.bool_serializer in
  assert (Skir.to_dense_json_code bool_list [ true; false ] = "[1,0]")
```

### Constants

Each `const` declared in a `.skir` file (e.g. `const TARZAN: User = ...`) is generated as a top-level OCaml value named `<lower_snake_case>_const`:

```ocaml
(* Access the generated constant directly as an immutable OCaml value *)
let () =
  assert (User_skir.tarzan_const.user_id = 123L);
  assert (User_skir.tarzan_const.name = "Tarzan");
  print_endline
    (Skir.to_readable_json_code
       (User_skir.User.serializer ())
       User_skir.tarzan_const)
(* {
     "user_id": 123,
     "name": "Tarzan",
     "quote": "AAAAaAaAaAyAAAAaAaAaAyAAAAaAaAaA",
     "pets": [
       {
         "name": "Cheeta",
         "height_in_meters": 1.67,
         "picture": "🐒"
       }
     ],
     "subscription_status": {
       "kind": "trial",
       "value": {
         "start_time": {
           "unix_millis": 1743592409000,
           "formatted": "2025-04-02T11:13:29.000Z"
         }
       }
     }
   } *)
```

### SkirRPC services

**Starting a SkirRPC service on an HTTP server** - full example [here](https://github.com/gepheum/skir-ocaml-example/blob/main/src/start_service.ml).

**Sending RPCs to a SkirRPC service** - full example [here](https://github.com/gepheum/skir-ocaml-example/blob/main/src/call_service.ml).

#### Starting a SkirRPC service

```ocaml
let svc = Skir.Service.create ()

let () =
  Skir.Service.add_method svc Service_skir.get_user_method (fun req _meta ->
      Service_skir.GetUserResponse.make ~user:None ())

(* In your HTTP handler: *)
let raw_resp = Skir.Service.handle_request svc request_body request_meta
(* Write raw_resp.data with status raw_resp.status_code and Content-Type raw_resp.content_type *)
```

#### Sending RPCs with `Skir.Service_client`

```ocaml
let client = Skir.Service_client.create "http://localhost:8787/myapi"

let response =
  Skir.Service_client.invoke_remote client Service_skir.get_user_method
    (Service_skir.GetUserRequest.make ~user_id:42L ())
    ~headers:[ ("X-Foo", "hi") ]
```

### Reflection

Reflection allows you to inspect a Skir type at runtime:

```ocaml
let td = Skir.type_descriptor (User_skir.User.serializer ())
let json_code = Skir.Type_descriptor.to_json_code td
let () = print_endline json_code

(* A Type_descriptor.t can be serialized to JSON and parsed back *)
let () =
  match Skir.Type_descriptor.from_json_code json_code with
  | Ok parsed -> assert (Skir.Type_descriptor.to_json_code parsed = json_code)
  | Error msg -> failwith msg
```
