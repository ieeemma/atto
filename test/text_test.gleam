import gleam/set
import gleeunit/should
import glide
import glide/error
import glide/text
import glide_test.{span_char, span_point}

pub fn text_test() {
  let in = text.new("Hello, world!")
  let pos = #(1, 1)
  let assert Ok(#(t, s, pos)) = in.get(in.src, pos)
  t |> should.equal("H")
  s |> should.equal("ello, world!")
  pos |> should.equal(#(1, 2))

  let in = text.new("")
  let pos = #(1, 1)
  in.get(in.src, pos) |> should.equal(Error(Nil))
}

pub fn regex_test() {
  text.match("[0-9]+")
  |> glide.run(text.new("452"), Nil)
  |> should.equal(Ok("452"))

  text.match("[0-9]+")
  |> glide.run(text.new("foo"), Nil)
  |> should.equal(
    Error(error.ParseError(
      span_char(0, 1, 1),
      error.Msg("Regex failed"),
      set.new(),
    )),
  )

  text.match("a*")
  |> glide.run(text.new("foo"), Nil)
  |> should.equal(
    Error(error.ParseError(
      span_point(0, 1, 1),
      error.Msg("Zero-length match"),
      set.new(),
    )),
  )
}
