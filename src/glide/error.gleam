import gleam/set.{type Set}

/// A position in the input stream, with an index, line, and column.
pub type Pos {
  Pos(idx: Int, line: Int, col: Int)
}

/// A span of positions in the input stream.
pub type Span {
  Span(start: Pos, end: Pos)
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
