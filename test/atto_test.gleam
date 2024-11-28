import gleam/set
import gleeunit
import gleeunit/should

import atto
import atto/text

pub fn main() {
  gleeunit.main()
}

pub fn span_char(idx, row, col) {
  atto.Span(atto.Pos(idx, row, col), atto.Pos(idx + 1, row, col + 1))
}

pub fn span_point(idx, row, col) {
  atto.Span(atto.Pos(idx, row, col), atto.Pos(idx, row, col))
}

pub fn pure_test() {
  atto.pure(5)
  |> atto.run(text.new(""), Nil)
  |> should.equal(Ok(5))
}

pub fn fail_test() {
  atto.fail_msg("foo")
  |> atto.run(text.new(""), Nil)
  |> should.equal(
    Error(atto.ParseError(span_point(0, 1, 1), atto.Msg("foo"), set.new())),
  )

  atto.fail(5)
  |> atto.run(text.new(""), Nil)
  |> should.equal(Error(atto.Custom(span_point(0, 1, 1), 5)))
}

pub fn pos_test() {
  {
    use <- atto.drop(
      atto.pos() |> atto.map(fn(p) { should.equal(p, atto.Pos(0, 1, 1)) }),
    )
    use <- atto.drop(atto.token("a"))
    use <- atto.drop(
      atto.pos() |> atto.map(fn(p) { should.equal(p, atto.Pos(1, 1, 2)) }),
    )
    atto.pure(Nil)
  }
  |> atto.run(text.new("a"), Nil)
}

pub fn ctx_test() {
  {
    use <- atto.ctx_put(fn(x) { x + 1 })
    use x <- atto.do(atto.ctx())
    atto.pure(x |> should.equal(6))
  }
  |> atto.run(text.new(""), 5)
}

pub fn map_test() {
  atto.pure(5)
  |> atto.map(fn(n) { n + 1 })
  |> atto.run(text.new(""), Nil)
  |> should.equal(Ok(6))
}

pub fn do_test() {
  let p = {
    use x <- atto.do(atto.pure(5))
    use y <- atto.do(atto.pure(6))
    atto.pure(x + y)
  }
  atto.run(p, text.new(""), Nil)
  |> should.equal(Ok(11))
}

pub fn satisfy_test() {
  atto.satisfy(fn(c) { c == "5" })
  |> atto.run(text.new("5"), Nil)
  |> should.equal(Ok("5"))

  atto.satisfy(fn(c) { c == "5" })
  |> atto.run(text.new("6"), Nil)
  |> should.equal(
    Error(atto.ParseError(span_char(0, 1, 1), atto.Token("6"), set.new())),
  )
}

pub fn label_test() {
  let p = {
    use <- atto.label("foo")
    atto.token("5")
  }
  atto.run(p, text.new("6"), Nil)
  |> should.equal(
    Error(atto.ParseError(
      span_char(0, 1, 1),
      atto.Token("6"),
      set.insert(set.new(), atto.Msg("foo")),
    )),
  )
}

pub fn eof_test() {
  atto.eof()
  |> atto.run(text.new(""), Nil)
  |> should.equal(Ok(Nil))

  atto.eof()
  |> atto.run(text.new("foo"), Nil)
  |> should.equal(
    Error(atto.ParseError(
      span_point(0, 1, 1),
      atto.Token("f"),
      set.insert(set.new(), atto.Msg("EOF")),
    )),
  )
}
