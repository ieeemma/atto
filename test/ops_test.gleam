import gleam/set
import gleeunit/should
import glide
import glide/ops
import glide/text
import glide_test.{span_at}

pub fn maybe_test() {
  ops.maybe(glide.token("5"))
  |> glide.run(text.new("5"), Nil)
  |> should.equal(Ok(Ok("5")))

  ops.maybe(glide.token("5"))
  |> glide.run(text.new("6"), Nil)
  |> should.equal(Ok(Error(Nil)))

  ops.maybe(glide.token("5"))
  |> glide.run(text.new(""), Nil)
  |> should.equal(Ok(Error(Nil)))
}

pub fn many_test() {
  ops.many(glide.token("5"))
  |> glide.run(text.new("555"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.many(glide.token("5"))
  |> glide.run(text.new("666"), Nil)
  |> should.equal(Ok([]))
}

pub fn some_test() {
  ops.some(glide.token("5"))
  |> glide.run(text.new("555"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.some(glide.token("5"))
  |> glide.run(text.new("666"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      span_at(1, 1),
      glide.Token("6"),
      set.insert(set.new(), glide.Token("5")),
    )),
  )
}

pub fn choice_test() {
  ops.choice([glide.token("5"), glide.token("6")])
  |> glide.run(text.new("5"), Nil)
  |> should.equal(Ok("5"))

  ops.choice([glide.token("5"), glide.token("6")])
  |> glide.run(text.new("6"), Nil)
  |> should.equal(Ok("6"))

  ops.choice([glide.token("5"), glide.token("6")])
  |> glide.run(text.new("7"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      span_at(1, 1),
      glide.Token("7"),
      set.from_list([glide.Token("5"), glide.Token("6")]),
    )),
  )
}

pub fn sep1_test() {
  ops.sep1(glide.token("5"), glide.token(","))
  |> glide.run(text.new("5,5,5"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.sep1(glide.token("5"), glide.token(","))
  |> glide.run(text.new("5,5,6"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      span_at(1, 5),
      glide.Token("6"),
      set.insert(set.new(), glide.Token("5")),
    )),
  )

  ops.sep1(glide.token("5"), glide.token(","))
  |> glide.run(text.new("6"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      span_at(1, 1),
      glide.Token("6"),
      set.insert(set.new(), glide.Token("5")),
    )),
  )
}

pub fn sep_test() {
  ops.sep(glide.token("5"), glide.token(","))
  |> glide.run(text.new("5,5,5"), Nil)
  |> should.equal(Ok(["5", "5", "5"]))

  ops.sep(glide.token("5"), glide.token(","))
  |> glide.run(text.new("5,5,6"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      span_at(1, 5),
      glide.Token("6"),
      set.insert(set.new(), glide.Token("5")),
    )),
  )

  ops.sep(glide.token("5"), glide.token(","))
  |> glide.run(text.new("6"), Nil)
  |> should.equal(Ok([]))
}

pub fn between_test() {
  ops.between(glide.token("("), glide.token("5"), glide.token(")"))
  |> glide.run(text.new("(5)"), Nil)
  |> should.equal(Ok("5"))

  ops.between(glide.token("("), glide.token("5"), glide.token(")"))
  |> glide.run(text.new("5"), Nil)
  |> should.equal(
    Error(glide.ParseError(
      span_at(1, 1),
      glide.Token("5"),
      set.insert(set.new(), glide.Token("(")),
    )),
  )
}
