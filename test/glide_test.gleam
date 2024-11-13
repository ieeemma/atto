import gleam/dict
import gleam/list
import gleam/set
import gleeunit
import gleeunit/should
import glide
import glide/ops
import glide/text
import json.{json}

pub fn main() {
  gleeunit.main()
}

pub fn text_test() {
  let in = text.new("Hello, world!")
  let pos = glide.Pos(1, 1)
  let assert Ok(#(t, s, pos)) = in.get(in.src, pos)
  t |> should.equal("H")
  s |> should.equal("ello, world!")
  pos |> should.equal(glide.Pos(1, 2))

  let in = text.new("")
  let pos = glide.Pos(1, 1)
  in.get(in.src, pos) |> should.equal(Error(Nil))
}

pub fn pure_test() {
  glide.pure(5)
  |> glide.run(text.new(""), Nil)
  |> should.equal(Ok(5))
}

pub fn map_test() {
  glide.pure(5)
  |> glide.map(fn(n) { n + 1 })
  |> glide.run(text.new(""), Nil)
  |> should.equal(Ok(6))
}

pub fn do_test() {
  let p = {
    use x <- glide.do(glide.pure(5))
    use y <- glide.do(glide.pure(6))
    glide.pure(x + y)
  }
  glide.run(p, text.new(""), Nil)
  |> should.equal(Ok(11))
}

pub fn satisfy_test() {
  glide.satisfy(fn(c) { c == "5" })
  |> glide.run(text.new("5"), Nil)
  |> should.equal(Ok("5"))

  glide.satisfy(fn(c) { c == "5" })
  |> glide.run(text.new("6"), Nil)
  |> should.equal(
    Error(glide.ParseError(glide.Pos(1, 1), glide.Token("6"), set.new())),
  )
}

pub fn label_test() {
  let p = {
    use <- glide.label("foo")
    glide.satisfy(fn(c) { c == "5" })
  }
  glide.run(p, text.new("6"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      glide.Pos(1, 1),
      glide.Token("6"),
      set.insert(set.new(), glide.Msg("foo")),
    )),
  )
}

pub fn eof_test() {
  glide.eof()
  |> glide.run(text.new(""), Nil)
  |> should.equal(Ok(Nil))

  glide.eof()
  |> glide.run(text.new("foo"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      glide.Pos(1, 1),
      glide.Token("f"),
      set.insert(set.new(), glide.Msg("EOF")),
    )),
  )
}

pub fn maybe_test() {
  ops.maybe(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(text.new("5"), Nil)
  |> should.equal(Ok(Ok("5")))

  ops.maybe(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(text.new("6"), Nil)
  |> should.equal(Ok(Error(Nil)))

  ops.maybe(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(text.new(""), Nil)
  |> should.equal(Ok(Error(Nil)))
}

pub fn many_test() {
  ops.many(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(text.new("555"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.many(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(text.new("666"), Nil)
  |> should.equal(Ok([]))
}

pub fn some_test() {
  ops.some(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(text.new("555"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.some(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(text.new("666"), Nil)
  |> should.equal(
    Error(glide.ParseError(glide.Pos(1, 1), glide.Token("6"), set.new())),
  )
}

pub fn choice_test() {
  ops.choice([
    glide.satisfy(fn(c) { c == "5" }),
    glide.satisfy(fn(c) { c == "6" }),
  ])
  |> glide.run(text.new("5"), Nil)
  |> should.equal(Ok("5"))

  ops.choice([
    glide.satisfy(fn(c) { c == "5" }),
    glide.satisfy(fn(c) { c == "6" }),
  ])
  |> glide.run(text.new("6"), Nil)
  |> should.equal(Ok("6"))

  ops.choice([
    glide.satisfy(fn(c) { c == "5" }),
    glide.satisfy(fn(c) { c == "6" }),
  ])
  |> glide.run(text.new("7"), Nil)
  |> should.equal(
    Error(glide.ParseError(glide.Pos(1, 1), glide.Token("7"), set.new())),
  )
}

pub fn regex_test() {
  text.match("[0-9]+")
  |> glide.run(text.new("452"), Nil)
  |> should.equal(Ok("452"))

  text.match("[0-9]+")
  |> glide.run(text.new("foo"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      glide.Pos(1, 1),
      glide.Msg("Regex failed"),
      set.new(),
    )),
  )

  text.match("[")
  |> glide.run(text.new("foo"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      glide.Pos(1, 1),
      glide.Msg(
        "Invalid regular expression: /^[/: Unterminated character class",
      ),
      set.new(),
    )),
  )
}

pub fn json_test() {
  json()
  |> glide.run(text.new("{\"foo\": 5}"), Nil)
  |> should.equal(Ok(json.Object(dict.from_list([#("foo", json.Number(5.0))]))))

  json()
  |> glide.run(text.new("[1, 2, 3]"), Nil)
  |> should.equal(
    Ok(json.Array([json.Number(1.0), json.Number(2.0), json.Number(3.0)])),
  )

  json()
  |> glide.run(text.new("\"foo\""), Nil)
  |> should.equal(Ok(json.String("foo")))

  json()
  |> glide.run(text.new("5"), Nil)
  |> should.equal(Ok(json.Number(5.0)))

  json()
  |> glide.run(text.new("true"), Nil)
  |> should.equal(Ok(json.Bool(True)))

  json()
  |> glide.run(text.new("false"), Nil)
  |> should.equal(Ok(json.Bool(False)))

  json()
  |> glide.run(text.new("null"), Nil)
  |> should.equal(Ok(json.Null))

  let all =
    ["object", "array", "string", "number", "bool", "null"]
    |> list.map(glide.Msg)
    |> set.from_list
  json()
  |> glide.run(text.new("foo"), Nil)
  |> should.equal(
    Error(glide.ParseError(glide.Pos(1, 1), glide.Token("f"), all)),
  )
}
