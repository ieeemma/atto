import gleam/set
import gleeunit/should

import atto
import atto/ops
import atto/text
import atto_test.{span_char}

pub fn maybe_test() {
  ops.maybe(atto.token("5"))
  |> atto.run(text.new("5"), Nil)
  |> should.equal(Ok(Ok("5")))

  ops.maybe(atto.token("5"))
  |> atto.run(text.new("6"), Nil)
  |> should.equal(Ok(Error(Nil)))

  ops.maybe(atto.token("5"))
  |> atto.run(text.new(""), Nil)
  |> should.equal(Ok(Error(Nil)))
}

pub fn many_test() {
  ops.many(atto.token("5"))
  |> atto.run(text.new("555"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.many(atto.token("5"))
  |> atto.run(text.new("666"), Nil)
  |> should.equal(Ok([]))
}

pub fn some_test() {
  ops.some(atto.token("5"))
  |> atto.run(text.new("555"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.some(atto.token("5"))
  |> atto.run(text.new("666"), Nil)
  |> should.equal(
    Error(atto.ParseError(
      span_char(0, 1, 1),
      atto.Token("6"),
      set.insert(set.new(), atto.Token("5")),
    )),
  )
}

pub fn choice_test() {
  ops.choice([atto.token("5"), atto.token("6")])
  |> atto.run(text.new("5"), Nil)
  |> should.equal(Ok("5"))

  ops.choice([atto.token("5"), atto.token("6")])
  |> atto.run(text.new("6"), Nil)
  |> should.equal(Ok("6"))

  ops.choice([atto.token("5"), atto.token("6")])
  |> atto.run(text.new("7"), Nil)
  |> should.equal(
    Error(atto.ParseError(
      span_char(0, 1, 1),
      atto.Token("7"),
      set.from_list([atto.Token("5"), atto.Token("6")]),
    )),
  )
}

pub fn sep1_test() {
  ops.sep1(atto.token("5"), atto.token(","))
  |> atto.run(text.new("5,5,5"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.sep1(atto.token("5"), atto.token(","))
  |> atto.run(text.new("5,5,6"), Nil)
  |> should.equal(
    Error(atto.ParseError(
      span_char(4, 1, 5),
      atto.Token("6"),
      set.insert(set.new(), atto.Token("5")),
    )),
  )

  ops.sep1(atto.token("5"), atto.token(","))
  |> atto.run(text.new("6"), Nil)
  |> should.equal(
    Error(atto.ParseError(
      span_char(0, 1, 1),
      atto.Token("6"),
      set.insert(set.new(), atto.Token("5")),
    )),
  )
}

pub fn sep_test() {
  ops.sep(atto.token("5"), atto.token(","))
  |> atto.run(text.new("5,5,5"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.sep(atto.token("5"), atto.token(","))
  |> atto.run(text.new("5,5,6"), Nil)
  |> should.equal(
    Error(atto.ParseError(
      span_char(4, 1, 5),
      atto.Token("6"),
      set.insert(set.new(), atto.Token("5")),
    )),
  )

  ops.sep(atto.token("5"), atto.token(","))
  |> atto.run(text.new("6"), Nil)
  |> should.equal(Ok([]))
}

pub fn between_test() {
  ops.between(atto.token("("), atto.token("5"), atto.token(")"))
  |> atto.run(text.new("(5)"), Nil)
  |> should.equal(Ok("5"))

  ops.between(atto.token("("), atto.token("5"), atto.token(")"))
  |> atto.run(text.new("5"), Nil)
  |> should.equal(
    Error(atto.ParseError(
      span_char(0, 1, 1),
      atto.Token("5"),
      set.insert(set.new(), atto.Token("(")),
    )),
  )
}

pub fn not_test() {
  let a = atto.token("a")
  let not_a = ops.not(a)

  assert atto.run(not_a, text.new("b"), Nil) == Ok("b")
  assert atto.run(not_a, text.new("a"), Nil)
    == Error(atto.ParseError(
      span: span_char(0, 1, 1),
      got: atto.Token("a"),
      expected: set.new(),
    ))
}

pub fn not_and_backtrack_test() {
  let a = atto.token("a") |> atto.map(fn(_) { 1 })
  let not_a = ops.not(a) |> atto.map(fn(_) { 0 })
  let parser = ops.some(ops.choice([a, not_a]))

  assert atto.run(parser, text.new("abba"), Nil) == Ok([1, 0, 0, 1])
}
