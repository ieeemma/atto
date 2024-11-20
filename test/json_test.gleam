import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/set
import gleam/string
import gleeunit/should
import glide.{type Parser, do, drop, pure}
import glide/ops
import glide/text

import glide_test.{span_char}

pub type Json {
  Object(dict.Dict(String, Json))
  Array(List(Json))
  String(String)
  Number(Float)
  Bool(Bool)
  Null
}

pub fn json() -> Parser(Json, String, String, Nil, Nil) {
  ops.choice([object(), array(), string(), number(), bool(), null()])
}

fn object() {
  use <- glide.label("object")
  ops.between(
    glide.token("{") |> ws,
    ops.sep(key_value(), glide.token(",") |> ws()),
    glide.token("}") |> ws,
  )
  |> glide.map(dict.from_list)
  |> glide.map(Object)
}

fn key_value() {
  use <- glide.label("key-value pair")
  use k <- do(string())
  let assert String(k) = k
  use <- drop(glide.token(":") |> ws())
  use v <- do(json())
  pure(#(k, v))
}

fn array() {
  use <- glide.label("array")
  ops.between(
    glide.token("[") |> ws,
    ops.sep(json(), glide.token(",") |> ws()),
    glide.token("]") |> ws,
  )
  |> glide.map(Array)
}

fn string() {
  use <- glide.label("string")
  ops.between(
    glide.token("\"") |> ws,
    ops.many(string_inner()),
    glide.token("\"") |> ws,
  )
  |> glide.map(string.concat)
  |> glide.map(String)
}

fn string_inner() {
  ops.choice([unicode_escape(), escape(), glide.satisfy(fn(c) { c != "\"" })])
}

fn escape() {
  use <- glide.label("escape")
  ops.choice([
    text.match("\\\\\"") |> glide.map(fn(_) { "\"" }),
    text.match("\\\\\\\\") |> glide.map(fn(_) { "\\" }),
    text.match("\\/") |> glide.map(fn(_) { "/" }),
    text.match("\\\\b") |> glide.map(fn(_) { "\u{0008}" }),
    text.match("\\\\f") |> glide.map(fn(_) { "\u{000c}" }),
    text.match("\\\\n") |> glide.map(fn(_) { "\u{000a}" }),
    text.match("\\\\r") |> glide.map(fn(_) { "\u{000d}" }),
    text.match("\\\\t") |> glide.map(fn(_) { "\u{0009}" }),
  ])
}

fn unicode_escape() {
  use <- glide.label("unicode escape")
  use <- drop(text.match("\\\\u") |> ws())
  use a <- do(text.match("[0-9a-fA-F]") |> ws())
  use b <- do(text.match("[0-9a-fA-F]") |> ws())
  use c <- do(text.match("[0-9a-fA-F]") |> ws())
  use d <- do(text.match("[0-9a-fA-F]") |> ws())
  let assert Ok(n) = int.parse(string.concat(["0x", a, b, c, d]))
  case string.utf_codepoint(n) {
    Ok(s) -> pure(string.from_utf_codepoints([s]))
    Error(_) -> glide.fail_msg("Invalid unicode escape sequence")
  }
}

fn number() {
  use <- glide.label("number")
  use n <- do(text.match("\\d+(\\.\\d+)?") |> ws())
  let assert Ok(n) =
    result.or(float.parse(n), int.parse(n) |> result.map(int.to_float))
  pure(Number(n))
}

fn bool() {
  use <- glide.label("bool")
  ops.choice([
    text.match("true") |> glide.map(fn(_) { Bool(True) }),
    text.match("false") |> glide.map(fn(_) { Bool(False) }),
  ])
  |> ws()
}

fn null() {
  use <- glide.label("null")
  text.match("null") |> glide.map(fn(_) { Null }) |> ws()
}

fn ws(x) {
  use x <- do(x)
  use <- drop(ops.maybe(text.match("\\s+")))
  pure(x)
}

pub fn json_test() {
  json()
  |> glide.run(text.new("{\"foo\": 5}"), Nil)
  |> should.equal(Ok(Object(dict.from_list([#("foo", Number(5.0))]))))

  json()
  |> glide.run(text.new("[1, 2, 3]"), Nil)
  |> should.equal(Ok(Array([Number(1.0), Number(2.0), Number(3.0)])))

  json()
  |> glide.run(text.new("\"foo\""), Nil)
  |> should.equal(Ok(String("foo")))

  json()
  |> glide.run(text.new("5"), Nil)
  |> should.equal(Ok(Number(5.0)))

  json()
  |> glide.run(text.new("true"), Nil)
  |> should.equal(Ok(Bool(True)))

  json()
  |> glide.run(text.new("false"), Nil)
  |> should.equal(Ok(Bool(False)))

  json()
  |> glide.run(text.new("null"), Nil)
  |> should.equal(Ok(Null))

  let all =
    ["object", "array", "string", "number", "bool", "null"]
    |> list.map(glide.Msg)
    |> set.from_list
  json()
  |> glide.run(text.new("foo"), Nil)
  |> should.equal(
    Error(glide.ParseError(span_char(0, 1, 1), glide.Token("f"), all)),
  )
}
