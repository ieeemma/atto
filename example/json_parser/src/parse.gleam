import atto
import atto/stream/text
import gleam/dict
import gleam/int

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
  |> text.lexeme
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
  |> text.lexeme
}

fn bool() {
  use <- atto.label("bool")
  atto.choice(
    text.keyword("true") |> atto.this(atto.pure(Bool(True))),
    text.keyword("false") |> atto.this(atto.pure(Bool(False))),
  )
}

fn null() {
  use <- atto.label("null")
  text.keyword("null") |> atto.this(atto.pure(Null))
}
