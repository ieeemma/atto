import gleam/set
import gleeunit/should

import atto
import atto/error
import atto/text
import atto_test.{span_char}

pub fn pretty_test() {
  let err = atto.ParseError(span_char(0, 1, 1), atto.Token("b"), set.new())
  let in = text.new("b")
  error.pretty(err, in, False)
  |> should.equal("Parse error: Unexpected token \"b\"\n\n    b")

  let err =
    atto.ParseError(
      span_char(0, 1, 1),
      atto.Token("b"),
      set.insert(set.new(), atto.Token("a")),
    )
  let in = text.new("b")
  error.pretty(err, in, True)
  |> should.equal(
    "\u{001b}[31mParse error:\u{001b}[0m Expected \"a\", got \"b\"\n\n    \u{001b}[31mb\u{001b}[0m",
  )

  let err =
    atto.ParseError(
      span_char(0, 1, 1),
      atto.Token("c"),
      set.from_list([atto.Token("a"), atto.Token("b")]),
    )
  let in = text.new("c")
  error.pretty(err, in, True)
  |> should.equal(
    "\u{001b}[31mParse error:\u{001b}[0m Expected one of \"a\", \"b\", got \"c\"\n\n    \u{001b}[31mc\u{001b}[0m",
  )

  let err =
    atto.ParseError(
      atto.Span(atto.Pos(4, 1, 5), atto.Pos(11, 2, 4)),
      atto.Token("b"),
      set.from_list([atto.Token("foo"), atto.Token("quux")]),
    )
  let in = text.new("foo bar\nbaz quux")
  error.pretty(err, in, True)
  |> should.equal(
    "\u{001b}[31mParse error:\u{001b}[0m Expected one of \"foo\", \"quux\", got \"b\"\n\n    foo \u{001b}[31mbar\n    baz\u{001b}[0m quux",
  )
}
