import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/set
import gleam/string
import gleeunit/should

import atto.{type Parser, do, drop, pure}
import atto/ops
import atto/text
import atto_test.{span_char}

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
  use <- atto.label("object")
  ops.between(
    atto.token("{") |> ws,
    ops.sep(key_value(), atto.token(",") |> ws()),
    atto.token("}") |> ws,
  )
  |> atto.map(dict.from_list)
  |> atto.map(Object)
}

fn key_value() {
  use <- atto.label("key-value pair")
  use k <- do(string())
  let assert String(k) = k
  use <- drop(atto.token(":") |> ws())
  use v <- do(json())
  pure(#(k, v))
}

fn array() {
  use <- atto.label("array")
  ops.between(
    atto.token("[") |> ws,
    ops.sep(json(), atto.token(",") |> ws()),
    atto.token("]") |> ws,
  )
  |> atto.map(Array)
}

fn string() {
  use <- atto.label("string")
  ops.between(
    atto.token("\"") |> ws,
    ops.many(string_inner()),
    atto.token("\"") |> ws,
  )
  |> atto.map(string.concat)
  |> atto.map(String)
}

fn string_inner() {
  ops.choice([unicode_escape(), escape(), atto.satisfy(fn(c) { c != "\"" })])
}

fn escape() {
  use <- atto.label("escape")
  ops.choice([
    text.match("\\\\\"") |> atto.map(fn(_) { "\"" }),
    text.match("\\\\\\\\") |> atto.map(fn(_) { "\\" }),
    text.match("\\/") |> atto.map(fn(_) { "/" }),
    text.match("\\\\b") |> atto.map(fn(_) { "\u{0008}" }),
    text.match("\\\\f") |> atto.map(fn(_) { "\u{000c}" }),
    text.match("\\\\n") |> atto.map(fn(_) { "\u{000a}" }),
    text.match("\\\\r") |> atto.map(fn(_) { "\u{000d}" }),
    text.match("\\\\t") |> atto.map(fn(_) { "\u{0009}" }),
  ])
}

fn unicode_escape() {
  use <- atto.label("unicode escape")
  use <- drop(text.match("\\\\u") |> ws())
  use a <- do(text.match("[0-9a-fA-F]") |> ws())
  use b <- do(text.match("[0-9a-fA-F]") |> ws())
  use c <- do(text.match("[0-9a-fA-F]") |> ws())
  use d <- do(text.match("[0-9a-fA-F]") |> ws())
  let assert Ok(n) = int.parse(string.concat(["0x", a, b, c, d]))
  case string.utf_codepoint(n) {
    Ok(s) -> pure(string.from_utf_codepoints([s]))
    Error(_) -> atto.fail_msg("Invalid unicode escape sequence")
  }
}

fn number() {
  use <- atto.label("number")
  use n <- do(text.match("\\d+(\\.\\d+)?") |> ws())
  let assert Ok(n) =
    result.or(float.parse(n), int.parse(n) |> result.map(int.to_float))
  pure(Number(n))
}

fn bool() {
  use <- atto.label("bool")
  ops.choice([
    text.match("true") |> atto.map(fn(_) { Bool(True) }),
    text.match("false") |> atto.map(fn(_) { Bool(False) }),
  ])
  |> ws()
}

fn null() {
  use <- atto.label("null")
  text.match("null") |> atto.map(fn(_) { Null }) |> ws()
}

fn ws(x) {
  use x <- do(x)
  use <- drop(ops.maybe(text.match("\\s+")))
  pure(x)
}

pub fn json_test() {
  json()
  |> atto.run(text.new("{\"foo\": 5}"), Nil)
  |> should.equal(Ok(Object(dict.from_list([#("foo", Number(5.0))]))))

  json()
  |> atto.run(text.new("[1, 2, 3]"), Nil)
  |> should.equal(Ok(Array([Number(1.0), Number(2.0), Number(3.0)])))

  json()
  |> atto.run(text.new("\"foo\""), Nil)
  |> should.equal(Ok(String("foo")))

  json()
  |> atto.run(text.new("5"), Nil)
  |> should.equal(Ok(Number(5.0)))

  json()
  |> atto.run(text.new("true"), Nil)
  |> should.equal(Ok(Bool(True)))

  json()
  |> atto.run(text.new("false"), Nil)
  |> should.equal(Ok(Bool(False)))

  json()
  |> atto.run(text.new("null"), Nil)
  |> should.equal(Ok(Null))

  let all =
    ["object", "array", "string", "number", "bool", "null"]
    |> list.map(atto.Msg)
    |> set.from_list
  json()
  |> atto.run(text.new("foo"), Nil)
  |> should.equal(
    Error(atto.ParseError(span_char(0, 1, 1), atto.Token("f"), all)),
  )
}
