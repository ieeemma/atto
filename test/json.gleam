import gleam/dict
import gleam/float
import gleam/int
import gleam/result
import gleam/string
import glide.{do, pure}

pub type Json {
  Object(dict.Dict(String, Json))
  Array(List(Json))
  String(String)
  Number(Float)
  Bool(Bool)
  Null
}

pub fn json() -> glide.Parser(Json, String, String, Nil, Nil) {
  glide.choice([object(), array(), string(), number(), bool(), null()])
}

fn object() {
  use <- glide.label("object")
  use _ <- do(glide.token("{") |> ws())
  use xs <- do(glide.sep_by(key_value(), glide.token(",") |> ws()))
  use _ <- do(glide.token("}") |> ws())
  pure(Object(dict.from_list(xs)))
}

fn key_value() {
  use <- glide.label("key-value pair")
  use k <- do(string())
  let assert String(k) = k
  use _ <- do(glide.token(":") |> ws())
  use v <- do(json())
  pure(#(k, v))
}

fn array() {
  use <- glide.label("array")
  use _ <- do(glide.token("[") |> ws())
  use xs <- do(glide.sep_by(json(), glide.token(",") |> ws()))
  use _ <- do(glide.token("]") |> ws())
  pure(Array(xs))
}

fn string() {
  use <- glide.label("string")
  use _ <- do(glide.token("\""))
  use s <- do(
    glide.many(
      glide.choice([
        unicode_escape(),
        escape(),
        glide.satisfy(fn(c) { c != "\"" }),
      ]),
    ),
  )
  use _ <- do(glide.token("\""))
  pure(String(string.concat(s)))
}

fn escape() {
  use <- glide.label("escape")
  glide.choice([
    glide.match("\\\"") |> glide.map(fn(_) { "\"" }),
    glide.match("\\\\") |> glide.map(fn(_) { "\\" }),
    glide.match("\\/") |> glide.map(fn(_) { "/" }),
    glide.match("\\\\b") |> glide.map(fn(_) { "\u{0008}" }),
    glide.match("\\\\f") |> glide.map(fn(_) { "\u{000c}" }),
    glide.match("\\\\n") |> glide.map(fn(_) { "\u{000a}" }),
    glide.match("\\\\r") |> glide.map(fn(_) { "\u{000d}" }),
    glide.match("\\\\t") |> glide.map(fn(_) { "\u{0009}" }),
  ])
}

fn unicode_escape() {
  use <- glide.label("unicode escape")
  use _ <- do(glide.match("\\\\u") |> ws())
  use a <- do(glide.match("[0-9a-fA-F]") |> ws())
  use b <- do(glide.match("[0-9a-fA-F]") |> ws())
  use c <- do(glide.match("[0-9a-fA-F]") |> ws())
  use d <- do(glide.match("[0-9a-fA-F]") |> ws())
  let assert Ok(n) = int.parse(string.concat(["0x", a, b, c, d]))
  case string.utf_codepoint(n) {
    Ok(s) -> pure(string.from_utf_codepoints([s]))
    Error(_) -> glide.fail("Invalid unicode escape sequence")
  }
}

fn number() {
  use <- glide.label("number")
  use n <- do(glide.match("\\d+(\\.\\d+)?") |> ws())
  let assert Ok(n) =
    result.or(float.parse(n), int.parse(n) |> result.map(int.to_float))
  pure(Number(n))
}

fn bool() {
  use <- glide.label("bool")
  glide.choice([
    glide.match("true") |> glide.map(fn(_) { Bool(True) }),
    glide.match("false") |> glide.map(fn(_) { Bool(False) }),
  ])
  |> ws()
}

fn null() {
  use <- glide.label("null")
  glide.match("null") |> glide.map(fn(_) { Null }) |> ws()
}

fn ws(x) {
  use x <- do(x)
  use _ <- do(glide.match("\\s*"))
  pure(x)
}
