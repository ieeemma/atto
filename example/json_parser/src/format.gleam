import gleam/dict
import gleam/float
import gleam/list
import gleam/string
import gleam/string_tree
import parse

pub fn format(json: parse.Json) -> String {
  format_rec(json) |> string_tree.to_string
}

fn format_rec(json) {
  case json {
    parse.Object(obj) ->
      obj
      |> dict.to_list
      |> list.map(fn(x) {
        format_rec(x.1)
        |> string_tree.prepend(": ")
        |> string_tree.prepend(string.inspect(x.0))
      })
      |> string_tree.join(", ")
      |> string_tree.prepend("{")
      |> string_tree.append("}")
    parse.Array(arr) ->
      arr
      |> list.map(format_rec)
      |> string_tree.join(", ")
      |> string_tree.prepend("[")
      |> string_tree.append("]")
    parse.String(s) -> string.inspect(s) |> string_tree.from_string
    parse.Number(n) -> float.to_string(n) |> string_tree.from_string
    parse.Bool(True) -> "true" |> string_tree.from_string
    parse.Bool(False) -> "false" |> string_tree.from_string
    parse.Null -> "null" |> string_tree.from_string
  }
}
