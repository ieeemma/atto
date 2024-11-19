// import gleam/dict
// import gleam/int
// import gleam/list
// import gleam/string
import gleam/set.{type Set}

/// A position in the input stream.
pub type Pos {
  Pos(line: Int, col: Int)
}

pub type Span {
  Span(start: Pos, end: Pos)
  Single(pos: Pos)
}

/// An error that occurred during parsing.
pub type ParseError(e, t) {
  ParseError(span: Span, got: ErrorPart(t), expected: Set(ErrorPart(t)))
  Custom(span: Span, value: e)
}

/// An expected or found component of an error.
pub type ErrorPart(t) {
  Token(t)
  Msg(String)
}
