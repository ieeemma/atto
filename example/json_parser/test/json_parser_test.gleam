import atto
import atto/stream/text
import gleam/dict
import gleam/list
import gleam/set
import gleeunit
import parse.{json_file}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn object_test() {
  assert json_file() |> text.run("{\"foo\": 5}")
    == Ok(parse.Object(dict.from_list([#("foo", parse.Number(5.0))])))

  assert json_file() |> text.run("{\"foo\": 5, \"bar\": [1, 2, null]}")
    == Ok(
      parse.Object(
        dict.from_list([
          #("foo", parse.Number(5.0)),
          #(
            "bar",
            parse.Array([
              parse.Number(1.0),
              parse.Number(2.0),
              parse.Null,
            ]),
          ),
        ]),
      ),
    )
}

pub fn array_test() {
  assert json_file() |> text.run("[1, 2, 3]")
    == Ok(
      parse.Array([
        parse.Number(1.0),
        parse.Number(2.0),
        parse.Number(3.0),
      ]),
    )

  assert json_file() |> text.run("[]") == Ok(parse.Array([]))
}

pub fn string_test() {
  assert json_file() |> text.run("\"foo\"") == Ok(parse.String("foo"))
}

pub fn number_test() {
  assert json_file() |> text.run("5") == Ok(parse.Number(5.0))
}

pub fn bool_test() {
  assert json_file() |> text.run("true") == Ok(parse.Bool(True))
  assert json_file() |> text.run("false") == Ok(parse.Bool(False))
}

pub fn null_test() {
  assert json_file() |> text.run("null") == Ok(parse.Null)
}

pub fn error_test() {
  let expect =
    ["object", "array", "string", "number", "bool", "null"]
    |> list.map(atto.Name)
    |> set.from_list

  // TODO: This still isnt right.
  // `nullz` should report `nullz` as the tokens, not `n`
  // and the `one of` string should say `whitespace

  assert json_file() |> text.run("nullz")
    == Error(atto.Msg(text.Pos(1, 1), atto.Tokens("n"), expect))

  assert json_file() |> text.run("{\"foo\": [1, 2, a]}")
    == Error(atto.Msg(
      text.Pos(1, 16),
      atto.Tokens("a"),
      expect |> set.insert(atto.Name("one of \" \\n\\r\\t\"")),
    ))
}
