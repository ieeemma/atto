import atto
import atto/stream/text
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam/string_tree
import in

pub type Json {
  Object(dict.Dict(String, Json))
  Array(List(Json))
  String(String)
  Number(Float)
  Bool(Bool)
  Null
}

pub fn json_file() {
  json() |> atto.that(atto.eof())
}

pub fn json() {
  atto.one_of([
    object(),
    array(),
    string(),
    number(),
    bool(),
    null(),
  ])
}

fn object() {
  use <- atto.label("object")
  text.string_literal()
  |> atto.that(text.symbol(":"))
  |> atto.both(json())
  |> atto.sep_by(text.symbol(","))
  |> atto.between(text.symbol("{"), text.symbol("}"))
  |> atto.map(dict.from_list)
  |> atto.map(Object)
}

fn array() {
  use <- atto.label("array")
  json()
  |> atto.sep_by(text.symbol(","))
  |> atto.between(text.symbol("["), text.symbol("]"))
  |> atto.map(Array)
}

fn string() {
  use <- atto.label("string")
  text.string_literal() |> text.lexeme() |> atto.map(String)
}

fn number() {
  use <- atto.label("number")
  atto.choice(
    text.float() |> atto.map(Number) |> atto.try,
    text.integer() |> atto.map(int.to_float) |> atto.map(Number),
  )
}

fn bool() {
  use <- atto.label("bool")
  atto.choice(
    text.reserved("true") |> atto.this(atto.pure(Bool(True))),
    text.reserved("false") |> atto.this(atto.pure(Bool(False))),
  )
}

fn null() {
  use <- atto.label("null")
  text.reserved("null") |> atto.this(atto.pure(Null))
}

fn format(json: Json) -> String {
  format_rec(json) |> string_tree.to_string
}

fn format_rec(json) {
  case json {
    Object(obj) ->
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
    Array(arr) ->
      arr
      |> list.map(format_rec)
      |> string_tree.join(", ")
      |> string_tree.prepend("[")
      |> string_tree.append("]")
    String(s) -> string.inspect(s) |> string_tree.from_string
    Number(n) -> float.to_string(n) |> string_tree.from_string
    Bool(True) -> "true" |> string_tree.from_string
    Bool(False) -> "false" |> string_tree.from_string
    Null -> "null" |> string_tree.from_string
  }
}

pub fn main() {
  case in.read_chars(int.bitwise_shift_left(1, 32)) {
    Error(e) -> io.println_error(string.inspect(e))
    Ok(str) ->
      case text.run(json_file(), str) {
        Error(e) -> io.println_error(string.inspect(e))
        Ok(json) -> io.println(format(json))
      }
  }
}
