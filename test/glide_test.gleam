import gleam/set
import gleeunit
import gleeunit/should
import glide
import glide/text

pub fn main() {
  gleeunit.main()
}

pub fn pure_test() {
  glide.pure(5)
  |> glide.run(text.new(""), Nil)
  |> should.equal(Ok(5))
}

pub fn fail_test() {
  glide.fail_msg("foo")
  |> glide.run(text.new(""), Nil)
  |> should.equal(
    Error(glide.ParseError(glide.Pos(1, 1), glide.Msg("foo"), set.new())),
  )

  glide.fail(5)
  |> glide.run(text.new(""), Nil)
  |> should.equal(Error(glide.Custom(glide.Pos(1, 1), 5)))
}

pub fn pos_test() {
  {
    use <- glide.drop(
      glide.pos() |> glide.map(fn(p) { should.equal(p, glide.Pos(1, 1)) }),
    )
    use <- glide.drop(glide.token("a"))
    use <- glide.drop(
      glide.pos() |> glide.map(fn(p) { should.equal(p, glide.Pos(1, 2)) }),
    )
    glide.pure(Nil)
  }
  |> glide.run(text.new("a"), Nil)
}

pub fn ctx_test() {
  {
    use <- glide.ctx_put(fn(x) { x + 1 })
    use x <- glide.do(glide.ctx())
    glide.pure(x |> should.equal(6))
  }
  |> glide.run(text.new(""), 5)
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
    glide.token("5")
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
