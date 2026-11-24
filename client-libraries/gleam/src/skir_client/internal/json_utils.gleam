import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string_tree

pub fn decode_errors_to_string(errors: List(decode.DecodeError)) -> String {
  case errors {
    [decode.DecodeError(expected:, found:, ..), ..] ->
      "expected " <> expected <> " but found " <> found
    _ -> "decode error"
  }
}

/// Builds readable JSON object code from key/value readable trees.
pub fn readable_json_object(
  fields: List(#(String, string_tree.StringTree)),
  eol_indent: String,
) -> string_tree.StringTree {
  case fields {
    [] -> string_tree.from_string("{}")
    _ -> {
      let child_indent = eol_indent <> "  "
      let lines =
        list.map(fields, fn(field) {
          let #(name, value_tree) = field
          string_tree.concat([
            string_tree.from_string(child_indent),
            json.to_string_tree(json.string(name)),
            string_tree.from_string(": "),
            value_tree,
          ])
        })
      string_tree.concat([
        string_tree.from_string("{"),
        string_tree.join(lines, ","),
        string_tree.from_string(eol_indent <> "}"),
      ])
    }
  }
}
