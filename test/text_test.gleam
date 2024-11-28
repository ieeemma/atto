import gleam/set
import gleeunit/should

import atto
import atto/text
import atto_test.{span_char}

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

pub fn text_render_test() {
  let in = text.new("foo bar baz")
  let sp = atto.Span(atto.Pos(4, 1, 5), atto.Pos(7, 1, 8))
  in.render_span(in.src, sp) |> should.equal(#("foo ", "bar", " baz"))

  let in = text.new("foo bar\nbaz quux")
  let sp = atto.Span(atto.Pos(4, 1, 5), atto.Pos(11, 2, 4))
  in.render_span(in.src, sp) |> should.equal(#("foo ", "bar\nbaz", " quux"))
}

pub fn regex_test() {
  text.match("[0-9]+")
  |> atto.run(text.new("452"), Nil)
  |> should.equal(Ok("452"))

  text.match("[0-9]+")
  |> atto.run(text.new("foo"), Nil)
  |> should.equal(
    Error(atto.ParseError(span_char(0, 1, 1), atto.Token("f"), set.new())),
  )
}
