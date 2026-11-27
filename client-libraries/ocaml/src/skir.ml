(* =============================================================================
   JSON AST, Parser, and Printer
   ============================================================================= *)

module Json = struct
  type t =
    | Null
    | Bool of bool
    | Number of string
    | String of string
    | Array of t list
    | Object of (string * t) list

  let hex_digit n =
    let n = n land 0xF in
    if n < 10 then Char.chr (Char.code '0' + n)
    else Char.chr (Char.code 'a' + (n - 10))

  let append_escaped_string buf s =
    Buffer.add_char buf '"';
    for i = 0 to String.length s - 1 do
      let ch = String.unsafe_get s i in
      match ch with
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | '\b' -> Buffer.add_string buf "\\b"
      | '\012' -> Buffer.add_string buf "\\f"
      | '\n' -> Buffer.add_string buf "\\n"
      | '\r' -> Buffer.add_string buf "\\r"
      | '\t' -> Buffer.add_string buf "\\t"
      | _ ->
        let code = Char.code ch in
        if code < 0x20 then (
          Buffer.add_string buf "\\u00";
          Buffer.add_char buf (hex_digit (code lsr 4));
          Buffer.add_char buf (hex_digit code))
        else Buffer.add_char buf ch
    done;
    Buffer.add_char buf '"'

  let quote_string s =
    let buf = Buffer.create (String.length s + 4) in
    append_escaped_string buf s;
    Buffer.contents buf

  let rec write_compact buf = function
    | Null -> Buffer.add_string buf "null"
    | Bool true -> Buffer.add_string buf "true"
    | Bool false -> Buffer.add_string buf "false"
    | Number raw -> Buffer.add_string buf raw
    | String s -> append_escaped_string buf s
    | Array items ->
      Buffer.add_char buf '[';
      List.iteri
        (fun i item ->
          if i > 0 then Buffer.add_char buf ',';
          write_compact buf item)
        items;
      Buffer.add_char buf ']'
    | Object fields ->
      Buffer.add_char buf '{';
      List.iteri
        (fun i (k, v) ->
          if i > 0 then Buffer.add_char buf ',';
          append_escaped_string buf k;
          Buffer.add_char buf ':';
          write_compact buf v)
        fields;
      Buffer.add_char buf '}'

  let rec write_pretty buf indent = function
    | Null -> Buffer.add_string buf "null"
    | Bool true -> Buffer.add_string buf "true"
    | Bool false -> Buffer.add_string buf "false"
    | Number raw -> Buffer.add_string buf raw
    | String s -> append_escaped_string buf s
    | Array [] -> Buffer.add_string buf "[]"
    | Array items ->
      let inner = indent ^ "  " in
      Buffer.add_string buf "[\n";
      List.iteri
        (fun i item ->
          if i > 0 then Buffer.add_string buf ",\n";
          Buffer.add_string buf inner;
          write_pretty buf inner item)
        items;
      Buffer.add_char buf '\n';
      Buffer.add_string buf indent;
      Buffer.add_char buf ']'
    | Object [] -> Buffer.add_string buf "{}"
    | Object fields ->
      let inner = indent ^ "  " in
      Buffer.add_string buf "{\n";
      List.iteri
        (fun i (k, v) ->
          if i > 0 then Buffer.add_string buf ",\n";
          Buffer.add_string buf inner;
          append_escaped_string buf k;
          Buffer.add_string buf ": ";
          write_pretty buf inner v)
        fields;
      Buffer.add_char buf '\n';
      Buffer.add_string buf indent;
      Buffer.add_char buf '}'

  let to_string ?(pretty = false) v =
    let buf = Buffer.create 128 in
    if pretty then write_pretty buf "" v else write_compact buf v;
    Buffer.contents buf

  exception Parse_error of string

  let is_ws = function ' ' | '\t' | '\n' | '\r' -> true | _ -> false

  let skip_ws s len idx =
    let i = ref idx in
    while !i < len && is_ws (String.unsafe_get s !i) do
      incr i
    done;
    !i

  let hex_val ch =
    match ch with
    | '0' .. '9' -> Char.code ch - Char.code '0'
    | 'a' .. 'f' -> Char.code ch - Char.code 'a' + 10
    | 'A' .. 'F' -> Char.code ch - Char.code 'A' + 10
    | _ -> raise (Parse_error "invalid hex digit in JSON string")

  let parse_hex4 s idx =
    if idx + 4 > String.length s then
      raise (Parse_error "unexpected end of input in \\u escape");
    let h0 = hex_val (String.unsafe_get s idx) in
    let h1 = hex_val (String.unsafe_get s (idx + 1)) in
    let h2 = hex_val (String.unsafe_get s (idx + 2)) in
    let h3 = hex_val (String.unsafe_get s (idx + 3)) in
    (h0 lsl 12) lor (h1 lsl 8) lor (h2 lsl 4) lor h3

  let add_utf8_scalar buf cp =
    if cp <= 0x7F then Buffer.add_char buf (Char.chr cp)
    else if cp <= 0x7FF then (
      Buffer.add_char buf (Char.chr (0xC0 lor (cp lsr 6)));
      Buffer.add_char buf (Char.chr (0x80 lor (cp land 0x3F))))
    else if cp <= 0xFFFF then (
      Buffer.add_char buf (Char.chr (0xE0 lor (cp lsr 12)));
      Buffer.add_char buf (Char.chr (0x80 lor ((cp lsr 6) land 0x3F)));
      Buffer.add_char buf (Char.chr (0x80 lor (cp land 0x3F))))
    else (
      Buffer.add_char buf (Char.chr (0xF0 lor (cp lsr 18)));
      Buffer.add_char buf (Char.chr (0x80 lor ((cp lsr 12) land 0x3F)));
      Buffer.add_char buf (Char.chr (0x80 lor ((cp lsr 6) land 0x3F)));
      Buffer.add_char buf (Char.chr (0x80 lor (cp land 0x3F))))

  let parse_string s len idx =
    (* idx points at opening '"' *)
    let buf = Buffer.create 32 in
    let i = ref (idx + 1) in
    let done_flag = ref false in
    while not !done_flag do
      if !i >= len then raise (Parse_error "unterminated JSON string");
      let ch = String.unsafe_get s !i in
      incr i;
      match ch with
      | '"' -> done_flag := true
      | '\\' -> (
        if !i >= len then raise (Parse_error "unterminated escape in JSON string");
        let esc = String.unsafe_get s !i in
        incr i;
        match esc with
        | '"' -> Buffer.add_char buf '"'
        | '\\' -> Buffer.add_char buf '\\'
        | '/' -> Buffer.add_char buf '/'
        | 'b' -> Buffer.add_char buf '\b'
        | 'f' -> Buffer.add_char buf '\012'
        | 'n' -> Buffer.add_char buf '\n'
        | 'r' -> Buffer.add_char buf '\r'
        | 't' -> Buffer.add_char buf '\t'
        | 'u' ->
          let cp1 = parse_hex4 s !i in
          i := !i + 4;
          if
            cp1 >= 0xD800 && cp1 <= 0xDBFF && !i + 6 <= len
            && String.unsafe_get s !i = '\\'
            && String.unsafe_get s (!i + 1) = 'u'
          then (
            let cp2 = parse_hex4 s (!i + 2) in
            if cp2 >= 0xDC00 && cp2 <= 0xDFFF then (
              i := !i + 6;
              let full_cp =
                0x10000 + (((cp1 - 0xD800) lsl 10) lor (cp2 - 0xDC00))
              in
              add_utf8_scalar buf full_cp)
            else add_utf8_scalar buf 0xFFFD)
          else add_utf8_scalar buf cp1
        | _ -> raise (Parse_error "invalid escape character in JSON string"))
      | c -> Buffer.add_char buf c
    done;
    (Buffer.contents buf, !i)

  let parse_number s len idx =
    let i = ref idx in
    if !i < len && String.unsafe_get s !i = '-' then incr i;
    if !i >= len then raise (Parse_error "invalid JSON number");
    let c0 = String.unsafe_get s !i in
    if c0 = '0' then incr i
    else if c0 >= '1' && c0 <= '9' then (
      incr i;
      while
        !i < len
        &&
        let c = String.unsafe_get s !i in
        c >= '0' && c <= '9'
      do
        incr i
      done)
    else raise (Parse_error "invalid JSON number");
    if !i < len && String.unsafe_get s !i = '.' then (
      incr i;
      if
        !i >= len
        ||
        let c = String.unsafe_get s !i in
        c < '0' || c > '9'
      then raise (Parse_error "invalid fraction in JSON number");
      while
        !i < len
        &&
        let c = String.unsafe_get s !i in
        c >= '0' && c <= '9'
      do
        incr i
      done);
    if
      !i < len
      &&
      let c = String.unsafe_get s !i in
      c = 'e' || c = 'E'
    then (
      incr i;
      if
        !i < len
        &&
        let c = String.unsafe_get s !i in
        c = '+' || c = '-'
      then incr i;
      if
        !i >= len
        ||
        let c = String.unsafe_get s !i in
        c < '0' || c > '9'
      then raise (Parse_error "invalid exponent in JSON number");
      while
        !i < len
        &&
        let c = String.unsafe_get s !i in
        c >= '0' && c <= '9'
      do
        incr i
      done);
    (Number (String.sub s idx (!i - idx)), !i)

  let rec parse_value s len idx =
    let i = skip_ws s len idx in
    if i >= len then raise (Parse_error "unexpected end of JSON");
    match String.unsafe_get s i with
    | 'n' ->
      if i + 4 <= len && String.sub s i 4 = "null" then (Null, i + 4)
      else raise (Parse_error "invalid JSON literal")
    | 't' ->
      if i + 4 <= len && String.sub s i 4 = "true" then (Bool true, i + 4)
      else raise (Parse_error "invalid JSON literal")
    | 'f' ->
      if i + 5 <= len && String.sub s i 5 = "false" then (Bool false, i + 5)
      else raise (Parse_error "invalid JSON literal")
    | '"' ->
      let str, next = parse_string s len i in
      (String str, next)
    | '[' -> parse_array s len (i + 1)
    | '{' -> parse_object s len (i + 1)
    | '-' | '0' .. '9' -> parse_number s len i
    | c -> raise (Parse_error (Printf.sprintf "unexpected character '%c'" c))

  and parse_array s len idx =
    let i = skip_ws s len idx in
    if i < len && String.unsafe_get s i = ']' then (Array [], i + 1)
    else
      let acc = ref [] in
      let cur = ref i in
      let done_flag = ref false in
      while not !done_flag do
        let v, next = parse_value s len !cur in
        acc := v :: !acc;
        let next = skip_ws s len next in
        if next >= len then raise (Parse_error "unterminated JSON array");
        match String.unsafe_get s next with
        | ',' -> cur := next + 1
        | ']' ->
          cur := next + 1;
          done_flag := true
        | _ -> raise (Parse_error "expected ',' or ']' in JSON array")
      done;
      (Array (List.rev !acc), !cur)

  and parse_object s len idx =
    let i = skip_ws s len idx in
    if i < len && String.unsafe_get s i = '}' then (Object [], i + 1)
    else
      let acc = ref [] in
      let cur = ref i in
      let done_flag = ref false in
      while not !done_flag do
        let k_start = skip_ws s len !cur in
        if k_start >= len || String.unsafe_get s k_start <> '"' then
          raise (Parse_error "expected string key in JSON object");
        let key, after_key = parse_string s len k_start in
        let colon = skip_ws s len after_key in
        if colon >= len || String.unsafe_get s colon <> ':' then
          raise (Parse_error "expected ':' after key in JSON object");
        let v, next = parse_value s len (colon + 1) in
        acc := (key, v) :: !acc;
        let next = skip_ws s len next in
        if next >= len then raise (Parse_error "unterminated JSON object");
        match String.unsafe_get s next with
        | ',' -> cur := next + 1
        | '}' ->
          cur := next + 1;
          done_flag := true
        | _ -> raise (Parse_error "expected ',' or '}' in JSON object")
      done;
      (Object (List.rev !acc), !cur)

  let parse code =
    let len = String.length code in
    try
      let v, next = parse_value code len 0 in
      let end_idx = skip_ws code len next in
      if end_idx <> len then Error "trailing characters after JSON value"
      else Ok v
    with Parse_error msg -> Error ("invalid JSON: " ^ msg)

  let rec equal a b =
    match (a, b) with
    | Null, Null -> true
    | Bool x, Bool y -> x = y
    | Number x, Number y -> (
      if x = y then true
      else
        match (float_of_string_opt x, float_of_string_opt y) with
        | Some fx, Some fy -> fx = fy
        | _ -> false)
    | String x, String y -> x = y
    | Array xs, Array ys ->
      List.length xs = List.length ys && List.for_all2 equal xs ys
    | Object xs, Object ys ->
      List.length xs = List.length ys
      && List.for_all
           (fun (k, vx) ->
             match List.assoc_opt k ys with
             | Some vy -> equal vx vy
             | None -> false)
           xs
    | _ -> false
end

(* =============================================================================
   Timestamp
   ============================================================================= *)

module Timestamp = struct
  type t = { unix_millis : int64 }

  let min_unix_millis = -8640000000000000L
  let max_unix_millis = 8640000000000000L

  let clamp_millis ms =
    if Int64.compare ms min_unix_millis < 0 then min_unix_millis
    else if Int64.compare ms max_unix_millis > 0 then max_unix_millis
    else ms

  let from_unix_millis ms = { unix_millis = clamp_millis ms }

  let from_unix_seconds s =
    from_unix_millis (Int64.of_float (Float.round (s *. 1000.0)))

  let unix_epoch = { unix_millis = 0L }
  let min = { unix_millis = min_unix_millis }
  let max = { unix_millis = max_unix_millis }
  let unix_millis t = t.unix_millis
  let unix_seconds t = Int64.to_float t.unix_millis /. 1000.0
  let equal a b = Int64.equal a.unix_millis b.unix_millis
  let compare a b = Int64.compare a.unix_millis b.unix_millis

  let div_euclid a b =
    let q = Int64.div a b in
    let r = Int64.rem a b in
    if Int64.compare r 0L < 0 then
      if Int64.compare b 0L > 0 then Int64.sub q 1L else Int64.add q 1L
    else q

  let rem_euclid a b = Int64.sub a (Int64.mul (div_euclid a b) b)

  let zero_pad n width =
    let s = Int.to_string n in
    let len = String.length s in
    if len >= width then s else String.make (width - len) '0' ^ s

  let to_iso8601 t =
    let ms = clamp_millis t.unix_millis in
    let millis_part = Int64.to_int (rem_euclid ms 1000L) in
    let secs = div_euclid ms 1000L in
    let time_of_day = rem_euclid secs 86400L in
    let h = Int64.to_int (Int64.div time_of_day 3600L) in
    let mi = Int64.to_int (Int64.div (Int64.rem time_of_day 3600L) 60L) in
    let s = Int64.to_int (Int64.rem time_of_day 60L) in
    let days = div_euclid secs 86400L in
    let z = Int64.add days 719468L in
    let era = div_euclid z 146097L in
    let doe = Int64.sub z (Int64.mul era 146097L) in
    let yoe =
      div_euclid
        (Int64.sub
           (Int64.add (Int64.sub doe (div_euclid doe 1460L)) (div_euclid doe 36524L))
           (div_euclid doe 146096L))
        365L
    in
    let y = Int64.add yoe (Int64.mul era 400L) in
    let doy =
      Int64.sub doe
        (Int64.sub
           (Int64.add (Int64.mul 365L yoe) (div_euclid yoe 4L))
           (div_euclid yoe 100L))
    in
    let mp = div_euclid (Int64.add (Int64.mul 5L doy) 2L) 153L in
    let d =
      Int64.to_int
        (Int64.add
           (Int64.sub doy (div_euclid (Int64.add (Int64.mul 153L mp) 2L) 5L))
           1L)
    in
    let m =
      if Int64.compare mp 10L < 0 then Int64.to_int (Int64.add mp 3L)
      else Int64.to_int (Int64.sub mp 9L)
    in
    let y_final = if m <= 2 then Int64.add y 1L else y in
    let y_str =
      if Int64.compare y_final 0L >= 0 then zero_pad (Int64.to_int y_final) 4
      else Int64.to_string y_final
    in
    Printf.sprintf "%s-%s-%sT%s:%s:%s.%sZ" y_str (zero_pad m 2) (zero_pad d 2)
      (zero_pad h 2) (zero_pad mi 2) (zero_pad s 2) (zero_pad millis_part 3)
end

(* =============================================================================
   Recursive field wrapper & Unrecognized data
   ============================================================================= *)

type 'a recursive =
  | Default
  | Value of 'a

type unrecognized_format =
  | Unrecognized_dense_json of Json.t
  | Unrecognized_bytes of string

type unrecognized_fields = {
  uf_format : unrecognized_format;
  uf_array_len : int;
}

type unrecognized_variant = {
  uv_format : unrecognized_format;
  uv_number : int;
}

type unrecognized_values =
  | Drop
  | Keep

(* =============================================================================
   TypeDescriptor (Reflection)
   ============================================================================= *)

module Type_descriptor = struct
  type primitive_type =
    | Bool
    | Int32
    | Int64
    | Hash64
    | Float32
    | Float64
    | Timestamp
    | String
    | Bytes

  type type_signature =
    | Primitive of primitive_type
    | Optional of type_signature
    | Array of { item_type : type_signature; key_extractor : string }
    | Record of string

  type struct_field = {
    name : string;
    number : int;
    field_type : type_signature;
    doc : string;
  }

  type enum_constant_variant = {
    name : string;
    number : int;
    doc : string;
  }

  type enum_wrapper_variant = {
    name : string;
    number : int;
    variant_type : type_signature;
    doc : string;
  }

  type enum_variant =
    | Constant of enum_constant_variant
    | Wrapper of enum_wrapper_variant

  type struct_record_descriptor = {
    record_id : string;
    doc : string;
    fields : struct_field list;
    removed_numbers : int list;
  }

  type enum_record_descriptor = {
    record_id : string;
    doc : string;
    variants : enum_variant list;
    removed_numbers : int list;
  }

  type record_descriptor =
    | Struct of struct_record_descriptor
    | Enum of enum_record_descriptor

  type t = {
    root_type : type_signature;
    records : record_descriptor list;
  }

  let primitive_to_string = function
    | Bool -> "bool"
    | Int32 -> "int32"
    | Int64 -> "int64"
    | Hash64 -> "hash64"
    | Float32 -> "float32"
    | Float64 -> "float64"
    | Timestamp -> "timestamp"
    | String -> "string"
    | Bytes -> "bytes"

  let parse_primitive = function
    | "bool" -> Ok Bool
    | "int32" -> Ok Int32
    | "int64" -> Ok Int64
    | "hash64" -> Ok Hash64
    | "float32" -> Ok Float32
    | "float64" -> Ok Float64
    | "timestamp" -> Ok Timestamp
    | "string" -> Ok String
    | "bytes" -> Ok Bytes
    | s -> Error ("unknown primitive type: " ^ s)

  let rec type_signature_to_json = function
    | Primitive p ->
      Json.Object
        [
          ("kind", Json.String "primitive");
          ("value", Json.String (primitive_to_string p));
        ]
    | Optional inner ->
      Json.Object
        [
          ("kind", Json.String "optional");
          ("value", type_signature_to_json inner);
        ]
    | Array { item_type; key_extractor } ->
      let value_fields =
        ("item", type_signature_to_json item_type)
        ::
        (if key_extractor = "" then []
         else [ ("key_extractor", Json.String key_extractor) ])
      in
      Json.Object [ ("kind", Json.String "array"); ("value", Json.Object value_fields) ]
    | Record record_id ->
      Json.Object
        [ ("kind", Json.String "record"); ("value", Json.String record_id) ]

  let struct_field_to_json (f : struct_field) =
    let base =
      [
        ("name", Json.String f.name);
        ("number", Json.Number (Int.to_string f.number));
        ("type", type_signature_to_json f.field_type);
      ]
    in
    let fields =
      if f.doc = "" then base else base @ [ ("doc", Json.String f.doc) ]
    in
    Json.Object fields

  let enum_variant_to_json = function
    | Constant (c : enum_constant_variant) ->
      let base =
        [
          ("name", Json.String c.name);
          ("number", Json.Number (Int.to_string c.number));
        ]
      in
      let fields =
        if c.doc = "" then base else base @ [ ("doc", Json.String c.doc) ]
      in
      Json.Object fields
    | Wrapper (w : enum_wrapper_variant) ->
      let base =
        [
          ("name", Json.String w.name);
          ("number", Json.Number (Int.to_string w.number));
          ("type", type_signature_to_json w.variant_type);
        ]
      in
      let fields =
        if w.doc = "" then base else base @ [ ("doc", Json.String w.doc) ]
      in
      Json.Object fields

  let record_to_json = function
    | Struct s ->
      let fields =
        [ ("kind", Json.String "struct"); ("id", Json.String s.record_id) ]
        @ (if s.doc = "" then [] else [ ("doc", Json.String s.doc) ])
        @ [ ("fields", Json.Array (List.map struct_field_to_json s.fields)) ]
        @
        if s.removed_numbers = [] then []
        else
          [
            ( "removed_numbers",
              Json.Array
                (List.map
                   (fun n -> Json.Number (Int.to_string n))
                   s.removed_numbers) );
          ]
      in
      Json.Object fields
    | Enum e ->
      let fields =
        [ ("kind", Json.String "enum"); ("id", Json.String e.record_id) ]
        @ (if e.doc = "" then [] else [ ("doc", Json.String e.doc) ])
        @ [ ("variants", Json.Array (List.map enum_variant_to_json e.variants)) ]
        @
        if e.removed_numbers = [] then []
        else
          [
            ( "removed_numbers",
              Json.Array
                (List.map
                   (fun n -> Json.Number (Int.to_string n))
                   e.removed_numbers) );
          ]
      in
      Json.Object fields

  let to_json td =
    Json.Object
      [
        ("type", type_signature_to_json td.root_type);
        ("records", Json.Array (List.map record_to_json td.records));
      ]

  (* Matches the exact formatting of golden type descriptors *)
  let rec type_signature_to_json_code sig_t indent =
    let inner = indent ^ "  " in
    match sig_t with
    | Primitive p ->
      Printf.sprintf "{\n%s\"kind\": \"primitive\",\n%s\"value\": %s\n%s}" inner
        inner
        (Json.quote_string (primitive_to_string p))
        indent
    | Optional other ->
      Printf.sprintf "{\n%s\"kind\": \"optional\",\n%s\"value\": %s\n%s}" inner
        inner
        (type_signature_to_json_code other inner)
        indent
    | Array { item_type; key_extractor } ->
      let value_indent = inner ^ "  " in
      let item_line =
        Printf.sprintf "%s\"item\": %s" value_indent
          (type_signature_to_json_code item_type value_indent)
      in
      let lines =
        if key_extractor = "" then [ item_line ]
        else
          [
            item_line;
            Printf.sprintf "%s\"key_extractor\": %s" value_indent
              (Json.quote_string key_extractor);
          ]
      in
      Printf.sprintf
        "{\n%s\"kind\": \"array\",\n%s\"value\": {\n%s\n%s}\n%s}" inner inner
        (String.concat ",\n" lines)
        inner indent
    | Record record_id ->
      Printf.sprintf "{\n%s\"kind\": \"record\",\n%s\"value\": %s\n%s}" inner
        inner
        (Json.quote_string record_id)
        indent

  let struct_field_to_json_code (f : struct_field) indent =
    let inner = indent ^ "  " in
    let lines =
      [
        Printf.sprintf "%s\"name\": %s" inner (Json.quote_string f.name);
        Printf.sprintf "%s\"number\": %d" inner f.number;
        Printf.sprintf "%s\"type\": %s" inner
          (type_signature_to_json_code f.field_type inner);
      ]
      @
      if f.doc = "" then []
      else [ Printf.sprintf "%s\"doc\": %s" inner (Json.quote_string f.doc) ]
    in
    Printf.sprintf "{\n%s\n%s}" (String.concat ",\n" lines) indent

  let enum_variant_to_json_code (v : enum_variant) indent =
    let inner = indent ^ "  " in
    match v with
    | Constant c ->
      let lines =
        [
          Printf.sprintf "%s\"name\": %s" inner (Json.quote_string c.name);
          Printf.sprintf "%s\"number\": %d" inner c.number;
        ]
        @
        if c.doc = "" then []
        else [ Printf.sprintf "%s\"doc\": %s" inner (Json.quote_string c.doc) ]
      in
      Printf.sprintf "{\n%s\n%s}" (String.concat ",\n" lines) indent
    | Wrapper w ->
      let lines =
        [
          Printf.sprintf "%s\"name\": %s" inner (Json.quote_string w.name);
          Printf.sprintf "%s\"number\": %d" inner w.number;
          Printf.sprintf "%s\"type\": %s" inner
            (type_signature_to_json_code w.variant_type inner);
        ]
        @
        if w.doc = "" then []
        else [ Printf.sprintf "%s\"doc\": %s" inner (Json.quote_string w.doc) ]
      in
      Printf.sprintf "{\n%s\n%s}" (String.concat ",\n" lines) indent

  let record_to_json_code r indent =
    let inner = indent ^ "  " in
    match r with
    | Struct s ->
      let fields_code =
        if s.fields = [] then "[]"
        else
          let parts =
            List.map
              (fun f ->
                inner ^ "  " ^ struct_field_to_json_code f (inner ^ "  "))
              s.fields
          in
          Printf.sprintf "[\n%s\n%s]" (String.concat ",\n" parts) inner
      in
      let lines =
        [
          Printf.sprintf "%s\"kind\": \"struct\"" inner;
          Printf.sprintf "%s\"id\": %s" inner (Json.quote_string s.record_id);
        ]
        @ (if s.doc = "" then []
           else
             [ Printf.sprintf "%s\"doc\": %s" inner (Json.quote_string s.doc) ])
        @ [ Printf.sprintf "%s\"fields\": %s" inner fields_code ]
        @
        if s.removed_numbers = [] then []
        else
          let rem_lines =
            List.map
              (fun n -> Printf.sprintf "%s  %d" inner n)
              s.removed_numbers
          in
          [
            Printf.sprintf "%s\"removed_numbers\": [\n%s\n%s]" inner
              (String.concat ",\n" rem_lines)
              inner;
          ]
      in
      Printf.sprintf "{\n%s\n%s}" (String.concat ",\n" lines) indent
    | Enum e ->
      let variants_code =
        if e.variants = [] then "[]"
        else
          let parts =
            List.map
              (fun v ->
                inner ^ "  " ^ enum_variant_to_json_code v (inner ^ "  "))
              e.variants
          in
          Printf.sprintf "[\n%s\n%s]" (String.concat ",\n" parts) inner
      in
      let lines =
        [
          Printf.sprintf "%s\"kind\": \"enum\"" inner;
          Printf.sprintf "%s\"id\": %s" inner (Json.quote_string e.record_id);
        ]
        @ (if e.doc = "" then []
           else
             [ Printf.sprintf "%s\"doc\": %s" inner (Json.quote_string e.doc) ])
        @ [ Printf.sprintf "%s\"variants\": %s" inner variants_code ]
        @
        if e.removed_numbers = [] then []
        else
          let rem_lines =
            List.map
              (fun n -> Printf.sprintf "%s  %d" inner n)
              e.removed_numbers
          in
          [
            Printf.sprintf "%s\"removed_numbers\": [\n%s\n%s]" inner
              (String.concat ",\n" rem_lines)
              inner;
          ]
      in
      Printf.sprintf "{\n%s\n%s}" (String.concat ",\n" lines) indent

  let to_json_code td =
    let type_code = type_signature_to_json_code td.root_type "  " in
    let records_code =
      if td.records = [] then "[]"
      else
        let parts =
          List.map (fun r -> "    " ^ record_to_json_code r "    ") td.records
        in
        Printf.sprintf "[\n%s\n  ]" (String.concat ",\n" parts)
    in
    Printf.sprintf "{\n  \"type\": %s,\n  \"records\": %s\n}" type_code
      records_code

  let get_field obj key =
    match obj with Json.Object pairs -> List.assoc_opt key pairs | _ -> None

  let get_string obj key =
    match get_field obj key with
    | Some (Json.String s) -> Ok s
    | _ -> Error ("missing or invalid string field '" ^ key ^ "'")

  let get_opt_string obj key =
    match get_field obj key with Some (Json.String s) -> s | _ -> ""

  let get_int obj key =
    match get_field obj key with
    | Some (Json.Number raw) -> (
      match int_of_string_opt raw with
      | Some n -> Ok n
      | None -> Error ("invalid integer in '" ^ key ^ "'"))
    | _ -> Error ("missing or invalid integer field '" ^ key ^ "'")

  let get_int_list obj key =
    match get_field obj key with
    | None -> Ok []
    | Some (Json.Array items) ->
      let rec loop acc = function
        | [] -> Ok (List.rev acc)
        | Json.Number raw :: rest -> (
          match int_of_string_opt raw with
          | Some n -> loop (n :: acc) rest
          | None -> Error "invalid integer in array")
        | _ -> Error "expected integer in array"
      in
      loop [] items
    | _ -> Error ("field '" ^ key ^ "' must be an array")

  let rec parse_type_signature json =
    match (get_string json "kind", get_field json "value") with
    | Error e, _ -> Error e
    | _, None -> Error "type signature missing 'value'"
    | Ok "primitive", Some (Json.String p_name) -> (
      match parse_primitive p_name with
      | Ok p -> Ok (Primitive p)
      | Error e -> Error e)
    | Ok "optional", Some v -> (
      match parse_type_signature v with
      | Ok inner -> Ok (Optional inner)
      | Error e -> Error e)
    | Ok "array", Some v -> (
      match get_field v "item" with
      | None -> Error "array signature missing 'item'"
      | Some item_json -> (
        match parse_type_signature item_json with
        | Ok item_type ->
          let key_extractor = get_opt_string v "key_extractor" in
          Ok (Array { item_type; key_extractor })
        | Error e -> Error e))
    | Ok "record", Some (Json.String record_id) -> Ok (Record record_id)
    | Ok k, _ -> Error ("invalid type signature kind: " ^ k)

  let parse_record json =
    match (get_string json "kind", get_string json "id") with
    | Error e, _ | _, Error e -> Error e
    | Ok kind, Ok record_id -> (
      let doc = get_opt_string json "doc" in
      match get_int_list json "removed_numbers" with
      | Error e -> Error e
      | Ok removed_numbers ->
        if kind = "struct" then
          match get_field json "fields" with
          | Some (Json.Array f_jsons) ->
            let rec loop acc = function
              | [] ->
                Ok
                  (Struct
                     {
                       record_id;
                       doc;
                       fields = List.rev acc;
                       removed_numbers;
                     })
              | f :: rest -> (
                match
                  (get_string f "name", get_int f "number", get_field f "type")
                with
                | Ok name, Ok number, Some t_json -> (
                  match parse_type_signature t_json with
                  | Ok field_type ->
                    let f_doc = get_opt_string f "doc" in
                    loop
                      ({ name; number; field_type; doc = f_doc } :: acc)
                      rest
                  | Error e -> Error e)
                | _ -> Error "invalid struct field descriptor")
            in
            loop [] f_jsons
          | _ -> Error "struct descriptor missing 'fields'"
        else if kind = "enum" then
          match get_field json "variants" with
          | Some (Json.Array v_jsons) ->
            let rec loop acc = function
              | [] ->
                Ok
                  (Enum
                     {
                       record_id;
                       doc;
                       variants = List.rev acc;
                       removed_numbers;
                     })
              | v :: rest -> (
                match (get_string v "name", get_int v "number") with
                | Ok name, Ok number -> (
                  let v_doc = get_opt_string v "doc" in
                  match get_field v "type" with
                  | None ->
                    loop (Constant { name; number; doc = v_doc } :: acc) rest
                  | Some t_json -> (
                    match parse_type_signature t_json with
                    | Ok variant_type ->
                      loop
                        (Wrapper { name; number; variant_type; doc = v_doc }
                        :: acc)
                        rest
                    | Error e -> Error e))
                | _ -> Error "invalid enum variant descriptor")
            in
            loop [] v_jsons
          | _ -> Error "enum descriptor missing 'variants'"
        else Error ("unknown record kind: " ^ kind))

  let from_json json =
    match get_field json "type" with
    | None -> Error "type descriptor missing 'type'"
    | Some t_json -> (
      match parse_type_signature t_json with
      | Error e -> Error e
      | Ok root_type -> (
        match get_field json "records" with
        | None -> Ok { root_type; records = [] }
        | Some (Json.Array r_jsons) ->
          let rec loop acc = function
            | [] -> Ok { root_type; records = List.rev acc }
            | r :: rest -> (
              match parse_record r with
              | Ok rd -> loop (rd :: acc) rest
              | Error e -> Error e)
          in
          loop [] r_jsons
        | _ -> Error "'records' must be an array"))

  let from_json_code code =
    match Json.parse code with
    | Error e -> Error e
    | Ok json -> from_json json
end

(* =============================================================================
   Base64 & Hex Helpers
   ============================================================================= *)

module Base64 = struct
  let alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

  let encode s =
    let len = String.length s in
    if len = 0 then ""
    else
      let buf = Buffer.create ((len + 2) / 3 * 4) in
      let i = ref 0 in
      while !i + 3 <= len do
        let b0 = Char.code (String.unsafe_get s !i) in
        let b1 = Char.code (String.unsafe_get s (!i + 1)) in
        let b2 = Char.code (String.unsafe_get s (!i + 2)) in
        let n = (b0 lsl 16) lor (b1 lsl 8) lor b2 in
        Buffer.add_char buf (String.unsafe_get alphabet ((n lsr 18) land 63));
        Buffer.add_char buf (String.unsafe_get alphabet ((n lsr 12) land 63));
        Buffer.add_char buf (String.unsafe_get alphabet ((n lsr 6) land 63));
        Buffer.add_char buf (String.unsafe_get alphabet (n land 63));
        i := !i + 3
      done;
      let rem = len - !i in
      if rem = 1 then (
        let b0 = Char.code (String.unsafe_get s !i) in
        let n = b0 lsl 16 in
        Buffer.add_char buf (String.unsafe_get alphabet ((n lsr 18) land 63));
        Buffer.add_char buf (String.unsafe_get alphabet ((n lsr 12) land 63));
        Buffer.add_char buf '=';
        Buffer.add_char buf '=')
      else if rem = 2 then (
        let b0 = Char.code (String.unsafe_get s !i) in
        let b1 = Char.code (String.unsafe_get s (!i + 1)) in
        let n = (b0 lsl 16) lor (b1 lsl 8) in
        Buffer.add_char buf (String.unsafe_get alphabet ((n lsr 18) land 63));
        Buffer.add_char buf (String.unsafe_get alphabet ((n lsr 12) land 63));
        Buffer.add_char buf (String.unsafe_get alphabet ((n lsr 6) land 63));
        Buffer.add_char buf '=');
      Buffer.contents buf

  let decode_char = function
    | 'A' .. 'Z' as c -> Char.code c - Char.code 'A'
    | 'a' .. 'z' as c -> Char.code c - Char.code 'a' + 26
    | '0' .. '9' as c -> Char.code c - Char.code '0' + 52
    | '+' | '-' -> 62
    | '/' | '_' -> 63
    | _ -> -1

  let decode s =
    let len = String.length s in
    let buf = Buffer.create (len * 3 / 4) in
    let acc = ref 0 in
    let bits = ref 0 in
    let err = ref false in
    for i = 0 to len - 1 do
      let c = String.unsafe_get s i in
      if c = '=' || c = ' ' || c = '\n' || c = '\r' || c = '\t' then ()
      else
        let v = decode_char c in
        if v < 0 then err := true
        else (
          acc := (!acc lsl 6) lor v;
          bits := !bits + 6;
          if !bits >= 8 then (
            bits := !bits - 8;
            Buffer.add_char buf (Char.chr ((!acc lsr !bits) land 0xFF))))
    done;
    if !err then Error "invalid base64" else Ok (Buffer.contents buf)
end

module Hex = struct
  let encode s =
    let len = String.length s in
    let buf = Buffer.create (len * 2) in
    for i = 0 to len - 1 do
      let b = Char.code (String.unsafe_get s i) in
      Buffer.add_char buf (Json.hex_digit (b lsr 4));
      Buffer.add_char buf (Json.hex_digit (b land 0xF))
    done;
    Buffer.contents buf

  let hex_nibble = function
    | '0' .. '9' as c -> Char.code c - Char.code '0'
    | 'a' .. 'f' as c -> Char.code c - Char.code 'a' + 10
    | 'A' .. 'F' as c -> Char.code c - Char.code 'A' + 10
    | _ -> -1

  let decode s =
    let len = String.length s in
    if len mod 2 <> 0 then Error "odd length hex string"
    else
      let buf = Buffer.create (len / 2) in
      let i = ref 0 in
      let err = ref false in
      while !i < len && not !err do
        let h = hex_nibble (String.unsafe_get s !i) in
        let l = hex_nibble (String.unsafe_get s (!i + 1)) in
        if h < 0 || l < 0 then err := true
        else Buffer.add_char buf (Char.chr ((h lsl 4) lor l));
        i := !i + 2
      done;
      if !err then Error "invalid hex character" else Ok (Buffer.contents buf)
end

(* =============================================================================
   UTF-8 Scrubbing (replace invalid UTF-8 sequences with U+FFFD)
   ============================================================================= *)

let scrub_utf8 s =
  let len = String.length s in
  let buf = Buffer.create len in
  let i = ref 0 in
  let add_replacement () = Buffer.add_string buf "\xEF\xBF\xBD" in
  let is_cont idx =
    idx < len && Char.code (String.unsafe_get s idx) land 0xC0 = 0x80
  in
  while !i < len do
    let b0 = Char.code (String.unsafe_get s !i) in
    if b0 < 0x80 then (
      Buffer.add_char buf (Char.chr b0);
      incr i)
    else if b0 >= 0xC2 && b0 <= 0xDF then
      if is_cont (!i + 1) then (
        Buffer.add_substring buf s !i 2;
        i := !i + 2)
      else (
        add_replacement ();
        incr i)
    else if b0 >= 0xE0 && b0 <= 0xEF then
      if is_cont (!i + 1) && is_cont (!i + 2) then
        let b1 = Char.code (String.unsafe_get s (!i + 1)) in
        if (b0 = 0xE0 && b1 < 0xA0) || (b0 = 0xED && b1 >= 0xA0) then (
          add_replacement ();
          incr i)
        else (
          Buffer.add_substring buf s !i 3;
          i := !i + 3)
      else (
        add_replacement ();
        incr i)
    else if b0 >= 0xF0 && b0 <= 0xF4 then
      if is_cont (!i + 1) && is_cont (!i + 2) && is_cont (!i + 3) then
        let b1 = Char.code (String.unsafe_get s (!i + 1)) in
        if (b0 = 0xF0 && b1 < 0x90) || (b0 = 0xF4 && b1 >= 0x90) then (
          add_replacement ();
          incr i)
        else (
          Buffer.add_substring buf s !i 4;
          i := !i + 4)
      else (
        add_replacement ();
        incr i)
    else (
      add_replacement ();
      incr i)
  done;
  Buffer.contents buf

(* =============================================================================
   Binary Wire Encoding / Decoding Helpers
   ============================================================================= *)

module Binary = struct
  type stream = {
    data : string;
    mutable pos : int;
    len : int;
  }

  exception Decode_error of string

  let make_stream data pos = { data; pos; len = String.length data }

  let read_byte st =
    if st.pos >= st.len then raise (Decode_error "unexpected EOF");
    let b = Char.code (String.unsafe_get st.data st.pos) in
    st.pos <- st.pos + 1;
    b

  let peek_byte st =
    if st.pos >= st.len then raise (Decode_error "unexpected EOF");
    Char.code (String.unsafe_get st.data st.pos)

  let read_bytes st n =
    if n < 0 || st.pos + n > st.len then raise (Decode_error "unexpected EOF");
    let s = String.sub st.data st.pos n in
    st.pos <- st.pos + n;
    s

  let write_byte buf b = Buffer.add_char buf (Char.chr (b land 0xFF))

  let write_u16_le buf v =
    write_byte buf v;
    write_byte buf (v lsr 8)

  let write_u32_le buf (v : int32) =
    let i = Int32.to_int v in
    write_byte buf i;
    write_byte buf (i lsr 8);
    write_byte buf (i lsr 16);
    write_byte buf (Int32.to_int (Int32.shift_right_logical v 24))

  let write_i64_le buf (v : int64) =
    for shift = 0 to 7 do
      let b =
        Int64.to_int (Int64.shift_right_logical v (shift * 8)) land 0xFF
      in
      write_byte buf b
    done

  let encode_int32 (v : int32) buf =
    if Int32.compare v (-65536l) < 0 then (
      write_byte buf 237;
      write_u32_le buf v)
    else if Int32.compare v (-256l) < 0 then (
      write_byte buf 236;
      write_u16_le buf (Int32.to_int v))
    else if Int32.compare v 0l < 0 then (
      write_byte buf 235;
      write_byte buf (Int32.to_int v))
    else if Int32.compare v 231l <= 0 then write_byte buf (Int32.to_int v)
    else if Int32.compare v 65535l <= 0 then (
      write_byte buf 232;
      write_u16_le buf (Int32.to_int v))
    else (
      write_byte buf 233;
      write_u32_le buf v)

  let encode_length buf len =
    if len < 232 then write_byte buf len
    else if len < 65536 then (
      write_byte buf 232;
      write_u16_le buf len)
    else (
      write_byte buf 233;
      write_u32_le buf (Int32.of_int len))

  let encode_int64 (v : int64) buf =
    if
      Int64.compare v (-2147483648L) >= 0
      && Int64.compare v 2147483647L <= 0
    then encode_int32 (Int64.to_int32 v) buf
    else (
      write_byte buf 238;
      write_i64_le buf v)

  let encode_hash64 (v : int64) buf =
    if Int64.unsigned_compare v 231L <= 0 then write_byte buf (Int64.to_int v)
    else if Int64.unsigned_compare v 65535L <= 0 then (
      write_byte buf 232;
      write_u16_le buf (Int64.to_int v))
    else if Int64.unsigned_compare v 4294967295L <= 0 then (
      write_byte buf 233;
      write_u32_le buf (Int64.to_int32 v))
    else (
      write_byte buf 234;
      write_i64_le buf v)

  let read_u16 st =
    let b0 = read_byte st in
    let b1 = read_byte st in
    b0 lor (b1 lsl 8)

  let read_u32_as_int64 st =
    let b0 = Int64.of_int (read_byte st) in
    let b1 = Int64.of_int (read_byte st) in
    let b2 = Int64.of_int (read_byte st) in
    let b3 = Int64.of_int (read_byte st) in
    Int64.logor
      (Int64.logor b0 (Int64.shift_left b1 8))
      (Int64.logor (Int64.shift_left b2 16) (Int64.shift_left b3 24))

  let read_i32 st =
    let u = read_u32_as_int64 st in
    if Int64.compare u 2147483648L >= 0 then Int64.sub u 4294967296L else u

  let read_i64 st =
    let res = ref 0L in
    for shift = 0 to 7 do
      let b = Int64.of_int (read_byte st) in
      res := Int64.logor !res (Int64.shift_left b (shift * 8))
    done;
    !res

  let decode_number_body wire st =
    match wire with
    | w when w >= 0 && w <= 231 -> Int64.of_int w
    | 232 -> Int64.of_int (read_u16 st)
    | 233 -> read_u32_as_int64 st
    | 234 -> read_i64 st
    | 235 -> Int64.of_int (read_byte st - 256)
    | 236 -> Int64.of_int (read_u16 st - 65536)
    | 237 -> read_i32 st
    | 238 | 239 -> read_i64 st
    | 240 ->
      let u = read_u32_as_int64 st in
      let f = Int32.float_of_bits (Int64.to_int32 u) in
      Int64.of_float f
    | 241 ->
      let bits = read_i64 st in
      let d = Int64.float_of_bits bits in
      Int64.of_float d
    | _ -> 0L

  let decode_number st =
    let wire = read_byte st in
    decode_number_body wire st

  let uint64_to_float (u : int64) =
    if Int64.compare u 0L >= 0 then Int64.to_float u
    else
      let high = Int64.shift_right_logical u 1 in
      let low = Int64.logand u 1L in
      (Int64.to_float high *. 2.0) +. Int64.to_float low

  let decode_float_body wire st =
    match wire with
    | w when w >= 0 && w <= 231 -> Float.of_int w
    | 232 -> Float.of_int (read_u16 st)
    | 233 -> Int64.to_float (read_u32_as_int64 st)
    | 234 -> uint64_to_float (read_i64 st)
    | 235 -> Float.of_int (read_byte st - 256)
    | 236 -> Float.of_int (read_u16 st - 65536)
    | 237 -> Int64.to_float (read_i32 st)
    | 238 | 239 -> Int64.to_float (read_i64 st)
    | 240 ->
      let u = read_u32_as_int64 st in
      Int32.float_of_bits (Int64.to_int32 u)
    | 241 ->
      let bits = read_i64 st in
      Int64.float_of_bits bits
    | _ -> 0.0

  let decode_float st =
    let wire = read_byte st in
    decode_float_body wire st

  let rec skip_value st =
    let wire = read_byte st in
    match wire with
    | w when w >= 0 && w <= 231 -> ()
    | 242 | 244 | 246 | 255 -> ()
    | 232 | 236 -> ignore (read_bytes st 2)
    | 233 | 237 | 240 -> ignore (read_bytes st 4)
    | 234 | 238 | 239 | 241 -> ignore (read_bytes st 8)
    | 235 -> ignore (read_bytes st 1)
    | 243 | 245 ->
      let n = Int64.to_int (decode_number st) in
      ignore (read_bytes st n)
    | 247 | 248 | 249 ->
      let count = wire - 246 in
      for _ = 1 to count do
        skip_value st
      done
    | 250 ->
      let count = Int64.to_int (decode_number st) in
      for _ = 1 to count do
        skip_value st
      done
    | 251 | 252 | 253 | 254 -> skip_value st
    | _ -> ()
end

(* =============================================================================
   Serializer & Primitive / Composite Serializers
   ============================================================================= *)

type 'a adapter = {
  is_default : 'a -> bool;
  to_dense_json : 'a -> Json.t;
  to_readable_json : 'a -> Json.t;
  from_json : Json.t -> unrecognized_values -> ('a, string) result;
  encode : 'a -> Buffer.t -> unit;
  decode : Binary.stream -> unrecognized_values -> 'a;
  type_signature : unit -> Type_descriptor.type_signature;
  type_descriptor : unit -> Type_descriptor.t;
}

type 'a serializer = { adapter : 'a adapter }

let to_dense_json ser v = ser.adapter.to_dense_json v
let to_readable_json ser v = ser.adapter.to_readable_json v

let to_dense_json_code ser v =
  Json.to_string ~pretty:false (ser.adapter.to_dense_json v)

let to_readable_json_code ser v =
  Json.to_string ~pretty:true (ser.adapter.to_readable_json v)

let to_json ?(readable = false) ser v =
  if readable then to_readable_json ser v else to_dense_json ser v

let to_json_code ?(readable = false) ser v =
  if readable then to_readable_json_code ser v else to_dense_json_code ser v

let from_json ?(unrecognized_values = Drop) ser json =
  ser.adapter.from_json json unrecognized_values

let from_json_code ?(unrecognized_values = Drop) ser code =
  match Json.parse code with
  | Error e -> Error e
  | Ok json -> ser.adapter.from_json json unrecognized_values

let to_bytes ser v =
  let buf = Buffer.create 64 in
  Buffer.add_string buf "skir";
  ser.adapter.encode v buf;
  Buffer.contents buf

let from_bytes ?(unrecognized_values = Drop) ser bytes =
  if String.length bytes < 4 || String.sub bytes 0 4 <> "skir" then
    Error "invalid binary header: missing 'skir' magic"
  else
    let st = Binary.make_stream bytes 4 in
    try Ok (ser.adapter.decode st unrecognized_values)
    with Binary.Decode_error msg -> Error ("binary decode error: " ^ msg)

let type_descriptor ser = ser.adapter.type_descriptor ()

(* Numeric formatting and parsing helpers *)

let format_float f =
  if Float.is_nan f then "NaN"
  else if Float.is_infinite f then
    if f > 0.0 then "Infinity" else "-Infinity"
  else if f = 0.0 then "0"
  else
    (* Format shortest round-trip float like JS/Skir *)
    let s15 = Printf.sprintf "%.15g" f in
    let s17 = Printf.sprintf "%.17g" f in
    let chosen =
      match float_of_string_opt s15 with
      | Some parsed when parsed = f -> s15
      | _ -> s17
    in
    (* Normalize e+05 -> e+5 or e-05 -> e-5 if needed *)
    chosen

let format_float32 f =
  let f32 = Int32.float_of_bits (Int32.bits_of_float f) in
  if Float.is_nan f32 then "NaN"
  else if Float.is_infinite f32 then
    if f32 > 0.0 then "Infinity" else "-Infinity"
  else if f32 = 0.0 then "0"
  else
    let s7 = Printf.sprintf "%.7g" f32 in
    let s9 = Printf.sprintf "%.9g" f32 in
    let chosen =
      match float_of_string_opt s7 with
      | Some parsed ->
        let p32 = Int32.float_of_bits (Int32.bits_of_float parsed) in
        if p32 = f32 then s7 else s9
      | None -> s9
    in
    chosen

let parse_float_str s =
  match s with
  | "NaN" -> Float.nan
  | "Infinity" | "+Infinity" -> Float.infinity
  | "-Infinity" -> Float.neg_infinity
  | _ -> ( match float_of_string_opt s with Some f -> f | None -> 0.0)

let uint64_to_string (u : int64) =
  if Int64.compare u 0L >= 0 then Int64.to_string u
  else
    (* Unsigned division by 10 *)
    let q =
      Int64.div (Int64.shift_right_logical u 1) 5L
    in
    let r = Int64.sub u (Int64.mul q 10L) in
    let q, r =
      if Int64.compare r 10L >= 0 then (Int64.add q 1L, Int64.sub r 10L)
      else (q, r)
    in
    Int64.to_string q ^ Int64.to_string r

let parse_uint64_str s =
  let len = String.length s in
  if len = 0 then 0L
  else if String.unsafe_get s 0 = '-' then 0L
  else
    let acc = ref 0L in
    let stop = ref false in
    let is_float = ref false in
    for i = 0 to len - 1 do
      let c = String.unsafe_get s i in
      if c = '.' || c = 'e' || c = 'E' then is_float := true
    done;
    if !is_float then
      let f = parse_float_str s in
      if Float.is_nan f || f <= 0.0 then 0L
      else if f >= 18446744073709551615.0 then -1L
      else if f < 9223372036854775808.0 then Int64.of_float f
      else
        Int64.add
          (Int64.of_float (f -. 9223372036854775808.0))
          Int64.min_int
    else (
      for i = 0 to len - 1 do
        if not !stop then
          let c = String.unsafe_get s i in
          if c >= '0' && c <= '9' then
            let d = Int64.of_int (Char.code c - Char.code '0') in
            (* Check unsigned overflow: acc * 10 + d > max_uint64 *)
            let max_div_10 = 1844674407370955161L in
            if
              Int64.unsigned_compare !acc max_div_10 > 0
              || (Int64.equal !acc max_div_10 && Int64.compare d 5L > 0)
            then (
              acc := -1L;
              stop := true)
            else acc := Int64.add (Int64.mul !acc 10L) d
          else stop := true
      done;
      !acc)

let parse_int64_str s =
  match Int64.of_string_opt s with
  | Some v -> v
  | None ->
    let f = parse_float_str s in
    if Float.is_nan f then 0L
    else if f >= 9223372036854775807.0 then Int64.max_int
    else if f <= -9223372036854775808.0 then Int64.min_int
    else Int64.of_float f

let parse_int32_str s =
  let i64 = parse_int64_str s in
  if Int64.compare i64 2147483647L > 0 then Int32.max_int
  else if Int64.compare i64 (-2147483648L) < 0 then Int32.min_int
  else Int64.to_int32 i64

let max_safe_js_int = 9007199254740991L
let min_safe_js_int = -9007199254740991L

let bool_serializer =
  {
    adapter =
      {
        is_default = (fun b -> not b);
        to_dense_json = (fun b -> Json.Number (if b then "1" else "0"));
        to_readable_json = (fun b -> Json.Bool b);
        from_json =
          (fun json _ ->
            match json with
            | Json.Bool b -> Ok b
            | Json.Number raw -> Ok (parse_float_str raw <> 0.0)
            | Json.String s -> Ok (s <> "0" && s <> "false" && s <> "")
            | Json.Null -> Ok false
            | _ -> Ok false);
        encode = (fun b buf -> Binary.write_byte buf (if b then 1 else 0));
        decode = (fun st _ -> Binary.read_byte st <> 0);
        type_signature =
          (fun () -> Type_descriptor.Primitive Type_descriptor.Bool);
        type_descriptor =
          (fun () ->
            {
              root_type = Type_descriptor.Primitive Type_descriptor.Bool;
              records = [];
            });
      };
  }

let int32_serializer =
  {
    adapter =
      {
        is_default = (fun v -> Int32.equal v 0l);
        to_dense_json = (fun v -> Json.Number (Int32.to_string v));
        to_readable_json = (fun v -> Json.Number (Int32.to_string v));
        from_json =
          (fun json _ ->
            match json with
            | Json.Number raw -> Ok (parse_int32_str raw)
            | Json.String s -> Ok (parse_int32_str s)
            | Json.Bool b -> Ok (if b then 1l else 0l)
            | _ -> Ok 0l);
        encode = (fun v buf -> Binary.encode_int32 v buf);
        decode = (fun st _ -> Int64.to_int32 (Binary.decode_number st));
        type_signature =
          (fun () -> Type_descriptor.Primitive Type_descriptor.Int32);
        type_descriptor =
          (fun () ->
            {
              root_type = Type_descriptor.Primitive Type_descriptor.Int32;
              records = [];
            });
      };
  }

let int64_serializer =
  let to_json_val v =
    if
      Int64.compare v min_safe_js_int >= 0
      && Int64.compare v max_safe_js_int <= 0
    then Json.Number (Int64.to_string v)
    else Json.String (Int64.to_string v)
  in
  {
    adapter =
      {
        is_default = (fun v -> Int64.equal v 0L);
        to_dense_json = to_json_val;
        to_readable_json = to_json_val;
        from_json =
          (fun json _ ->
            match json with
            | Json.Number raw -> Ok (parse_int64_str raw)
            | Json.String s -> Ok (parse_int64_str s)
            | Json.Bool b -> Ok (if b then 1L else 0L)
            | _ -> Ok 0L);
        encode = (fun v buf -> Binary.encode_int64 v buf);
        decode = (fun st _ -> Binary.decode_number st);
        type_signature =
          (fun () -> Type_descriptor.Primitive Type_descriptor.Int64);
        type_descriptor =
          (fun () ->
            {
              root_type = Type_descriptor.Primitive Type_descriptor.Int64;
              records = [];
            });
      };
  }

let hash64_serializer =
  let to_json_val v =
    if Int64.unsigned_compare v max_safe_js_int <= 0 then
      Json.Number (uint64_to_string v)
    else Json.String (uint64_to_string v)
  in
  {
    adapter =
      {
        is_default = (fun v -> Int64.equal v 0L);
        to_dense_json = to_json_val;
        to_readable_json = to_json_val;
        from_json =
          (fun json _ ->
            match json with
            | Json.Number raw -> Ok (parse_uint64_str raw)
            | Json.String s -> Ok (parse_uint64_str s)
            | Json.Bool b -> Ok (if b then 1L else 0L)
            | _ -> Ok 0L);
        encode = (fun v buf -> Binary.encode_hash64 v buf);
        decode = (fun st _ -> Binary.decode_number st);
        type_signature =
          (fun () -> Type_descriptor.Primitive Type_descriptor.Hash64);
        type_descriptor =
          (fun () ->
            {
              root_type = Type_descriptor.Primitive Type_descriptor.Hash64;
              records = [];
            });
      };
  }

let float32_serializer =
  let to_json_val f =
    let s = format_float32 f in
    if s = "NaN" || s = "Infinity" || s = "-Infinity" then Json.String s
    else Json.Number s
  in
  {
    adapter =
      {
        is_default = (fun f -> f = 0.0);
        to_dense_json = to_json_val;
        to_readable_json = to_json_val;
        from_json =
          (fun json _ ->
            let f =
              match json with
              | Json.Number raw -> parse_float_str raw
              | Json.String s -> parse_float_str s
              | Json.Bool b -> if b then 1.0 else 0.0
              | _ -> 0.0
            in
            Ok (Int32.float_of_bits (Int32.bits_of_float f)));
        encode =
          (fun f buf ->
            if f = 0.0 then Binary.write_byte buf 0
            else (
              Binary.write_byte buf 240;
              Binary.write_u32_le buf (Int32.bits_of_float f)));
        decode =
          (fun st _ ->
            let f = Binary.decode_float st in
            Int32.float_of_bits (Int32.bits_of_float f));
        type_signature =
          (fun () -> Type_descriptor.Primitive Type_descriptor.Float32);
        type_descriptor =
          (fun () ->
            {
              root_type = Type_descriptor.Primitive Type_descriptor.Float32;
              records = [];
            });
      };
  }

let float64_serializer =
  let to_json_val f =
    let s = format_float f in
    if s = "NaN" || s = "Infinity" || s = "-Infinity" then Json.String s
    else Json.Number s
  in
  {
    adapter =
      {
        is_default = (fun f -> f = 0.0);
        to_dense_json = to_json_val;
        to_readable_json = to_json_val;
        from_json =
          (fun json _ ->
            match json with
            | Json.Number raw -> Ok (parse_float_str raw)
            | Json.String s -> Ok (parse_float_str s)
            | Json.Bool b -> Ok (if b then 1.0 else 0.0)
            | _ -> Ok 0.0);
        encode =
          (fun f buf ->
            if f = 0.0 then Binary.write_byte buf 0
            else (
              Binary.write_byte buf 241;
              Binary.write_i64_le buf (Int64.bits_of_float f)));
        decode = (fun st _ -> Binary.decode_float st);
        type_signature =
          (fun () -> Type_descriptor.Primitive Type_descriptor.Float64);
        type_descriptor =
          (fun () ->
            {
              root_type = Type_descriptor.Primitive Type_descriptor.Float64;
              records = [];
            });
      };
  }

let timestamp_serializer =
  let rec json_to_millis = function
    | Json.Number raw -> parse_int64_str raw
    | Json.String s -> parse_int64_str s
    | Json.Object fields -> (
      match List.assoc_opt "unix_millis" fields with
      | Some v -> json_to_millis v
      | None -> 0L)
    | _ -> 0L
  in
  {
    adapter =
      {
        is_default = (fun t -> Int64.equal (Timestamp.unix_millis t) 0L);
        to_dense_json =
          (fun t ->
            let ms = Timestamp.unix_millis (Timestamp.from_unix_millis (Timestamp.unix_millis t)) in
            Json.Number (Int64.to_string ms));
        to_readable_json =
          (fun t ->
            let ts = Timestamp.from_unix_millis (Timestamp.unix_millis t) in
            Json.Object
              [
                ("unix_millis", Json.Number (Int64.to_string (Timestamp.unix_millis ts)));
                ("formatted", Json.String (Timestamp.to_iso8601 ts));
              ]);
        from_json =
          (fun json _ -> Ok (Timestamp.from_unix_millis (json_to_millis json)));
        encode =
          (fun t buf ->
            let ms = Timestamp.unix_millis (Timestamp.from_unix_millis (Timestamp.unix_millis t)) in
            if Int64.equal ms 0L then Binary.write_byte buf 0
            else (
              Binary.write_byte buf 239;
              Binary.write_i64_le buf ms));
        decode =
          (fun st _ -> Timestamp.from_unix_millis (Binary.decode_number st));
        type_signature =
          (fun () -> Type_descriptor.Primitive Type_descriptor.Timestamp);
        type_descriptor =
          (fun () ->
            {
              root_type = Type_descriptor.Primitive Type_descriptor.Timestamp;
              records = [];
            });
      };
  }

let string_serializer =
  {
    adapter =
      {
        is_default = (fun s -> s = "");
        to_dense_json = (fun s -> Json.String s);
        to_readable_json = (fun s -> Json.String s);
        from_json =
          (fun json _ ->
            match json with
            | Json.String s -> Ok s
            | Json.Number "0" | Json.Number "0.0" | Json.Null -> Ok ""
            | _ -> Ok "");
        encode =
          (fun s buf ->
            let len = String.length s in
            if len = 0 then Binary.write_byte buf 242
            else (
              Binary.write_byte buf 243;
              Binary.encode_length buf len;
              Buffer.add_string buf s));
        decode =
          (fun st _ ->
            let wire = Binary.read_byte st in
            if wire = 0 || wire = 242 then ""
            else
              let len = Int64.to_int (Binary.decode_number st) in
              let raw = Binary.read_bytes st len in
              scrub_utf8 raw);
        type_signature =
          (fun () -> Type_descriptor.Primitive Type_descriptor.String);
        type_descriptor =
          (fun () ->
            {
              root_type = Type_descriptor.Primitive Type_descriptor.String;
              records = [];
            });
      };
  }

let bytes_serializer =
  {
    adapter =
      {
        is_default = (fun b -> String.length b = 0);
        to_dense_json = (fun b -> Json.String (Base64.encode b));
        to_readable_json = (fun b -> Json.String ("hex:" ^ Hex.encode b));
        from_json =
          (fun json _ ->
            match json with
            | Json.String s ->
              if String.length s >= 4 && String.sub s 0 4 = "hex:" then
                Hex.decode (String.sub s 4 (String.length s - 4))
              else Base64.decode s
            | Json.Number "0" | Json.Number "0.0" | Json.Null -> Ok ""
            | _ -> Ok "");
        encode =
          (fun b buf ->
            let len = String.length b in
            if len = 0 then Binary.write_byte buf 244
            else (
              Binary.write_byte buf 245;
              Binary.encode_length buf len;
              Buffer.add_string buf b));
        decode =
          (fun st _ ->
            let wire = Binary.read_byte st in
            if wire = 0 || wire = 244 then ""
            else
              let len = Int64.to_int (Binary.decode_number st) in
              Binary.read_bytes st len);
        type_signature =
          (fun () -> Type_descriptor.Primitive Type_descriptor.Bytes);
        type_descriptor =
          (fun () ->
            {
              root_type = Type_descriptor.Primitive Type_descriptor.Bytes;
              records = [];
            });
      };
  }

let optional_serializer (other : 'a serializer) : 'a option serializer =
  let o = other.adapter in
  {
    adapter =
      {
        is_default = (function None -> true | Some _ -> false);
        to_dense_json =
          (function None -> Json.Null | Some v -> o.to_dense_json v);
        to_readable_json =
          (function None -> Json.Null | Some v -> o.to_readable_json v);
        from_json =
          (fun json policy ->
            match json with
            | Json.Null -> Ok None
            | _ -> (
              match o.from_json json policy with
              | Ok v -> Ok (Some v)
              | Error e -> Error e));
        encode =
          (fun opt buf ->
            match opt with
            | None -> Binary.write_byte buf 255
            | Some v -> o.encode v buf);
        decode =
          (fun st policy ->
            if Binary.peek_byte st = 255 then (
              ignore (Binary.read_byte st);
              None)
            else Some (o.decode st policy));
        type_signature = (fun () -> Type_descriptor.Optional (o.type_signature ()));
        type_descriptor =
          (fun () ->
            let td = o.type_descriptor () in
            {
              root_type = Type_descriptor.Optional td.root_type;
              records = td.records;
            });
      };
  }

let recursive_serializer (other_lazy : unit -> 'a serializer) :
    'a recursive serializer =
  {
    adapter =
      {
        is_default =
          (function
          | Default -> true
          | Value v -> (other_lazy ()).adapter.is_default v);
        to_dense_json =
          (function
          | Default -> Json.Array []
          | Value v -> (other_lazy ()).adapter.to_dense_json v);
        to_readable_json =
          (function
          | Default -> Json.Object []
          | Value v -> (other_lazy ()).adapter.to_readable_json v);
        from_json =
          (fun json policy ->
            match json with
            | Json.Array [] | Json.Object [] | Json.Number "0" | Json.Null ->
              Ok Default
            | _ -> (
              match (other_lazy ()).adapter.from_json json policy with
              | Ok v -> Ok (Value v)
              | Error e -> Error e));
        encode =
          (fun r buf ->
            match r with
            | Default -> Binary.write_byte buf 246
            | Value v -> (other_lazy ()).adapter.encode v buf);
        decode =
          (fun st policy ->
            let wire = Binary.peek_byte st in
            if wire = 0 || wire = 246 then (
              ignore (Binary.read_byte st);
              Default)
            else Value ((other_lazy ()).adapter.decode st policy));
        type_signature = (fun () -> (other_lazy ()).adapter.type_signature ());
        type_descriptor = (fun () -> (other_lazy ()).adapter.type_descriptor ());
      };
  }

let list_serializer_impl (item_ser : 'a serializer) (key_extractor : string) :
    'a list serializer =
  let item = item_ser.adapter in
  {
    adapter =
      {
        is_default = (fun xs -> xs = []);
        to_dense_json = (fun xs -> Json.Array (List.map item.to_dense_json xs));
        to_readable_json =
          (fun xs -> Json.Array (List.map item.to_readable_json xs));
        from_json =
          (fun json policy ->
            match json with
            | Json.Array arr ->
              let rec loop acc = function
                | [] -> Ok (List.rev acc)
                | x :: rest -> (
                  match item.from_json x policy with
                  | Ok v -> loop (v :: acc) rest
                  | Error e -> Error e)
              in
              loop [] arr
            | _ -> Ok []);
        encode =
          (fun xs buf ->
            let n = List.length xs in
            if n <= 3 then Binary.write_byte buf (246 + n)
            else (
              Binary.write_byte buf 250;
              Binary.encode_int32 (Int32.of_int n) buf);
            List.iter (fun x -> item.encode x buf) xs);
        decode =
          (fun st policy ->
            let wire = Binary.read_byte st in
            if wire = 0 || wire = 246 then []
            else
              let n =
                if wire = 250 then Int64.to_int (Binary.decode_number st)
                else if wire >= 247 && wire <= 249 then wire - 246
                else 0
              in
              let acc = ref [] in
              for _ = 1 to n do
                acc := item.decode st policy :: !acc
              done;
              List.rev !acc);
        type_signature =
          (fun () ->
            Type_descriptor.Array
              { item_type = item.type_signature (); key_extractor });
        type_descriptor =
          (fun () ->
            let td = item.type_descriptor () in
            {
              root_type =
                Type_descriptor.Array
                  { item_type = td.root_type; key_extractor };
              records = td.records;
            });
      };
  }

let list_serializer item_ser = list_serializer_impl item_ser ""

let keyed_list_serializer (item_ser : 'a serializer) ~(key_extractor : string) :
    'a list serializer =
  list_serializer_impl item_ser key_extractor

(* =============================================================================
   Internal StructAdapter & EnumAdapter (used by skir-ocaml-gen)
   ============================================================================= *)

module Internal = struct
  (* Registry of record_id -> unit -> Type_descriptor.record_descriptor * (unit -> string list)
     to support cyclic/recursive record type descriptors cleanly without
     infinite recursion. *)
  let record_descriptor_builders :
      (string, unit -> Type_descriptor.record_descriptor * (unit -> string list))
      Hashtbl.t =
    Hashtbl.create 64

  let rec collect_record_ids_from_sig acc = function
    | Type_descriptor.Primitive _ -> acc
    | Type_descriptor.Optional inner -> collect_record_ids_from_sig acc inner
    | Type_descriptor.Array { item_type; _ } ->
      collect_record_ids_from_sig acc item_type
    | Type_descriptor.Record rid -> rid :: acc

  let collect_records root_record_id =
    let visited = Hashtbl.create 16 in
    let result = ref [] in
    let rec visit rid =
      if not (Hashtbl.mem visited rid) then (
        Hashtbl.add visited rid true;
        match Hashtbl.find_opt record_descriptor_builders rid with
        | None -> ()
        | Some build ->
          let desc, get_children = build () in
          result := desc :: !result;
          let child_ids = get_children () in
          List.iter visit child_ids)
    in
    visit root_record_id;
    List.rev !result

  type ('t, 'mut) struct_field_entry = {
    sf_name : string;
    sf_number : int;
    sf_doc : string;
    sf_get_type_sig : unit -> Type_descriptor.type_signature;
    sf_is_default : 't -> bool;
    sf_to_dense_json : 't -> Json.t;
    sf_to_readable_json : 't -> Json.t;
    sf_from_json : 'mut -> Json.t -> unrecognized_values -> (unit, string) result;
    sf_encode : 't -> Buffer.t -> unit;
    sf_decode : 'mut -> Binary.stream -> unrecognized_values -> unit;
  }

  type ('t, 'mut) struct_adapter = {
    sa_record_id : string;
    sa_doc : string;
    sa_default : 't;
    sa_new_mutable : unit -> 'mut;
    sa_to_frozen : 'mut -> 't;
    sa_get_unrecognized : 't -> unrecognized_fields option;
    sa_set_unrecognized : 'mut -> unrecognized_fields option -> unit;
    mutable sa_entries : ('t, 'mut) struct_field_entry list;
    mutable sa_removed_numbers : int list;
    sa_name_to_entry : (string, ('t, 'mut) struct_field_entry) Hashtbl.t;
    mutable sa_slot_to_entry : ('t, 'mut) struct_field_entry option array;
  }

  let make_struct_adapter ~record_id ~doc ~default ~new_mutable ~to_frozen
      ~get_unrecognized ~set_unrecognized =
    {
      sa_record_id = record_id;
      sa_doc = doc;
      sa_default = default;
      sa_new_mutable = new_mutable;
      sa_to_frozen = to_frozen;
      sa_get_unrecognized = get_unrecognized;
      sa_set_unrecognized = set_unrecognized;
      sa_entries = [];
      sa_removed_numbers = [];
      sa_name_to_entry = Hashtbl.create 16;
      sa_slot_to_entry = [||];
    }

  let add_struct_field (sa : ('t, 'mut) struct_adapter) ~(name : string)
      ~(number : int) ~(serializer : 'v serializer) ~(getter : 't -> 'v)
      ~(setter : 'mut -> 'v -> unit) ~(doc : string) =
    let ser = serializer.adapter in
    let entry =
      {
        sf_name = name;
        sf_number = number;
        sf_doc = doc;
        sf_get_type_sig = ser.type_signature;
        sf_is_default = (fun t -> ser.is_default (getter t));
        sf_to_dense_json = (fun t -> ser.to_dense_json (getter t));
        sf_to_readable_json = (fun t -> ser.to_readable_json (getter t));
        sf_from_json =
          (fun m json policy ->
            match ser.from_json json policy with
            | Ok v ->
              setter m v;
              Ok ()
            | Error e -> Error e);
        sf_encode = (fun t buf -> ser.encode (getter t) buf);
        sf_decode =
          (fun m st policy ->
            let v = ser.decode st policy in
            setter m v);
      }
    in
    sa.sa_entries <- sa.sa_entries @ [ entry ]

  let add_struct_removed_number sa n =
    sa.sa_removed_numbers <- sa.sa_removed_numbers @ [ n ]

  let finalize_struct (sa : ('t, 'mut) struct_adapter) =
    Hashtbl.clear sa.sa_name_to_entry;
    let max_field =
      List.fold_left (fun acc e -> max acc e.sf_number) (-1) sa.sa_entries
    in
    let max_removed =
      List.fold_left max (-1) sa.sa_removed_numbers
    in
    let max_num = max max_field max_removed in
    sa.sa_slot_to_entry <- Array.make (max_num + 1) None;
    List.iter
      (fun e ->
        Hashtbl.replace sa.sa_name_to_entry e.sf_name e;
        if e.sf_number >= 0 && e.sf_number < Array.length sa.sa_slot_to_entry
        then sa.sa_slot_to_entry.(e.sf_number) <- Some e)
      sa.sa_entries;
    Hashtbl.replace record_descriptor_builders sa.sa_record_id (fun () ->
        let fields =
          List.map
            (fun e ->
              {
                Type_descriptor.name = e.sf_name;
                number = e.sf_number;
                field_type = e.sf_get_type_sig ();
                doc = e.sf_doc;
              })
            sa.sa_entries
        in
        let desc =
          Type_descriptor.Struct
            {
              record_id = sa.sa_record_id;
              doc = sa.sa_doc;
              fields;
              removed_numbers = sa.sa_removed_numbers;
            }
        in
        let get_children () =
          List.rev
            (List.fold_left
               (fun acc (f : Type_descriptor.struct_field) ->
                 collect_record_ids_from_sig acc f.field_type)
               [] fields)
        in
        (desc, get_children))

  let struct_slot_count sa input =
    let max_non_def =
      List.fold_left
        (fun acc e ->
          if not (e.sf_is_default input) then max acc e.sf_number else acc)
        (-1) sa.sa_entries
    in
    max_non_def + 1

  let struct_serializer (sa : ('t, 'mut) struct_adapter) : 't serializer =
    {
      adapter =
        {
          is_default =
            (fun input ->
              match sa.sa_get_unrecognized input with
              | Some _ -> false
              | None ->
                List.for_all (fun e -> e.sf_is_default input) sa.sa_entries);
          to_dense_json =
            (fun input ->
              let total_slots, extra =
                match sa.sa_get_unrecognized input with
                | Some { uf_format = Unrecognized_dense_json (Json.Array ex); uf_array_len } ->
                  (uf_array_len, ex)
                | _ -> (struct_slot_count sa input, [])
              in
              let rec_max = Array.length sa.sa_slot_to_entry in
              let limit = min total_slots rec_max in
              let acc = ref [] in
              for i = 0 to limit - 1 do
                match sa.sa_slot_to_entry.(i) with
                | Some e -> acc := e.sf_to_dense_json input :: !acc
                | None -> acc := Json.Number "0" :: !acc
              done;
              let base = List.rev !acc in
              let all =
                if total_slots > rec_max && extra <> [] then base @ extra
                else base
              in
              Json.Array all);
          to_readable_json =
            (fun input ->
              let fields =
                List.filter_map
                  (fun e ->
                    if e.sf_is_default input then None
                    else Some (e.sf_name, e.sf_to_readable_json input))
                  sa.sa_entries
              in
              Json.Object fields);
          from_json =
            (fun json policy ->
              match json with
              | Json.Array arr ->
                let m = sa.sa_new_mutable () in
                let arr_a = Array.of_list arr in
                let len = Array.length arr_a in
                let rec loop = function
                  | [] -> Ok ()
                  | e :: rest ->
                    if e.sf_number >= 0 && e.sf_number < len then
                      match e.sf_from_json m arr_a.(e.sf_number) policy with
                      | Ok () -> loop rest
                      | Error err -> Error err
                    else loop rest
                in
                (match loop sa.sa_entries with
                | Error err -> Error err
                | Ok () ->
                  (if policy = Keep then
                     let rec_max = Array.length sa.sa_slot_to_entry in
                     if len > rec_max then
                       let extra =
                         Array.to_list (Array.sub arr_a rec_max (len - rec_max))
                       in
                       sa.sa_set_unrecognized m
                         (Some
                            {
                              uf_format =
                                Unrecognized_dense_json (Json.Array extra);
                              uf_array_len = len;
                            }));
                  Ok (sa.sa_to_frozen m))
              | Json.Object fields ->
                let m = sa.sa_new_mutable () in
                let rec loop = function
                  | [] -> Ok (sa.sa_to_frozen m)
                  | (k, v) :: rest -> (
                    match Hashtbl.find_opt sa.sa_name_to_entry k with
                    | None -> loop rest
                    | Some e -> (
                      match e.sf_from_json m v policy with
                      | Ok () -> loop rest
                      | Error err -> Error err))
                in
                loop fields
              | _ -> Ok sa.sa_default);
          encode =
            (fun input buf ->
              let total_slots, extra_bytes =
                match sa.sa_get_unrecognized input with
                | Some { uf_format = Unrecognized_bytes b; uf_array_len } ->
                  (uf_array_len, b)
                | _ -> (struct_slot_count sa input, "")
              in
              if total_slots <= 3 then Binary.write_byte buf (246 + total_slots)
              else (
                Binary.write_byte buf 250;
                Binary.encode_int32 (Int32.of_int total_slots) buf);
              let rec_count = Array.length sa.sa_slot_to_entry in
              let limit = min total_slots rec_count in
              for i = 0 to limit - 1 do
                match sa.sa_slot_to_entry.(i) with
                | Some e -> e.sf_encode input buf
                | None -> Binary.write_byte buf 0
              done;
              Buffer.add_string buf extra_bytes);
          decode =
            (fun st policy ->
              let wire = Binary.read_byte st in
              if wire = 0 || wire = 246 then sa.sa_default
              else
                let slot_count =
                  if wire = 250 then Int64.to_int (Binary.decode_number st)
                  else wire - 246
                in
                let m = sa.sa_new_mutable () in
                let rec_count = Array.length sa.sa_slot_to_entry in
                let slots_to_fill = min slot_count rec_count in
                for i = 0 to slots_to_fill - 1 do
                  match sa.sa_slot_to_entry.(i) with
                  | Some e -> e.sf_decode m st policy
                  | None -> Binary.skip_value st
                done;
                if slot_count > rec_count then
                  if policy = Keep then (
                    let start_pos = st.pos in
                    for _ = rec_count to slot_count - 1 do
                      Binary.skip_value st
                    done;
                    let captured =
                      String.sub st.data start_pos (st.pos - start_pos)
                    in
                    sa.sa_set_unrecognized m
                      (Some
                         {
                           uf_format = Unrecognized_bytes captured;
                           uf_array_len = slot_count;
                         }))
                  else
                    for _ = rec_count to slot_count - 1 do
                      Binary.skip_value st
                    done;
                sa.sa_to_frozen m);
          type_signature =
            (fun () -> Type_descriptor.Record sa.sa_record_id);
          type_descriptor =
            (fun () ->
              {
                root_type = Type_descriptor.Record sa.sa_record_id;
                records = collect_records sa.sa_record_id;
              });
        };
    }

  (* EnumAdapter *)

  type 't enum_variant_entry = {
    ev_name : string;
    ev_number : int;
    ev_doc : string;
    ev_is_wrapper : bool;
    ev_constant_val : 't option;
    ev_wrapper_default : unit -> 't;
    ev_to_dense_json : 't -> Json.t;
    ev_to_readable_json : 't -> Json.t;
    ev_encode : 't -> Buffer.t -> unit;
    ev_from_json : Json.t -> unrecognized_values -> ('t, string) result;
    ev_decode : Binary.stream -> unrecognized_values -> 't;
    ev_get_type_sig : (unit -> Type_descriptor.type_signature) option;
  }

  type 't enum_num_entry =
    | Enum_removed
    | Enum_constant of int
    | Enum_wrapper of int

  type 't enum_adapter = {
    ea_record_id : string;
    ea_doc : string;
    ea_default : 't;
    ea_get_kind_ordinal : 't -> int;
    ea_wrap_unrecognized : unrecognized_variant -> 't;
    ea_get_unrecognized : 't -> unrecognized_variant option;
    ea_number_to_entry : (int, 't enum_num_entry) Hashtbl.t;
    ea_name_to_ordinal : (string, int) Hashtbl.t;
    mutable ea_ordinal_to_entry : 't enum_variant_entry option array;
    mutable ea_ordered_entries : 't enum_variant_entry list;
    mutable ea_removed_numbers : int list;
  }

  let make_enum_adapter ~record_id ~doc ~default ~get_kind_ordinal
      ~wrap_unrecognized ~get_unrecognized =
    {
      ea_record_id = record_id;
      ea_doc = doc;
      ea_default = default;
      ea_get_kind_ordinal = get_kind_ordinal;
      ea_wrap_unrecognized = wrap_unrecognized;
      ea_get_unrecognized = get_unrecognized;
      ea_number_to_entry = Hashtbl.create 16;
      ea_name_to_ordinal = Hashtbl.create 16;
      ea_ordinal_to_entry = [| None |];
      ea_ordered_entries = [];
      ea_removed_numbers = [];
    }

  let set_ordinal_entry ea ordinal entry =
    let len = Array.length ea.ea_ordinal_to_entry in
    if ordinal >= len then (
      let next = Array.make (ordinal + 1) None in
      Array.blit ea.ea_ordinal_to_entry 0 next 0 len;
      ea.ea_ordinal_to_entry <- next);
    ea.ea_ordinal_to_entry.(ordinal) <- Some entry

  let add_enum_constant_variant (ea : 't enum_adapter) ~(name : string)
      ~(number : int) ~(kind_ordinal : int) ~(doc : string) ~(instance : 't) =
    Hashtbl.replace ea.ea_number_to_entry number (Enum_constant kind_ordinal);
    Hashtbl.replace ea.ea_name_to_ordinal name kind_ordinal;
    Hashtbl.replace ea.ea_name_to_ordinal (String.uppercase_ascii name)
      kind_ordinal;
    Hashtbl.replace ea.ea_name_to_ordinal (String.lowercase_ascii name)
      kind_ordinal;
    let entry =
      {
        ev_name = name;
        ev_number = number;
        ev_doc = doc;
        ev_is_wrapper = false;
        ev_constant_val = Some instance;
        ev_wrapper_default = (fun () -> instance);
        ev_to_dense_json = (fun _ -> Json.Number (Int.to_string number));
        ev_to_readable_json = (fun _ -> Json.String name);
        ev_encode =
          (fun _ buf -> Binary.encode_int32 (Int32.of_int number) buf);
        ev_from_json = (fun _ _ -> Ok instance);
        ev_decode = (fun _ _ -> instance);
        ev_get_type_sig = None;
      }
    in
    set_ordinal_entry ea kind_ordinal entry;
    ea.ea_ordered_entries <- ea.ea_ordered_entries @ [ entry ]

  let add_enum_wrapper_variant (ea : 't enum_adapter) ~(name : string)
      ~(number : int) ~(kind_ordinal : int) ~(serializer : 'v serializer)
      ~(doc : string) ~(wrap : 'v -> 't) ~(get_value : 't -> 'v) =
    let ser = serializer.adapter in
    Hashtbl.replace ea.ea_number_to_entry number (Enum_wrapper kind_ordinal);
    Hashtbl.replace ea.ea_name_to_ordinal name kind_ordinal;
    let entry =
      {
        ev_name = name;
        ev_number = number;
        ev_doc = doc;
        ev_is_wrapper = true;
        ev_constant_val = None;
        ev_wrapper_default =
          (fun () ->
            match ser.from_json (Json.Number "0") Drop with
            | Ok v -> wrap v
            | Error _ -> ea.ea_default);
        ev_to_dense_json =
          (fun t ->
            Json.Array
              [
                Json.Number (Int.to_string number);
                ser.to_dense_json (get_value t);
              ]);
        ev_to_readable_json =
          (fun t ->
            Json.Object
              [
                ("kind", Json.String name);
                ("value", ser.to_readable_json (get_value t));
              ]);
        ev_encode =
          (fun t buf ->
            if number >= 1 && number <= 4 then
              Binary.write_byte buf (250 + number)
            else (
              Binary.write_byte buf 248;
              Binary.encode_int32 (Int32.of_int number) buf);
            ser.encode (get_value t) buf);
        ev_from_json =
          (fun json policy ->
            match ser.from_json json policy with
            | Ok v -> Ok (wrap v)
            | Error e -> Error e);
        ev_decode =
          (fun st policy ->
            let v = ser.decode st policy in
            wrap v);
        ev_get_type_sig = Some ser.type_signature;
      }
    in
    set_ordinal_entry ea kind_ordinal entry;
    ea.ea_ordered_entries <- ea.ea_ordered_entries @ [ entry ]

  let add_enum_removed_number ea n =
    Hashtbl.replace ea.ea_number_to_entry n Enum_removed;
    ea.ea_removed_numbers <- ea.ea_removed_numbers @ [ n ]

  let finalize_enum (ea : 't enum_adapter) =
    Hashtbl.replace ea.ea_name_to_ordinal "UNKNOWN" 0;
    Hashtbl.replace ea.ea_name_to_ordinal "unknown" 0;
    Hashtbl.replace record_descriptor_builders ea.ea_record_id (fun () ->
        let variants =
          List.map
            (fun e ->
              match e.ev_get_type_sig with
              | None ->
                Type_descriptor.Constant
                  { name = e.ev_name; number = e.ev_number; doc = e.ev_doc }
              | Some get_sig ->
                Type_descriptor.Wrapper
                  {
                    name = e.ev_name;
                    number = e.ev_number;
                    variant_type = get_sig ();
                    doc = e.ev_doc;
                  })
            ea.ea_ordered_entries
        in
        let desc =
          Type_descriptor.Enum
            {
              record_id = ea.ea_record_id;
              doc = ea.ea_doc;
              variants;
              removed_numbers = ea.ea_removed_numbers;
            }
        in
        let get_children () =
          List.rev
            (List.fold_left
               (fun acc (v : Type_descriptor.enum_variant) ->
                 match v with
                 | Type_descriptor.Constant _ -> acc
                 | Type_descriptor.Wrapper w ->
                   collect_record_ids_from_sig acc w.variant_type)
               [] variants)
        in
        (desc, get_children))

  let get_enum_entry ea ko =
    if ko >= 0 && ko < Array.length ea.ea_ordinal_to_entry then
      ea.ea_ordinal_to_entry.(ko)
    else None

  let enum_serializer (ea : 't enum_adapter) : 't serializer =
    {
      adapter =
        {
          is_default = (fun input -> ea.ea_get_kind_ordinal input = 0);
          to_dense_json =
            (fun input ->
              let ko = ea.ea_get_kind_ordinal input in
              if ko = 0 then
                match ea.ea_get_unrecognized input with
                | Some { uv_format = Unrecognized_dense_json j; _ } -> j
                | _ -> Json.Number "0"
              else
                match get_enum_entry ea ko with
                | Some e -> e.ev_to_dense_json input
                | None -> Json.Number "0");
          to_readable_json =
            (fun input ->
              let ko = ea.ea_get_kind_ordinal input in
              if ko = 0 then Json.String "unknown"
              else
                match get_enum_entry ea ko with
                | Some e -> e.ev_to_readable_json input
                | None -> Json.String "unknown");
          from_json =
            (fun json policy ->
              let keep = policy = Keep in
              match json with
              | Json.Number raw -> (
                let num = Int32.to_int (parse_int32_str raw) in
                if num = 0 then Ok ea.ea_default
                else
                  match Hashtbl.find_opt ea.ea_number_to_entry num with
                  | Some Enum_removed -> Ok ea.ea_default
                  | Some (Enum_constant ko) -> (
                    match get_enum_entry ea ko with
                    | Some { ev_constant_val = Some v; _ } -> Ok v
                    | _ -> Ok ea.ea_default)
                  | Some (Enum_wrapper ko) -> (
                    match get_enum_entry ea ko with
                    | Some e -> Ok (e.ev_wrapper_default ())
                    | None -> Ok ea.ea_default)
                  | None ->
                    if keep then
                      Ok
                        (ea.ea_wrap_unrecognized
                           {
                             uv_format = Unrecognized_dense_json json;
                             uv_number = num;
                           })
                    else Ok ea.ea_default)
              | Json.String s -> (
                match Hashtbl.find_opt ea.ea_name_to_ordinal s with
                | Some 0 | None -> Ok ea.ea_default
                | Some ko -> (
                  match get_enum_entry ea ko with
                  | Some { ev_constant_val = Some v; _ } -> Ok v
                  | Some e -> Ok (e.ev_wrapper_default ())
                  | None -> Ok ea.ea_default))
              | Json.Array [ num_json; val_json ] -> (
                let num =
                  match num_json with
                  | Json.Number raw -> Int32.to_int (parse_int32_str raw)
                  | _ -> 0
                in
                if num = 0 then Ok ea.ea_default
                else
                  match Hashtbl.find_opt ea.ea_number_to_entry num with
                  | Some Enum_removed -> Ok ea.ea_default
                  | Some (Enum_constant ko) -> (
                    match get_enum_entry ea ko with
                    | Some { ev_constant_val = Some v; _ } -> Ok v
                    | _ -> Ok ea.ea_default)
                  | Some (Enum_wrapper ko) -> (
                    match get_enum_entry ea ko with
                    | Some e -> e.ev_from_json val_json policy
                    | None -> Ok ea.ea_default)
                  | None ->
                    if keep then
                      Ok
                        (ea.ea_wrap_unrecognized
                           {
                             uv_format = Unrecognized_dense_json json;
                             uv_number = num;
                           })
                    else Ok ea.ea_default)
              | Json.Object fields -> (
                let name =
                  match List.assoc_opt "kind" fields with
                  | Some (Json.String s) -> s
                  | _ -> ""
                in
                let val_json =
                  match List.assoc_opt "value" fields with
                  | Some v -> v
                  | None -> Json.Null
                in
                match Hashtbl.find_opt ea.ea_name_to_ordinal name with
                | Some 0 | None -> Ok ea.ea_default
                | Some ko -> (
                  match get_enum_entry ea ko with
                  | Some { ev_constant_val = Some v; _ } -> Ok v
                  | Some e -> e.ev_from_json val_json policy
                  | None -> Ok ea.ea_default))
              | _ -> Ok ea.ea_default);
          encode =
            (fun input buf ->
              let ko = ea.ea_get_kind_ordinal input in
              if ko = 0 then
                match ea.ea_get_unrecognized input with
                | Some { uv_format = Unrecognized_bytes b; _ } when b <> "" ->
                  Buffer.add_string buf b
                | _ -> Binary.write_byte buf 0
              else
                match get_enum_entry ea ko with
                | Some e -> e.ev_encode input buf
                | None -> Binary.write_byte buf 0);
          decode =
            (fun st policy ->
              let keep = policy = Keep in
              let start_pos = st.pos in
              let wire = Binary.read_byte st in
              if wire < 242 then
                let num = Int64.to_int (Binary.decode_number_body wire st) in
                if num = 0 then ea.ea_default
                else
                  match Hashtbl.find_opt ea.ea_number_to_entry num with
                  | Some Enum_removed -> ea.ea_default
                  | Some (Enum_constant ko) -> (
                    match get_enum_entry ea ko with
                    | Some { ev_constant_val = Some v; _ } -> v
                    | _ -> ea.ea_default)
                  | Some (Enum_wrapper ko) -> (
                    match get_enum_entry ea ko with
                    | Some e -> e.ev_wrapper_default ()
                    | None -> ea.ea_default)
                  | None ->
                    if keep then
                      let captured =
                        String.sub st.data start_pos (st.pos - start_pos)
                      in
                      ea.ea_wrap_unrecognized
                        {
                          uv_format = Unrecognized_bytes captured;
                          uv_number = num;
                        }
                    else ea.ea_default
              else
                let num =
                  if wire = 248 then Int64.to_int (Binary.decode_number st)
                  else wire - 250
                in
                match Hashtbl.find_opt ea.ea_number_to_entry num with
                | Some Enum_removed ->
                  Binary.skip_value st;
                  ea.ea_default
                | Some (Enum_constant ko) -> (
                  Binary.skip_value st;
                  match get_enum_entry ea ko with
                  | Some { ev_constant_val = Some v; _ } -> v
                  | _ -> ea.ea_default)
                | Some (Enum_wrapper ko) -> (
                  match get_enum_entry ea ko with
                  | Some e -> e.ev_decode st policy
                  | None ->
                    Binary.skip_value st;
                    ea.ea_default)
                | None ->
                  Binary.skip_value st;
                  if keep then
                    let captured =
                      String.sub st.data start_pos (st.pos - start_pos)
                    in
                    ea.ea_wrap_unrecognized
                      {
                        uv_format = Unrecognized_bytes captured;
                        uv_number = num;
                      }
                  else ea.ea_default);
          type_signature =
            (fun () -> Type_descriptor.Record ea.ea_record_id);
          type_descriptor =
            (fun () ->
              {
                root_type = Type_descriptor.Record ea.ea_record_id;
                records = collect_records ea.ea_record_id;
              });
        };
    }
end

(* =============================================================================
   Method, Service, and Service_client (SkirRPC)
   ============================================================================= *)

module Method = struct
  type ('req, 'resp) t = {
    name : string;
    number : int64;
    request_serializer : 'req serializer;
    response_serializer : 'resp serializer;
    doc : string;
  }
end

module Service = struct
  type raw_response = {
    status_code : int;
    content_type : string;
    data : string;
  }

  type 'meta erased_method = {
    em_name : string;
    em_number : int64;
    em_doc : string;
    em_request_td : unit -> Type_descriptor.t;
    em_response_td : unit -> Type_descriptor.t;
    em_invoke : Json.t -> bool -> unrecognized_values -> 'meta -> (string, int * string) result;
  }

  type 'meta t = {
    mutable keep_unrecognized_values : bool;
    mutable can_send_unknown_error_message : bool;
    mutable studio_app_js_url : string;
    by_number : (int64, 'meta erased_method) Hashtbl.t;
    by_name : (string, 'meta erased_method) Hashtbl.t;
    mutable method_list : 'meta erased_method list;
  }

  let default_studio_url =
    "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js"

  let create () =
    {
      keep_unrecognized_values = false;
      can_send_unknown_error_message = false;
      studio_app_js_url = default_studio_url;
      by_number = Hashtbl.create 16;
      by_name = Hashtbl.create 16;
      method_list = [];
    }

  let add_method (svc : 'meta t) (m : ('req, 'resp) Method.t)
      (handler : 'req -> 'meta -> 'resp) =
    let invoke req_json readable policy meta =
      match from_json ~unrecognized_values:policy m.request_serializer req_json with
      | Error msg -> Error (400, "bad request: can't parse request JSON: " ^ msg)
      | Ok req -> (
        try
          let resp = handler req meta in
          let out = to_json_code ~readable m.response_serializer resp in
          Ok out
        with exn ->
          let msg =
            if svc.can_send_unknown_error_message then
              "server error: " ^ Printexc.to_string exn
            else "server error"
          in
          Error (500, msg))
    in
    let em =
      {
        em_name = m.name;
        em_number = m.number;
        em_doc = m.doc;
        em_request_td = (fun () -> type_descriptor m.request_serializer);
        em_response_td = (fun () -> type_descriptor m.response_serializer);
        em_invoke = invoke;
      }
    in
    Hashtbl.replace svc.by_number m.number em;
    Hashtbl.replace svc.by_name m.name em;
    svc.method_list <- svc.method_list @ [ em ]

  let serve_studio svc =
    let html =
      Printf.sprintf
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\" /><title>RPC Studio</title><link rel=\"icon\" href=\"data:image/svg+xml,<svg xmlns=%%22http://www.w3.org/2000/svg%%22 viewBox=%%220 0 100 100%%22><text y=%%22.9em%%22 font-size=%%2290%%22>🐙</text></svg>\"><script src=\"%s\"></script></head><body style=\"margin: 0; padding: 0;\"><skir-studio-app></skir-studio-app></body></html>"
        svc.studio_app_js_url
    in
    {
      status_code = 200;
      content_type = "text/html; charset=utf-8";
      data = html;
    }

  let serve_list svc =
    let methods_json =
      List.map
        (fun em ->
          let base =
            [
              ("method", Json.String em.em_name);
              ("number", Json.Number (Int64.to_string em.em_number));
              ("request", Type_descriptor.to_json (em.em_request_td ()));
              ("response", Type_descriptor.to_json (em.em_response_td ()));
            ]
          in
          let fields =
            if em.em_doc = "" then base
            else base @ [ ("doc", Json.String em.em_doc) ]
          in
          Json.Object fields)
        svc.method_list
    in
    let root = Json.Object [ ("methods", Json.Array methods_json) ] in
    {
      status_code = 200;
      content_type = "application/json";
      data = Json.to_string ~pretty:true root;
    }

  let split_colon4 s =
    match String.index_opt s ':' with
    | None -> None
    | Some i1 -> (
      let a = String.sub s 0 i1 in
      match String.index_from_opt s (i1 + 1) ':' with
      | None -> None
      | Some i2 -> (
        let b = String.sub s (i1 + 1) (i2 - i1 - 1) in
        match String.index_from_opt s (i2 + 1) ':' with
        | None -> None
        | Some i3 ->
          let c = String.sub s (i2 + 1) (i3 - i2 - 1) in
          let d = String.sub s (i3 + 1) (String.length s - i3 - 1) in
          Some (a, b, c, d)))

  let handle_request (svc : 'meta t) (req_body : string) (req_meta : 'meta) :
      raw_response =
    let trimmed = String.trim req_body in
    if trimmed = "" || trimmed = "studio" then serve_studio svc
    else if trimmed = "list" then serve_list svc
    else
      let parsed_req =
        if String.unsafe_get trimmed 0 = '{' then
          match Json.parse req_body with
          | Error _ -> Error "bad request: invalid JSON"
          | Ok (Json.Object fields) -> (
            let req_val = List.assoc_opt "request" fields in
            let method_val = List.assoc_opt "method" fields in
            match (method_val, req_val) with
            | _, None ->
              Error "bad request: missing 'request' field in JSON object"
            | Some (Json.String name), Some rj -> Ok (name, None, true, rj)
            | Some (Json.Number num_s), Some rj -> (
              match Int64.of_string_opt num_s with
              | Some n -> Ok ("?" ^ num_s, Some n, true, rj)
              | None ->
                Error
                  "bad request: 'method' field must be a string or an integer")
            | _ ->
              Error "bad request: 'method' field must be a string or an integer")
          | Ok _ -> Error "bad request: expected JSON object"
        else
          match split_colon4 req_body with
          | None -> Error "bad request: invalid request format"
          | Some (name, num_str, format_str, req_json_code) -> (
            let num_opt =
              if num_str = "" then
                match Int64.of_string_opt name with
                | Some n -> Some n
                | None -> None
              else Int64.of_string_opt num_str
            in
            if num_str <> "" && num_opt = None then
              Error "bad request: method number is not an integer"
            else
              let readable = format_str = "readable" in
              match Json.parse req_json_code with
              | Error _ -> Error "bad request: can't parse request JSON"
              | Ok rj -> Ok (name, num_opt, readable, rj))
      in
      match parsed_req with
      | Error msg ->
        {
          status_code = 400;
          content_type = "text/plain; charset=utf-8";
          data = msg;
        }
      | Ok (name, num_opt, readable, req_json) -> (
        let em_opt =
          match num_opt with
          | Some n -> Hashtbl.find_opt svc.by_number n
          | None -> Hashtbl.find_opt svc.by_name name
        in
        match em_opt with
        | None ->
          {
            status_code = 404;
            content_type = "text/plain; charset=utf-8";
            data = Printf.sprintf "method not found: %s" name;
          }
        | Some em -> (
          let policy = if svc.keep_unrecognized_values then Keep else Drop in
          match em.em_invoke req_json readable policy req_meta with
          | Ok data ->
            {
              status_code = 200;
              content_type = "application/json";
              data;
            }
          | Error (code, msg) ->
            {
              status_code = code;
              content_type = "text/plain; charset=utf-8";
              data = msg;
            }))
end

module Service_client = struct
  type t = {
    host : string;
    port : int;
    path : string;
  }

  let parse_http_url url =
    let prefix = "http://" in
    let plen = String.length prefix in
    if String.length url < plen || String.sub url 0 plen <> prefix then
      invalid_arg ("Service_client.create: only http:// URLs are supported: " ^ url);
    if String.contains url '?' then
      invalid_arg "Service_client.create: service URL must not contain a query string";
    let rest = String.sub url plen (String.length url - plen) in
    let host_port, path =
      match String.index_opt rest '/' with
      | None -> (rest, "/")
      | Some idx ->
        (String.sub rest 0 idx, String.sub rest idx (String.length rest - idx))
    in
    let host, port =
      match String.index_opt host_port ':' with
      | None -> (host_port, 80)
      | Some idx ->
        let h = String.sub host_port 0 idx in
        let p_str =
          String.sub host_port (idx + 1) (String.length host_port - idx - 1)
        in
        (h, int_of_string p_str)
    in
    { host; port; path }

  let create url = parse_http_url url

  let invoke_remote ?(headers = []) (client : t)
      (m : ('req, 'resp) Method.t) (req : 'req) : ('resp, string) result =
    let req_json = to_dense_json_code m.request_serializer req in
    let body =
      Printf.sprintf "%s:%Ld::%s" m.name m.number req_json
    in
    try
      let entry = Unix.gethostbyname client.host in
      if Array.length entry.Unix.h_addr_list = 0 then
        Error ("DNS lookup failed for " ^ client.host)
      else
        let addr =
          Unix.ADDR_INET (entry.Unix.h_addr_list.(0), client.port)
        in
        let ic, oc = Unix.open_connection addr in
        let cleanup () =
          (try Unix.shutdown_connection ic with _ -> ());
          (try close_in_noerr ic with _ -> ());
          try close_out_noerr oc with _ -> ()
        in
        try
          let hdr_buf = Buffer.create 256 in
          Buffer.add_string hdr_buf
            (Printf.sprintf "POST %s HTTP/1.1\r\n" client.path);
          Buffer.add_string hdr_buf
            (Printf.sprintf "Host: %s:%d\r\n" client.host client.port);
          Buffer.add_string hdr_buf
            "Content-Type: text/plain; charset=utf-8\r\n";
          Buffer.add_string hdr_buf
            (Printf.sprintf "Content-Length: %d\r\n" (String.length body));
          Buffer.add_string hdr_buf "Connection: close\r\n";
          List.iter
            (fun (k, v) ->
              Buffer.add_string hdr_buf (Printf.sprintf "%s: %s\r\n" k v))
            headers;
          Buffer.add_string hdr_buf "\r\n";
          Buffer.add_string hdr_buf body;
          output_string oc (Buffer.contents hdr_buf);
          flush oc;

          let resp_buf = Buffer.create 1024 in
          (try
             while true do
               let line = input_line ic in
               Buffer.add_string resp_buf line;
               Buffer.add_char resp_buf '\n'
             done
           with End_of_file -> ());
          cleanup ();
          let raw_resp = Buffer.contents resp_buf in
          (* Split headers and body at first \r\n\r\n or \n\n *)
          let rec find_body_start i =
            if i + 3 < String.length raw_resp
               && String.unsafe_get raw_resp i = '\r'
               && String.unsafe_get raw_resp (i + 1) = '\n'
               && String.unsafe_get raw_resp (i + 2) = '\r'
               && String.unsafe_get raw_resp (i + 3) = '\n'
            then Some (i, i + 4)
            else if
              i + 1 < String.length raw_resp
              && String.unsafe_get raw_resp i = '\n'
              && String.unsafe_get raw_resp (i + 1) = '\n'
            then Some (i, i + 2)
            else if i + 1 < String.length raw_resp then find_body_start (i + 1)
            else None
          in
          match find_body_start 0 with
          | None -> Error "malformed HTTP response"
          | Some (hdr_end, body_start) ->
            let hdr_part = String.sub raw_resp 0 hdr_end in
            let resp_body =
              String.sub raw_resp body_start (String.length raw_resp - body_start)
            in
            let status_line =
              match String.index_opt hdr_part '\n' with
              | None -> hdr_part
              | Some idx -> String.sub hdr_part 0 idx
            in
            let status_code =
              match String.split_on_char ' ' (String.trim status_line) with
              | _ :: code_s :: _ -> (
                match int_of_string_opt code_s with Some c -> c | None -> 0)
              | _ -> 0
            in
            if status_code >= 200 && status_code < 300 then
              from_json_code ~unrecognized_values:Keep m.response_serializer
                resp_body
            else
              Error
                (Printf.sprintf "HTTP status %d: %s" status_code
                   (String.trim resp_body))
        with exn ->
          cleanup ();
          Error (Printexc.to_string exn)
    with exn -> Error (Printexc.to_string exn)
end
