import gleam/set
import gleam/string
import gleeunit
import gleeunit/should
import glide

pub fn main() {
  gleeunit.main()
}

pub fn string_input_test() {
  let in = glide.string_input("Hello, world!")
  let pos = glide.Pos(1, 1)
  let assert Ok(#(t, s, pos)) = in.get(in.src, pos)
  t |> should.equal("H")
  s |> should.equal(string.to_graphemes("ello, world!"))
  pos |> should.equal(glide.Pos(1, 2))

  let in = glide.string_input("")
  let pos = glide.Pos(1, 1)
  in.get(in.src, pos) |> should.equal(Error(Nil))
}

pub fn pure_test() {
  glide.pure(5)
  |> glide.run(glide.string_input(""), Nil)
  |> should.equal(Ok(5))
}

pub fn map_test() {
  glide.pure(5)
  |> glide.map(fn(n) { n + 1 })
  |> glide.run(glide.string_input(""), Nil)
  |> should.equal(Ok(6))
}

pub fn do_test() {
  let p = {
    use x <- glide.do(glide.pure(5))
    use y <- glide.do(glide.pure(6))
    glide.pure(x + y)
  }
  glide.run(p, glide.string_input(""), Nil)
  |> should.equal(Ok(11))
}

pub fn satisfy_test() {
  glide.satisfy(fn(c) { c == "5" })
  |> glide.run(glide.string_input("5"), Nil)
  |> should.equal(Ok("5"))

  glide.satisfy(fn(c) { c == "5" })
  |> glide.run(glide.string_input("6"), Nil)
  |> should.equal(
    Error(glide.ParseError(glide.Pos(1, 1), glide.Token("6"), set.new())),
  )
}

pub fn label_test() {
  let p = {
    use <- glide.label("foo")
    glide.satisfy(fn(c) { c == "5" })
  }
  glide.run(p, glide.string_input("6"), Nil)
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
  |> glide.run(glide.string_input(""), Nil)
  |> should.equal(Ok(Nil))

  glide.eof()
  |> glide.run(glide.string_input("foo"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      glide.Pos(1, 1),
      glide.Token("f"),
      set.insert(set.new(), glide.Msg("EOF")),
    )),
  )
}

pub fn optional_test() {
  glide.optional(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(glide.string_input("5"), Nil)
  |> should.equal(Ok(Ok("5")))

  glide.optional(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(glide.string_input("6"), Nil)
  |> should.equal(Ok(Error(Nil)))

  glide.optional(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(glide.string_input(""), Nil)
  |> should.equal(Ok(Error(Nil)))
}

pub fn many_test() {
  glide.many(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(glide.string_input("555"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  glide.many(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(glide.string_input("666"), Nil)
  |> should.equal(Ok([]))
}

pub fn some_test() {
  glide.some(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(glide.string_input("555"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  glide.some(glide.satisfy(fn(c) { c == "5" }))
  |> glide.run(glide.string_input("666"), Nil)
  |> should.equal(
    Error(glide.ParseError(glide.Pos(1, 1), glide.Token("6"), set.new())),
  )
}

pub fn choice_test() {
  glide.choice([
    glide.satisfy(fn(c) { c == "5" }),
    glide.satisfy(fn(c) { c == "6" }),
  ])
  |> glide.run(glide.string_input("5"), Nil)
  |> should.equal(Ok("5"))

  glide.choice([
    glide.satisfy(fn(c) { c == "5" }),
    glide.satisfy(fn(c) { c == "6" }),
  ])
  |> glide.run(glide.string_input("6"), Nil)
  |> should.equal(Ok("6"))

  glide.choice([
    glide.satisfy(fn(c) { c == "5" }),
    glide.satisfy(fn(c) { c == "6" }),
  ])
  |> glide.run(glide.string_input("7"), Nil)
  |> should.equal(
    Error(glide.ParseError(glide.Pos(1, 1), glide.Token("7"), set.new())),
  )
}
