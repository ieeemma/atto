import atto
import atto/stream/text
import gleam/dict
import gleam/list
import gleam/set
import gleeunit
import json_parser.{json_file}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn object_test() {
  assert json_file() |> text.run("{\"foo\": 5}")
    == Ok(
      json_parser.Object(dict.from_list([#("foo", json_parser.Number(5.0))])),
    )

  assert json_file() |> text.run("{\"foo\": 5, \"bar\": [1, 2, null]}")
    == Ok(
      json_parser.Object(
        dict.from_list([
          #("foo", json_parser.Number(5.0)),
          #(
            "bar",
            json_parser.Array([
              json_parser.Number(1.0),
              json_parser.Number(2.0),
              json_parser.Null,
            ]),
          ),
        ]),
      ),
    )
}

pub fn array_test() {
  assert json_file() |> text.run("[1, 2, 3]")
    == Ok(
      json_parser.Array([
        json_parser.Number(1.0),
        json_parser.Number(2.0),
        json_parser.Number(3.0),
      ]),
    )

  assert json_file() |> text.run("[]") == Ok(json_parser.Array([]))
}

pub fn string_test() {
  assert json_file() |> text.run("\"foo\"") == Ok(json_parser.String("foo"))
}

pub fn number_test() {
  assert json_file() |> text.run("5") == Ok(json_parser.Number(5.0))
}

pub fn bool_test() {
  assert json_file() |> text.run("true") == Ok(json_parser.Bool(True))
  assert json_file() |> text.run("false") == Ok(json_parser.Bool(False))
}

pub fn null_test() {
  assert json_file() |> text.run("null") == Ok(json_parser.Null)
}

pub fn error_test() {
  let expect =
    ["object", "array", "string", "number", "bool", "null"]
    |> list.map(atto.Name)
    |> set.from_list
  assert json_file() |> text.run("nullz")
    == Error(atto.Msg(text.Pos(1, 1), atto.Tokens("n"), expect))
}
